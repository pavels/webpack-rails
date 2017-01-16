module WebpackDevServer
  class Error < StandardError; end

  class << self
    attr_accessor :curb_available
  end
  
end

begin
  require 'curl'
  WebpackDevServer.curb_available = Curl.const_defined?('CURLOPT_UNIX_SOCKET_PATH')
rescue LoadError
  WebpackDevServer.curb_available = false
end

require 'webpack_dev_server/file_mutex'
require 'webpack_dev_server/socket_http'

require 'webpack_dev_server/webpack_runner'
require 'webpack_dev_server/middleware'
require 'webpack_dev_server/hooks'
require 'webpack_dev_server/railtie' if defined? ::Rails::Railtie
