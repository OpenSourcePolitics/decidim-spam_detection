# frozen_string_literal: true

module Decidim
  module SpamDetection
    class BlockUsersJob < ApplicationJob
      queue_as :default

      def perform
        Rails.logger.info "Blocking users marked as spam"
        users = reported_spams_users
        Rails.logger.info "Blocking users marked as spam: #{users.count} users found"
        users.find_each do |user|
          Decidim::SpamDetection::BlockSpamUserCommand.call(user, spam_level).call
        end
        Rails.logger.info "Terminated..."
      end

      private

      def reported_spams_users
        @reported_spams_users ||= Decidim::User.where(admin: false, blocked: false, deleted_at: nil)
                                               .where("(extended_data #> '{spam_detection, unreported_at}') is null")
                                               .where("(extended_data #> '{spam_detection, unblocked_at}') is null")
                                               .where("(extended_data -> 'spam_detection' ->> 'probability')::float >= ?", spam_level)
      end

      def spam_level
        Decidim::SpamDetection::SpamUserCommandAdapter::SPAM_LEVEL[:very_sure]
      end
    end
  end
end
