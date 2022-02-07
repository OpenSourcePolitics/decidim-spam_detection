# frozen_string_literal: true

module Decidim
  module SpamDetection
    class NotifyAdmins < ApplicationJob
      queue_as :default

      def perform(results_hash)
        results_hash.each do |id, result|
          next if result.keys == [:nothing]

          Decidim::Organization.find(id).admins.each do |admin|
            Decidim::SpamDetection::SpamDetectionMailer.notify_detection(admin, result).deliver_later
          end
        end
      end
    end
  end
end
