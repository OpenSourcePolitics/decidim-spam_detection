# frozen_string_literal: true

require "uri"
require "net/http"

module Decidim
  module SpamDetection
    class ReportSpamUserCommand < Decidim::SpamDetection::AbstractSpamUserCommand
      prepend Decidim::SpamDetection::Command

      def call
        ActiveRecord::Base.transaction do
          find_or_create_moderation!
          create_report!
          update_report_count!
          add_spam_detection_metadata!({ "reported_at" => Time.current, "spam_probability" => @probability })
        end

        Rails.logger.info("User with id #{@user.id} was reported for spam with a probability of #{@probability}%")

        :ok
      end

      private

      def reason
        "spam"
      end

      def details
        I18n.t("reported_user.details", probability: @probability)
      end

      def find_or_create_moderation!
        @moderation = UserModeration.find_or_create_by!(user: @user)
      end

      def create_report!
        @report = UserReport.create!(
          moderation: @moderation,
          user: @moderator,
          reason: reason,
          details: details
        )
      end

      def update_report_count!
        @moderation.update!(report_count: @moderation.report_count + 1)
      end
    end
  end
end
