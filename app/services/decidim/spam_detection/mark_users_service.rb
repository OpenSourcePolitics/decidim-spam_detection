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

      def initialize
        @users = Decidim::User.left_outer_joins(:user_moderation)
                              .where(decidim_user_moderations: { decidim_user_id: nil })
                              .where(admin: false, blocked: false, deleted_at: nil)
                              .where("(extended_data #> '{spam_detection, unreported_at}') is null")
                              .where("(extended_data #> '{spam_detection, unblocked_at}') is null")
        @results = {}
      end

      def self.call
        return unless Decidim::SpamDetection.service_activated?

        new.ask_and_mark
      end

      def ask_and_mark
        spam_probability_array = Decidim::SpamDetection::ApiProxy.request(cleaned_users)

        mark_spam_users(merge_response_with_users(spam_probability_array))
        notify_admins!
      end

      def mark_spam_users(probability_array)
        probability_array.each do |probability_hash|
          result = Decidim::SpamDetection::SpamUserCommandAdapter.call(probability_hash).result
          organization_id = probability_hash["decidim_organization_id"]

          add_to_results(organization_id.to_s, result)
        end
      end

      def cleaned_users
        @cleaned_users ||= @users.select(PUBLICY_SEARCHABLE_COLUMNS)
                                 .map { |u| u.serializable_hash(force_except: true) }
      end

      def merge_response_with_users(response)
        response.map { |resp| resp.merge("original_user" => @users.find(resp["id"])) }
      end

      def status
        @results.each_with_object({}) do |result, hash|
          hash[result[0]] = result[1].tally
        end
      end

      def notify_admins!
        Decidim::SpamDetection::NotifyAdmins.perform_later(status)
      end

      private

      def add_to_results(organization_id, result)
        if @results[organization_id]
          @results[organization_id] << result
        else
          @results[organization_id] = [result]
        end
      end
    end
  end
end
