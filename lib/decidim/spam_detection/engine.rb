# frozen_string_literal: true

require "rails"
require "decidim/core"

module Decidim
  module SpamDetection
    # This is the engine that runs on the public interface of spam_detection.
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::SpamDetection
    end
  end
end
