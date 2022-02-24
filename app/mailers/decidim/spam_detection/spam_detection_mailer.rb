# frozen_string_literal: true

module Decidim
  module SpamDetection
    class SpamDetectionMailer < Decidim::ApplicationMailer
      helper_method :blocked_users_url, :reported_users_url

      def notify_detection(user, results)
        with_user(user) do
          @reported_count = results[:reported_user]
          @blocked_count = results[:blocked_user]
          @organization = user.organization
          @user = user

          subject = I18n.t("notify_detection.subject", scope: "decidim.spam_detection_mailer")
          mail(to: @user.email, subject: subject)
        end
      end

      private

      def blocked_users_url
        decidim_admin.moderated_users_url(blocked: true, host: root_url)
      end

      def reported_users_url
        decidim_admin.moderated_users_url(blocked: false, host: root_url)
      end

      def decidim_admin
        Decidim::Admin::Engine.routes.url_helpers
      end

      def root_url
        decidim.root_url(host: @user.organization.host)[0..-2]
      end
    end
  end
end
