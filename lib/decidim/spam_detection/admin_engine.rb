# frozen_string_literal: true

module Decidim
  module SpamDetection
    # This is the engine that runs on the public interface of `SpamDetection`.
    class AdminEngine < ::Rails::Engine
      isolate_namespace Decidim::SpamDetection::Admin

      paths["db/migrate"] = nil
      paths["lib/tasks"] = nil

      routes do
        # Add admin engine routes here
        # resources :spam_detection do
        #   collection do
        #     resources :exports, only: [:create]
        #   end
        # end
        # root to: "spam_detection#index"
      end

      def load_seed
        nil
      end
    end
  end
end
