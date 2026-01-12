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

      def initialize
        @base_query = Decidim::User.left_outer_joins(:user_moderation)
                                   .where(decidim_user_moderations: { decidim_user_id: nil })
                                   .where(admin: false, blocked: false, deleted_at: nil)
                                   .where("(extended_data #> '{spam_detection, unreported_at}') is null")
                                   .where("(extended_data #> '{spam_detection, unblocked_at}') is null")
                                   .order(:id)
        @results = {}
        @processed_count = 0
        @error_count = 0
      end

      def self.call
        return false unless Decidim::SpamDetection.service_activated?

        new.ask_and_mark
      rescue StandardError
        false
      end

      def ask_and_mark
        total_count = count_total_users
        return true if total_count.zero?

        process_in_batches(total_count)
        notify_admins! if @results.any?

        true
      rescue StandardError
        false
      end

      def cleaned_users
        @cleaned_users ||= @base_query.select(PUBLICY_SEARCHABLE_COLUMNS)
                                      .map { |u| u.serializable_hash(force_except: true) }
      end

      def merge_response_with_users(response, users = nil)
        user_map = (users || @base_query.to_a).index_by(&:id)
        response.map do |resp|
          user = user_map[resp["id"]]
          user ? resp.merge("original_user" => user) : nil
        end.compact
      end

      def mark_spam_users(probability_array)
        probability_array.each do |probability_hash|
          Timeout.timeout(10) do
            result = Decidim::SpamDetection::SpamUserCommandAdapter.call(probability_hash).result
            organization_id = probability_hash["decidim_organization_id"]
            add_to_results(organization_id.to_s, result)
          end
        rescue StandardError
          @error_count += 1
        end
      end

      def status
        @results.each_with_object({}) do |result, hash|
          hash[result[0]] = result[1].tally
        end
      end

      def notify_admins!
        Decidim::SpamDetection::NotifyAdmins.perform_later(status)
      rescue StandardError => e
        Rails.logger.error "[SpamDetection] Failed to notify admins: #{e.message}"
      end

      private

      def count_total_users
        Timeout.timeout(15) { @base_query.count }
      rescue StandardError
        0
      end

      def process_in_batches(_total_count)
        offset = 0

        loop do
          batch = fetch_batch(offset)
          break if batch.empty?

          process_batch(batch)
          @processed_count += batch.size

          offset += BATCH_SIZE
          sleep(0.5)
        end
      end

      def fetch_batch(offset)
        Timeout.timeout(30) do
          @base_query.select(PUBLICY_SEARCHABLE_COLUMNS)
                     .offset(offset)
                     .limit(BATCH_SIZE)
                     .to_a
        end
      rescue StandardError
        []
      end

      def process_batch(batch_users)
        return if batch_users.empty?

        cleaned_batch = batch_users.map { |u| u.serializable_hash(force_except: true) }
        spam_probability_array = call_api_with_timeout(cleaned_batch)

        return if spam_probability_array.blank?

        merged_results = merge_response_with_users(spam_probability_array, batch_users)
        mark_spam_users(merged_results)
      rescue StandardError
        @error_count += batch_users.size
      end

      def call_api_with_timeout(cleaned_batch)
        Timeout.timeout(API_TIMEOUT) do
          Decidim::SpamDetection::ApiProxy.request(cleaned_batch)
        end
      rescue Timeout::Error => e
        Rails.logger.error "[SpamDetection] API timeout: #{e.message}"
        nil
      rescue StandardError => e
        Rails.logger.error "[SpamDetection] API error: #{e.message}"
        nil
      end

      def add_to_results(organization_id, result)
        @results[organization_id] ||= []
        @results[organization_id] << result
      end
    end
  end
end
