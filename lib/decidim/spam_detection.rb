# frozen_string_literal: true

require "decidim/spam_detection/admin"
require "decidim/spam_detection/engine"
require "decidim/spam_detection/admin_engine"

module Decidim
  # This namespace holds the logic of the `SpamDetection` component. This component
  # allows users to create spam_detection in a participatory space.
  module SpamDetection
    autoload :Command, "decidim/spam_detection/command"
    autoload :CommandErrors, "decidim/spam_detection/command_errors"
    autoload :ApiProxy, "decidim/spam_detection/api_proxy"
    autoload :AbstractSpamUserCommand, "decidim/spam_detection/abstract_spam_user_command"
    autoload :ReportSpamUserCommand, "decidim/spam_detection/report_spam_user_command"
    autoload :BlockSpamUserCommand, "decidim/spam_detection/block_spam_user_command"
    autoload :SpamUserCommandAdapter, "decidim/spam_detection/spam_user_command_adapter"
  end
end
