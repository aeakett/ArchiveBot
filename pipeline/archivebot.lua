archivebot = {}

dofile("acceptance_heuristics.lua")
dofile("redis_script_exec.lua")
dofile("settings.lua")

require('socket')

local json = require('json')
local redis = require('vendor/redis-lua/src/redis')
local ident = os.getenv('ITEM_IDENT')
local rconn = redis.connect(os.getenv('REDIS_HOST'), os.getenv('REDIS_PORT'))
local aborter = os.getenv('ABORT_SCRIPT')
local log_key = os.getenv('LOG_KEY')
local log_channel = os.getenv('LOG_CHANNEL')

local do_abort = eval_redis(os.getenv('ABORT_SCRIPT'), rconn)
local do_log = eval_redis(os.getenv('LOG_SCRIPT'), rconn)

rconn:select(os.getenv('REDIS_DB'))

-- Generates a log entry for ignored URLs.
local log_ignored_url = function(url, pattern)
  local entry = {
    ts = os.time(),
    url = url,
    pattern = pattern,
    type = 'ignore'
  }

  do_log(1, ident, json.encode(entry), log_channel, log_key)
end

local requisite_urls = {}

local add_as_page_requisite = function(url)
  requisite_urls[url] = true
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  -- Does the URL match any of the ignore patterns?
  local pattern = archivebot.ignore_url_p(urlpos.url.url)

  if pattern then
    log_ignored_url(urlpos.url.url, pattern)
    return false
  end

  -- Second-guess wget's host-spanning restrictions.
  if not verdict and reason == 'DIFFERENT_HOST' then
    -- Is the parent a www.example.com and the child an example.com, or vice
    -- versa?
    if is_www_to_bare(parent, urlpos.url) then
      -- OK, grab it after all.
      return true
    end

    -- Is this a URL of a non-hyperlinked page requisite?
    if is_page_requisite(urlpos) then
      -- Yeah, grab these too.  We also flag the URL as a page requisite here
      -- because we'll need to know that when we calculate the post-request
      -- delay.
      add_as_page_requisite(urlpos.url.url)
      return true
    end
  end

  -- If we're looking at a page requisite that didn't require verdict
  -- override, flag it as a requisite.
  if verdict and is_page_requisite(urlpos) then
    add_as_page_requisite(urlpos.url.url)
  end

  -- If we get here, none of our exceptions apply.  Return the original
  -- verdict.
  return verdict
end

local abort_requested = function()
  return rconn:hget(ident, 'abort_requested')
end

-- Should this result be flagged as an error?
local is_error = function(statcode, err)
  -- 5xx: yes
  if statcode >= 500 then
    return true
  end

  -- Response code zero with non-RETRFINISHED wget code: yes
  if statcode == 0 and err ~= 'RETRFINISHED' then
    return true
  end

  -- Could be an error, but we don't know it as such
  return false
end

-- Should this result be flagged as a warning?
local is_warning = function(statcode, err)
  return statcode >= 400 and statcode < 500
end

wget.callbacks.httploop_proceed_p = function(url, http_stat)
  local pattern = archivebot.ignore_url_p(url.url)

  if pattern then
    log_ignored_url(url.url, pattern)
    return false
  end

  return true
end

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- Update the traffic counters.
  rconn:hincrby(ident, 'bytes_downloaded', http_stat.rd_size)

  local statcode = http_stat['statcode']

  -- Record the current time, URL, response code, and wget's error code.
  local result = {
    ts = os.time(),
    url = url.url,
    response_code = statcode,
    wget_code = err,
    is_error = is_error(statcode, err),
    is_warning = is_warning(statcode, err),
    type = 'download'
  }

  -- Publish the log entry, and bump the log counter.
  do_log(1, ident, json.encode(result), log_channel, log_key)

  -- Update settings.
  if archivebot.update_settings(ident, rconn) then
    io.stdout:write("Settings updated: ")
    io.stdout:write(archivebot.inspect_settings())
    io.stdout:write("\n")
    io.stdout:flush()
  end

  -- Should we abort?
  if abort_requested() then
    io.stdout:write("Wget terminating on bot command\n")
    io.stdout:flush()
    do_abort(1, ident, log_channel)

    return wget.actions.ABORT
  end

  -- OK, we've finished our fetch attempt.  Now we need to figure out how much
  -- we should delay.  We delay different amounts for page requisites vs.
  -- non-page requisites because browsers act that way.
  local sl, sm

  if requisite_urls[url.url] then
    -- Yes, this will eventually free the memory needed for the key
    requisite_urls[url.url] = nil

    sl, sm = archivebot.pagereq_delay_time_range()
  else
    sl, sm = archivebot.delay_time_range()
  end

  socket.sleep(math.random(sl, sm) / 1000)

  return wget.actions.NOTHING
end

wget.callbacks.finish = function(start_time, end_time, wall_time, numurls, total_downloaded_bytes, total_download_time)
  io.stdout:write("  ")
  io.stdout:write(total_downloaded_bytes.." bytes.")
  io.stdout:write("\n")
  io.stdout:flush()
end

-- vim:ts=2:sw=2:et:tw=78
