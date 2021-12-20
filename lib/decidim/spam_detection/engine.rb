# frozen_string_literal: true

require "rails"
require "decidim/core"

module Decidim
  module SpamDetection
    # This is the engine that runs on the public interface of spam_detection.
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::SpamDetection
      config.autoload_paths += %W(#{Decidim::SpamDetection::Engine.root}/lib)
      config.eager_load_paths += %W(#{Decidim::SpamDetection::Engine.root}/lib)
    end
  end
end
