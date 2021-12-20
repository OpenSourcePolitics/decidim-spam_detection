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
      end

      def self.run
        new.ask_and_mark
      end

      def ask_and_mark
        spam_probability_array = Decidim::SpamDetection::ApiProxy.send_request_in_batch(cleaned_users)

        mark_spam_users(merge_response_with_users(spam_probability_array))
      end

      def mark_spam_users(probability_array)
        probability_array.each do |probability_hash|
          Decidim::SpamDetection::SpamUserActionFactory.for(probability_hash)
        end
      end

      def cleaned_users
        @cleaned_users ||= @users.select(PUBLICY_SEARCHABLE_COLUMNS)
                                 .map { |u| u.serializable_hash(force_except: true) }
      end

      def merge_response_with_users(response)
        response.map { |resp| resp.merge("original_user" => @users.find(resp["id"])) }
      end
    end
  end
end
