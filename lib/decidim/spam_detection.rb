# frozen_string_literal: true

require "decidim/spam_detection/admin"
require "decidim/spam_detection/engine"
require "decidim/spam_detection/admin_engine"

module Decidim
  # This namespace holds the logic of the `SpamDetection` component. This component
  # allows users to create spam_detection in a participatory space.
  module SpamDetection
    DEFAULT_URL = "http://localhost:8080/api"
    include ActiveSupport::Configurable

    autoload :Command, "decidim/spam_detection/command"
    autoload :CommandErrors, "decidim/spam_detection/command_errors"
    autoload :ApiProxy, "decidim/spam_detection/api_proxy"
    autoload :AbstractSpamUserCommand, "decidim/spam_detection/abstract_spam_user_command"
    autoload :ReportSpamUserCommand, "decidim/spam_detection/report_spam_user_command"
    autoload :BlockSpamUserCommand, "decidim/spam_detection/block_spam_user_command"
    autoload :SpamUserCommandAdapter, "decidim/spam_detection/spam_user_command_adapter"

    config_accessor :spam_detection_api_url do
      ENV.fetch("SPAM_DETECTION_API_URL", DEFAULT_URL)
    end

    config_accessor :spam_detection_api_auth_token do
      ENV.fetch("SPAM_DETECTION_API_AUTH_TOKEN", "dummy")
    end

    config_accessor :spam_detection_api_perform_block_user do
      ENV.fetch("PERFORM_BLOCK_USER", "0") == "1"
    end

    config_accessor :spam_detection_api_activate_service do
      lambda do
        return true unless Rails.env.production?

        ENV.fetch("ACTIVATE_SPAM_DETECTION_SERVICE", "0") == "1" || spam_detection_api_url != DEFAULT_URL
      end
    end

    def self.service_activated?
      spam_detection_api_activate_service.call
    end
  end
end
