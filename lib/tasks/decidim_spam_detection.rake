# frozen_string_literal: true

namespace :decidim do
  namespace :spam_detection do
    desc "TODO"
    task mark_users: :environment do
      Decidim::SpamDetection::MarkUsersJob.perform_now
    end
  end
end
