# frozen_string_literal: true

namespace :decidim do
  namespace :spam_detection do
    desc "Call the external Spam Detection service"
    task block_users: :environment do
      Decidim::SpamDetection::BlockUsersJob.perform_later
    end
  end
end
