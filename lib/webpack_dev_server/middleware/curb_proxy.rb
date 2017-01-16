require 'curl'

module WebpackDevServer
  module Middleware
    class CurbProxy < Base
    
      protected

      def fetch( path )
        request = curl
        request.url = "http://localhost#{path}"
        request.perform

        http_response, *http_headers = request.header_str.split(/[\r\n]+/).map(&:strip)
        http_headers = Hash[http_headers.flat_map{ |s| s.scan(/^(\S+): (.+)/) }]
        response_code = http_response.split(' ')[1].to_i

        [response_code, http_headers, [request.body]]
      end

      def connection_error_clazz
        Curl::Err::ConnectionFailedError
      end

      def curl
        Curl::Easy.new.tap do |c|
          c.set(:unix_socket_path, WebpackRunner.socket_path)
        end
      end

    end
  end
end
