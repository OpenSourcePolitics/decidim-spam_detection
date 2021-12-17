# frozen_string_literal: true

require "uri"
require "net/http"

module Decidim
  module SpamDetection
    class ReportUserService < Decidim::SpamDetection::AbstractUserService
      def self.call(user, probability)
        new(user, probability).run
      end

      def run
        return if previously_unmarked?

        form = form(Decidim::ReportForm).from_params(
          reason: "spam",
          details: "The user was marked as spam by Decidim spam detection bot"
        )

        current_organization = @user.organization
        moderator = @moderator
        user = @user

        report = Decidim::CreateUserReport.new(form, user, moderator)
        report.define_singleton_method(:current_organization) { current_organization }
        report.define_singleton_method(:current_user) { moderator }
        report.define_singleton_method(:reportable) { user }
        report.call

        add_spam_detection_metadata!({
                                       "reported_at" => Time.current,
                                       "spam_probability" => @probability
                                     })

        Rails.logger.info("User with id #{user.id} was reported for spam")
      end

      private

      def previously_unmarked?
        @user.extended_data.dig("spam_detection", "unreported_at").present?
      end
    end
  end
end
