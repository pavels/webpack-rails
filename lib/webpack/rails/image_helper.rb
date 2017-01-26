require 'action_view'
require 'webpack/rails/manifest'

module Webpack
  module Rails    
    module ImageHelper

      def compute_asset_path(path, options = {})
        return "" unless path.present?
        return "" unless request

        image_path =  Webpack::Rails::Manifest.image_path(path, request)
        return webpack_real_path(image_path)
      end
      
    end
  end
end
