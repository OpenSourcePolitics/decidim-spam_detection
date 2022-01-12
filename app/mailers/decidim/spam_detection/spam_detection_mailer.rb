# frozen_string_literal: true

module Decidim
  module SpamDetection
    class SpamDetectionMailer < Decidim::ApplicationMailer
      def notify_detection(admin, results)
        with_user(admin) do
          @reported_count = results[:reported_user]
          @blocked_count = results[:blocked_count]
          @organization = admin.organization
          @user = admin

          subject = I18n.t("notify_detection.subject", scope: "decidim.spam_detection_mailer")
          mail(to: admin.email, subject: subject)
        end
      end
    end
  end
end
