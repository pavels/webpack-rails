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
        def asset_paths(source)
          current_manifest = manifest
          if current_manifest[:assets].has_key? source
            return current_manifest[:assets][source]
          else
            raise EntryPointMissingError, "Can't find entry point '#{source}' in webpack manifest"
          end
        end

        def image_path(source)
          current_manifest = manifest
          if current_manifest[:images].has_key? source
            return current_manifest[:images][source]
          else
            raise EntryPointMissingError, "Can't find image '#{source}' in webpack manifest"
          end          
        end

        private

        def manifest
          if ::Rails.configuration.webpack.dev_server.enabled
            # Don't cache if we're in dev server mode, manifest may change ...
            load_manifest
          else
            # ... otherwise cache at class level, as JSON loading/parsing can be expensive
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

          manifest_json["modules"].each do |mod|
            base_path = "./#{::Rails.configuration.webpack.image_dir}/"
            if mod["name"].starts_with?(base_path)
              image_base_name = mod["name"].to_s[base_path.length .. -1]
              parsed_manifest[:images][image_base_name] = "/#{::Rails.configuration.webpack.public_path}/#{mod["assets"].first}"
            end
          end

          return parsed_manifest
        end

        def load_dev_server_manifest
          host = ::Rails.configuration.webpack.dev_server.manifest_host
          port = ::Rails.configuration.webpack.dev_server.manifest_port
          http = Net::HTTP.new(host, port)
          http.use_ssl = ::Rails.configuration.webpack.dev_server.https
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          http.get(dev_server_path).body
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

        def dev_server_url
          "http://#{::Rails.configuration.webpack.dev_server.host}:#{::Rails.configuration.webpack.dev_server.port}#{dev_server_path}"
        end
      end
    end
  end
end
