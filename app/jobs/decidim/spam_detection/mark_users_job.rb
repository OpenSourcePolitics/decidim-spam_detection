# frozen_string_literal: true

module Decidim
  module SpamDetection
    class MarkUsersJob < ApplicationJob
      queue_as :default

      def perform
        mark_users_service.call
      end

      private

      def mark_users_service
        @mark_users_service ||= Decidim::SpamDetection::MarkUsersService
      end
    end
  end
end
