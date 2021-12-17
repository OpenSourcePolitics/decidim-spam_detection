# frozen_string_literal: true

namespace :decidim do
  namespace :spam_detection do
    desc "Call the external Spam Detection service"
    task mark_users: :environment do
      Decidim::SpamDetection::MarkUsersJob.perform_now
    end
  end
end
