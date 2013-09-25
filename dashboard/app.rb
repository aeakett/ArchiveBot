require 'coffee-script'
require 'json'
require 'trollop'
require 'uri'
require 'webmachine'
require 'webmachine/sprockets'

require File.expand_path('../log_actors', __FILE__)
require File.expand_path('../db', __FILE__)

opts = Trollop.options do
  opt :url, 'URL to bind to', :default => 'http://localhost:4567'
  opt :redis, 'URL of Redis server', :default => ENV['REDIS_URL'] || 'redis://localhost:6379/0'
  opt :log_update_channel, 'Redis pubsub channel for log updates', :default => ENV['LOG_CHANNEL'] || 'updates'
  opt :db, 'URL of CouchDB history database', :default => ENV['COUCHDB_URL'] || 'http://localhost:5984/archivebot_history'
  opt :db_credentials, 'Credentials for history database (USERNAME:PASSWORD)', :type => String, :default => nil
end

bind_uri = URI.parse(opts[:url])

class History < Webmachine::Resource
  def content_types_accepted
    ['application/json']
  end

  def content_types_provided
    ['application/json']
  end

  def to_json
    params = request.query
  end
end

class Dashboard < Webmachine::Resource
  def to_html
    File.read(File.expand_path('../dashboard.html', __FILE__))
  end
end

App = Webmachine::Application.new do |app|
  sprockets = Sprockets::Environment.new
  sprockets.append_path(File.expand_path('../assets/stylesheets', __FILE__))
  sprockets.append_path(File.expand_path('../assets/javascripts', __FILE__))
  resource = Webmachine::Sprockets.resource_for(sprockets)

  app.configure do |config|
    config.ip = bind_uri.host
    config.port = bind_uri.port
    config.adapter = :Reel
    config.adapter_options[:websocket_handler] = proc do |ws|
      if ws.url == '/stream'
        LogClient.new(ws)
      else
        ws.close
      end
    end
  end

  app.routes do
    add [], Dashboard
    add ['history', '*'], History
    add ['assets', '*'], resource
  end
end

LogReceiver.supervise_as :log_receiver, opts[:redis], opts[:log_update_channel]

at_exit do
  Celluloid::Actor[:log_receiver].stop
end

App.run
