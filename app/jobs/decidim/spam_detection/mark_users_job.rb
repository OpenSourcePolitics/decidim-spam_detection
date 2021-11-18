module Decidim
  module SpamDetection
    class MarkUsersJob < Decidim::SpamDetection::ApplicationJob
      queue_as :default

      def perform
        mark_users_service.run
      end

      private

      def mark_users_service
        @mark_users_service ||= Decidim::SpamDetection::MarkUsersService
      end
    end
  end
end
