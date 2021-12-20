# frozen_string_literal: true

require "uri"
require "net/http"

module Decidim
  module SpamDetection
    class MarkUsersService
      URL = ENV.fetch("SPAM_DETECTION_API_URL", "http://localhost:8080/api")
      AUTH_TOKEN = ENV.fetch("SPAM_DETECTION_API_AUTH_TOKEN", "dummy")

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
        spam_probability_array = send_request_in_batch(cleaned_users)

        mark_spam_users(merge_response_with_users(spam_probability_array))
      end

      def send_request_in_batch(data_array, batch_size = 1000)
        responses = []
        data_array.each_slice(batch_size) do |subdata_array|
          responses << JSON.parse(send_request_to_api(subdata_array))
        end

        responses.flatten
      end

      def send_request_to_api(data)
        retries = [3, 5, 10]
        url = URI(URL)
        http = Net::HTTP.new(url.host, url.port)
        request = Net::HTTP::Post.new(url)
        request["Content-Type"] = "application/json"
        request["AUTH_TOKEN"] = AUTH_TOKEN
        request.body = JSON.dump(data)
        http.use_ssl = true if use_ssl?(url)
        response = http.request(request)
        response.read_body
      rescue Net::ReadTimeout
        raise Net::ReadTimeout if retries.empty?

        sleep retries.first
        retries.shift
        retry
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

      def use_ssl?(url)
        url.scheme == "https"
      end
    end
  end
end
