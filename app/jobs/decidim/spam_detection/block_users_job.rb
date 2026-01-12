# frozen_string_literal: true

module Decidim
  module SpamDetection
    class BlockUsersJob < ApplicationJob
      queue_as :default

      BATCH_SIZE = ENV.fetch("SPAM_BLOCK_BATCH_SIZE", 50).to_i
      MAX_EXECUTION_TIME = ENV.fetch("SPAM_BLOCK_MAX_TIME", 900).to_i # 15 minutes
      PAUSE_BETWEEN_BATCHES = ENV.fetch("SPAM_BLOCK_PAUSE", 0.5).to_f

      def perform(**args)
        start_time = Time.current
        level = spam_level(args[:spam_level]&.to_f)

        total_count = count_users_safely(level)
        return if total_count.zero?

        processed = 0
        succeeded = 0
        failed = 0

        reported_spams_users(level).find_in_batches(batch_size: BATCH_SIZE) do |batch|
          elapsed = Time.current - start_time
          break if elapsed > MAX_EXECUTION_TIME

          batch_result = process_batch_safely(batch, level)
          succeeded += batch_result[:succeeded]
          failed += batch_result[:failed]
          processed += batch.size

          sleep(PAUSE_BETWEEN_BATCHES)
        end

        Rails.logger.info "[BlockUsersJob] Completed: #{succeeded} succeeded, #{failed} failed" if processed.positive?
      rescue StandardError => e
        Rails.logger.error "[BlockUsersJob] Critical error: #{e.message}"
        false
      end

      private

      def count_users_safely(level)
        Timeout.timeout(15) { reported_spams_users(level).count }
      rescue StandardError
        0
      end

      def process_batch_safely(batch, level)
        succeeded = 0
        failed = 0

        batch.each do |user|
          begin
            Timeout.timeout(20) do
              result = Decidim::SpamDetection::BlockSpamUserCommand.call(user, level)
              result.success? ? succeeded += 1 : failed += 1
            end
          rescue StandardError => e
            failed += 1
            Rails.logger.error "[BlockUsersJob] Error blocking user #{user.id}: #{e.message}"
          end

          sleep(0.1)
        end

        { succeeded: succeeded, failed: failed }
      end

      def reported_spams_users(level)
        @reported_spams_users ||= Decidim::User
                                  .where(admin: false, blocked: false, deleted_at: nil)
                                  .where("(extended_data #> '{spam_detection, unreported_at}') is null")
                                  .where("(extended_data #> '{spam_detection, unblocked_at}') is null")
                                  .where("(extended_data -> 'spam_detection' ->> 'spam_probability')::float >= ?", level)
                                  .order(:id)
      end

      def spam_level(spam_level = nil)
        spam_level ||= ENV.fetch("SPAM_DETECTION_BLOCKING_LEVEL", nil)&.to_f
        spam_level || Decidim::SpamDetection::SpamUserCommandAdapter::SPAM_LEVEL[:very_sure]
      end
    end
  end
end
