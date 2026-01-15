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

    # Read ENV at runtime instead of at boot time
    # Seems to be an issue on self-hosted
    # Runs normally on Kubernetes because of how env vars work
    def self.spam_detection_api_url
      ENV.fetch("SPAM_DETECTION_API_URL", DEFAULT_URL)
    end

    def self.spam_detection_api_auth_token
      ENV.fetch("SPAM_DETECTION_API_AUTH_TOKEN", "dummy")
    end

    def self.spam_detection_api_perform_block_user
      ENV.fetch("PERFORM_BLOCK_USER", "0") == "1"
    end

    def self.spam_detection_api_force_activate_service
      ENV.fetch("ACTIVATE_SPAM_DETECTION_SERVICE", "0") == "1"
    end

    def self.spam_detection_api_activate_service
      !Rails.env.production? ||
        spam_detection_api_force_activate_service ||
        spam_detection_api_url != DEFAULT_URL
    end

    def self.service_activated?
      spam_detection_api_activate_service
    end
  end
end
