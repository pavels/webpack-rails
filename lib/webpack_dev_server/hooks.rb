require 'rack/server'


class Rack::Server
  def start_with_webpack
    WebpackDevServer::WebpackRunner.run if ( ::Rails.configuration.webpack.dev_server.enabled && !::Rails.configuration.webpack.dev_server.remote )
    start_without_webpack
  end
  alias_method :start_without_webpack, :start
  alias_method :start, :start_with_webpack
end

at_exit do
  WebpackDevServer::WebpackRunner.exit if ( ::Rails.configuration.webpack.dev_server.enabled && !::Rails.configuration.webpack.dev_server.remote )
end
