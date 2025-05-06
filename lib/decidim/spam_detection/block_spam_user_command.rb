# frozen_string_literal: true

require "uri"
require "net/http"

module Decidim
  module SpamDetection
    class BlockSpamUserCommand < Decidim::SpamDetection::AbstractSpamUserCommand
      prepend Decidim::SpamDetection::Command

      def call
        ActiveRecord::Base.transaction do
          create_user_moderation
          block!
          register_justification!
          notify_user!
          add_spam_detection_metadata!({ "blocked_at" => Time.current, "spam_probability" => @probability })
        end

        Rails.logger.info("User with id #{@user["id"]} was blocked for spam with a probability of #{@probability}%")

        :ok
      end

      private

      def create_user_moderation
        @user.create_user_moderation
      end

      def register_justification!
        UserBlock.create!(justification: reason, user: @user, blocking_user: @moderator)
      end

      def notify_user!
        Decidim::BlockUserJob.perform_later(@user, reason)
      end

      def block!
        Decidim.traceability.perform_action!(
          "block",
          @user,
          @moderator,
          extra: {
            reportable_type: @user.class.name,
            current_justification: reason
          },
          resource: {
            # Make sure the action log entry gets the original user name instead
            # of "Blocked user". Otherwise the log entries would show funny
            # messages such as "Mr. Admin blocked user Blocked user"-
            title: @user.name
          }
        ) do
          @user.blocked = true
          @user.blocked_at = Time.current
          @user.blocking = @current_blocking
          update_extended_data
          @user.name = "Blocked user"
          @user.nickname = generate_nickname
          @user.save!
        end
      end

      def reason
        I18n.t("blocked_user.reason", probability: @probability)
      end

      def generate_nickname
        max_attempts = 10

        max_attempts.times do
          random_key = SecureRandom.hex(5)
          nickname = "blocked_#{random_key}"
          return nickname unless Decidim::User.exists?(nickname: nickname)
        end

        raise "Unable to generate a unique nickname after #{max_attempts} attempts."
      end

      def update_extended_data
        @user.extended_data = {} if @user.extended_data.nil?
        @user.extended_data["user_name"] = @user.name
        @user.extended_data["user_nickname"] = @user.nickname
      end
    end
  end
end
