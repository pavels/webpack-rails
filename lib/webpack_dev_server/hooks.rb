require 'rack/server'

at_exit do
  WebpackDevServer::WebpackRunner.exit
end
