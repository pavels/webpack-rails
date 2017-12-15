module WebpackDevServer
  class Railtie < Rails::Railtie

    initializer :webpack_dev_server, after: :load_config_initializers do |app|
      if ( ::Rails.configuration.webpack.dev_server.enabled && !::Rails.configuration.webpack.dev_server.remote )
        default_proxy = WebpackDevServer.curb_available ? 'Curb' : 'NetHttp'
        proxy ||= "WebpackDevServer::Middleware::#{default_proxy}Proxy".constantize
        app.config.middleware.insert_before 0, proxy
      end
    end

  end
end
