# frozen_string_literal: true

require "decidim/spam_detection/admin"
require "decidim/spam_detection/engine"
require "decidim/spam_detection/admin_engine"

module Decidim
  # This namespace holds the logic of the `SpamDetection` component. This component
  # allows users to create spam_detection in a participatory space.
  module SpamDetection
    autoload :ApiProxy, "decidim/spam_detection/api_proxy"
    autoload :AbstractSpamUserAction, "decidim/spam_detection/abstract_spam_user_action"
    autoload :ReportSpamUserAction, "decidim/spam_detection/report_spam_user_action"
    autoload :BlockSpamUserAction, "decidim/spam_detection/block_spam_user_action"
    autoload :SpamUserActionFactory, "decidim/spam_detection/spam_user_action_factory"
  end
end
