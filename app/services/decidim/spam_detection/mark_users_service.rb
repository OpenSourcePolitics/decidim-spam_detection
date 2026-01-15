# frozen_string_literal: true

require "uri"
require "net/http"

module Decidim
  module SpamDetection
    class MarkUsersService
      PUBLICY_SEARCHABLE_COLUMNS = [
        :id,
        :decidim_organization_id,
        :sign_in_count,
        :personal_url,
        :about,
        :avatar,
        :extended_data,
        :followers_count,
        :following_count,
        :invitations_count,
        :failed_attempts,
        :admin
      ].freeze

      BATCH_SIZE = ENV.fetch("SPAM_DETECTION_BATCH_SIZE", 100).to_i
      API_TIMEOUT = ENV.fetch("SPAM_DETECTION_API_TIMEOUT", 90).to_i
      SLEEP_BETWEEN_BATCHES = ENV.fetch("SPAM_DETECTION_SLEEP", 0.3).to_f

      def initialize
        @base_query =
          Decidim::User
          .left_outer_joins(:user_moderation)
          .where(decidim_user_moderations: { decidim_user_id: nil })
          .where(admin: false, blocked: false, deleted_at: nil)
          .where("(extended_data #> '{spam_detection, unreported_at}') IS NULL")
          .where("(extended_data #> '{spam_detection, unblocked_at}') IS NULL")
          .order(:id)

        @results = {}
        @processed_count = 0
        @error_count = 0
      end

      def self.call
        return false unless Decidim::SpamDetection.service_activated?

        new.ask_and_mark
      rescue StandardError => e
        Rails.logger.error("[SpamDetection] Fatal error: #{e.class} - #{e.message}")
        false
      end

      def ask_and_mark
        total = count_total_users
        Rails.logger.info("[SpamDetection] Starting spam detection for #{total} users") if total.positive?
        return true if total.zero?

        process_in_batches

        notify_final_summary! if @processed_count.positive?
        true
      end

      def status
        @results.each_with_object({}) do |result, hash|
          hash[result[0]] = result[1].tally
        end
      end

      private

      def process_in_batches
        last_id = 0

        loop do
          batch =
            @base_query
            .where("decidim_users.id > ?", last_id)
            .limit(BATCH_SIZE)
            .to_a

          break if batch.empty?

          Rails.logger.info("[SpamDetection] Processing batch #{batch.first.id}-#{batch.last.id} (#{batch.size} users)")

          process_batch(batch)

          @processed_count += batch.size
          Rails.logger.info("[SpamDetection] Total processed: #{@processed_count}, Errors: #{@error_count}")

          if @results.any?
            notify_admins_for_batch!
            @results.clear
          end

          last_id = batch.last.id
          sleep(SLEEP_BETWEEN_BATCHES)
        end
      rescue StandardError => e
        Rails.logger.error("[SpamDetection] Batch loop error: #{e.class} - #{e.message}")
      end

      def process_batch(batch_users)
        cleaned = serialize_batch(batch_users)

        response = call_api_with_timeout(cleaned)
        return if response.blank?

        merged = merge_response_with_users(response, batch_users)
        mark_spam_users(merged)

        Rails.logger.info("[SpamDetection] Batch processed: #{batch_users.size} users, #{@error_count} errors so far")
      rescue StandardError => e
        @error_count += batch_users.size
        Rails.logger.error("[SpamDetection] Batch processing failed: #{e.class} - #{e.message}")
      end

      def serialize_batch(batch_users)
        batch_users.map do |u|
          hash = u.serializable_hash(force_except: true)
          hash["avatar"] = nil if hash["avatar"].is_a?(ActiveStorage::Attached::One)
          hash
        end
      end

      def merge_response_with_users(response, batch_users)
        user_map = batch_users.index_by(&:id)

        response.map do |resp|
          user = user_map[resp["id"]]
          user ? resp.merge("original_user" => user) : nil
        end.compact
      end

      def mark_spam_users(probability_array)
        probability_array.each do |probability_hash|
          result =
            Decidim::SpamDetection::SpamUserCommandAdapter
            .call(probability_hash)
            .result

          add_to_results(
            probability_hash["decidim_organization_id"].to_s,
            result
          )
        rescue StandardError => e
          @error_count += 1
          Rails.logger.warn("[SpamDetection] Marking user failed: #{e.class} - #{e.message}")
        end
      end

      def call_api_with_timeout(cleaned_batch)
        Timeout.timeout(API_TIMEOUT) do
          Decidim::SpamDetection::ApiProxy.request(cleaned_batch)
        end
      rescue StandardError => e
        Rails.logger.warn("[SpamDetection] API call failed: #{e.class} - #{e.message}")
        nil
      end

      def count_total_users
        @base_query.count
      rescue StandardError => e
        Rails.logger.error("[SpamDetection] Counting users failed: #{e.class} - #{e.message}")
        0
      end

      def add_to_results(organization_id, result)
        @results[organization_id] ||= []
        @results[organization_id] << result
      end

      def notify_admins_for_batch!
        return unless @results.any?

        Decidim::SpamDetection::NotifyAdmins.perform_later(status)
        Rails.logger.info("[SpamDetection] Notified admins for batch: #{status}")
      rescue StandardError => e
        Rails.logger.error("[SpamDetection] Failed to notify admins for batch: #{e.message}")
      end

      def notify_final_summary!
        Rails.logger.info("[SpamDetection] Completed. Total processed: #{@processed_count}, Errors: #{@error_count}")
      rescue StandardError => e
        Rails.logger.error("[SpamDetection] Failed to log final summary: #{e.message}")
      end
    end
  end
end
