# frozen_string_literal: true

require "rails"
require "decidim/core"

module Decidim
  module SpamDetection
    # This is the engine that runs on the public interface of spam_detection.
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::SpamDetection

      routes do
        # Add engine routes here
        # resources :spam_detection
        # root to: "spam_detection#index"
      end

      initializer "SpamDetection.webpacker.assets_path" do
        Decidim.register_assets_path File.expand_path("app/packs", root)
      end
    end
  end
end
