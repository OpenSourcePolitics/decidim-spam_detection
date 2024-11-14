# frozen_string_literal: true

module Decidim
  module SpamDetection
    class BlockUsersJob < ApplicationJob
      queue_as :default

      def perform(**args)
        level = spam_level(args[:spam_level]&.to_f)
        Rails.logger.info "Blocking users marked as spam with spam level: #{level}..."
        users = reported_spams_users(level)
        Rails.logger.info "Blocking users marked as spam: #{users.count} users found"
        users.find_each do |user|
          Decidim::SpamDetection::BlockSpamUserCommand.call(user, level).call
        end
        Rails.logger.info "Terminated..."
      end

      private

      def reported_spams_users(level)
        @reported_spams_users ||= Decidim::User.where(admin: false, blocked: false, deleted_at: nil)
                                               .where("(extended_data #> '{spam_detection, unreported_at}') is null")
                                               .where("(extended_data #> '{spam_detection, unblocked_at}') is null")
                                               .where("(extended_data -> 'spam_detection' ->> 'spam_probability')::float >= ?", level)
      end

      def spam_level(spam_level = nil)
        spam_level ||= ENV.fetch("SPAM_DETECTION_BLOCKING_LEVEL", nil)&.to_f
        spam_level || Decidim::SpamDetection::SpamUserCommandAdapter::SPAM_LEVEL[:very_sure]
      end
    end
  end
end
