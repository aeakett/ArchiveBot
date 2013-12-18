require 'uri'

##
# There are two sorts of job targets for ArchiveBot:
#
# 1. URIs.  You give ArchiveBot a URI and it starts downloading content from
#    it.
# 2. URIs of files containing URIs.  You give ArchiveBot one of these and it
#    will download content from each of the URIs in the file.
#
# JobTarget is a (URI, interpretation type) pair.  The two types are:
#
# 1. :uri: a target URI
# 2. :file: a file containing URIs
#
# Any other type is unsupported and will raise an exception.
class JobTarget < Struct.new(:uri, :type)
  def initialize(*)
    super

    if !KNOWN_TYPES.include?(type)
      raise ArgumentError, "#{type} is not a known job target type"
    end
  end

  def file?
    type == :file
  end

  def to_s
    [type, uri].join(':')
  end
end
