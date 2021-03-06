require 'net/http'
require 'uri'

module Webpack
  module Rails
    # Webpack manifest loading, caching & entry point retrieval
    class Manifest
      # Raised if we can't read our webpack manifest for whatever reason
      class ManifestLoadError < StandardError
        def initialize(message, orig)
          super "#{message} (original error #{orig})"
        end
      end

      # Raised if webpack couldn't build one of your entry points
      class WebpackError < StandardError
        def initialize(errors)
          super "Error in webpack compile, details follow below:\n#{errors.join("\n\n")}"
        end
      end

      # Raised if a supplied entry point does not exist in the webpack manifest
      class EntryPointMissingError < StandardError
      end

      class << self
        # :nodoc:
        def asset_paths(source, request)
          current_manifest = manifest(request)
          if current_manifest[:assets].has_key? source
            return current_manifest[:assets][source]
          else
            raise EntryPointMissingError, "Can't find entry point '#{source}' in webpack manifest"
          end
        end

        def image_path(source, request)
          current_manifest = manifest(request)
          if current_manifest[:images].has_key? source
            return current_manifest[:images][source]
          else
            raise EntryPointMissingError, "Can't find image '#{source}' in webpack manifest"
          end          
        end

        private

        def manifest(request)
          if ::Rails.configuration.webpack.dev_server.enabled
            if request
              if request.webpack_manifest
                return request.webpack_manifest 
              else
                return (request.webpack_manifest = load_manifest)
              end
            end
          else
            @manifest ||= load_manifest
          end
        end

        def load_manifest
          data = if ::Rails.configuration.webpack.dev_server.enabled
            load_dev_server_manifest
          else
            load_static_manifest
          end
          manifest_json = JSON.parse(data)

          if manifest_json["errors"].any? { |error| error.include? "Module build failed" }
            raise WebpackError, manifest_json["errors"]
          end

          parsed_manifest = { assets: {}, images: {} }

          # Assets
          manifest_json["assetsByChunkName"].each do |key, paths|
            parsed_manifest[:assets][key] = [paths].flatten.reject { |p| p =~ /.*\.map$/ }.map do |p|
              "/#{::Rails.configuration.webpack.public_path}/#{p}"
            end
          end

          if manifest_json["modules"]
            manifest_json["modules"].each do |mod|
              base_path = "./#{::Rails.configuration.webpack.image_dir}/"
              if mod["name"] && mod["name"].starts_with?(base_path)
                image_base_name = mod["name"].to_s[base_path.length .. -1]
                parsed_manifest[:images][image_base_name] = "/#{::Rails.configuration.webpack.public_path}/#{mod["assets"].first}"
              end
            end
          end

          return parsed_manifest
        end

        def load_dev_server_manifest
          if ::Rails.configuration.webpack.dev_server.remote
            host = ::Rails.configuration.webpack.dev_server.manifest_host
            port = ::Rails.configuration.webpack.dev_server.manifest_port
            https = ::Rails.configuration.webpack.dev_server.https
  
            http = Net::HTTP.new(host, port)
            http.use_ssl = https
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
            return http.get(dev_server_path).body
          else
            default_proxy = WebpackDevServer.curb_available ? 'Curb' : 'NetHttp'
            proxy = "WebpackDevServer::Middleware::#{default_proxy}Proxy".constantize.new(nil)
            return proxy.call({'REQUEST_PATH' => dev_server_path})[2][0]
          end
        rescue => e
          raise ManifestLoadError.new("Could not load manifest from webpack-dev-server at http://#{host}:#{port}#{dev_server_path} - is it running, and is stats-webpack-plugin loaded?", e)
        end

        def load_static_manifest
          File.read(static_manifest_path)
        rescue => e
          raise ManifestLoadError.new("Could not load compiled manifest from #{static_manifest_path} - have you run `rake webpack:compile`?", e)
        end

        def static_manifest_path
          ::Rails.root.join(
            ::Rails.configuration.webpack.output_dir,
            ::Rails.configuration.webpack.manifest_filename
          )
        end

        def dev_server_path
          "/#{::Rails.configuration.webpack.public_path}/#{::Rails.configuration.webpack.manifest_filename}"
        end

      end
    end
  end
end
