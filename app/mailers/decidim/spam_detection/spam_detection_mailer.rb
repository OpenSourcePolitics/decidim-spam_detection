# frozen_string_literal: true

module Decidim
  module SpamDetection
    class SpamDetectionMailer < Decidim::ApplicationMailer
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
    end
  end
end
