# frozen_string_literal: true

require "uri"
require "net/http"

module Decidim
  module SpamDetection
    class MarkUsersService
      include Decidim::FormFactory

      URL = ENV.fetch("SPAM_DETECTION_API_URL", "http://localhost:8080/api")
      SPAM_USER = {
        name: ENV.fetch("SPAM_DETECTION_NAME", "spam detection bot"),
        nickname: ENV.fetch("SPAM_DETECTION_NICKNAME", "Spam_detection_bot"),
        email: ENV.fetch("SPAM_DETECTION_EMAIL", "spam_detection_bot@opensourcepolitcs.eu")
      }.freeze
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

      SPAM_LEVEL = { very_sure: 0.99, probable: 0.7 }.freeze

      def initialize
        @users = Decidim::User.left_outer_joins(:user_moderation)
                              .where(decidim_user_moderations: { decidim_user_id: nil })
                              .where(admin: false, blocked: false)
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
          if probability_hash["spam_probability"] > SPAM_LEVEL[:very_sure] && perform_block_user?
            block_user(probability_hash)
          elsif probability_hash["spam_probability"] > SPAM_LEVEL[:probable]
            report_user(probability_hash)
          end
        end
      end

      def block_user(probability_hash)
        user = probability_hash["original_user"]
        return if previously_unblocked?(user)

        admin = moderation_user_for(user)

        form = form(Decidim::Admin::BlockUserForm).from_params(
          justification: "The user was blocked because of a high spam probability by Decidim spam detection bot"
        )

        form.define_singleton_method(:user) { user }
        form.define_singleton_method(:current_user) { admin }
        form.define_singleton_method(:blocking_user) { admin }

        Decidim::Admin::BlockUser.call(form)

        add_spam_detection_metadata!(user, {
                                       "blocked_as_spam_at" => Time.current,
                                       "spam_probability" => probability_hash["spam_probability"]
                                     })

        Rails.logger.info("User with id #{user["id"]} was blocked for spam")
      end

      def report_user(probability_hash)
        user = probability_hash["original_user"]
        return if previously_unmarked?(user)

        admin = moderation_user_for(user)

        form = form(Decidim::ReportForm).from_params(
          reason: "spam",
          details: "The user was marked at spam by Decidim spam detection bot"
        )

        report = Decidim::CreateUserReport.new(form, user, admin)
        report.define_singleton_method(:current_organization) { admin.organization }
        report.define_singleton_method(:current_user) { admin }
        report.define_singleton_method(:reportable) { user }
        report.call

        add_spam_detection_metadata!(user, {
                                       "marked_as_spam_at" => Time.current,
                                       "spam_probability" => probability_hash["spam_probability"]
                                     })

        Rails.logger.info("User with id #{user.id} was reported for spam")
      end

      def moderation_user_for(user)
        moderation_admin_params = {
          name: SPAM_USER[:name],
          nickname: SPAM_USER[:nickname],
          email: SPAM_USER[:email],
          admin: true,
          organization: user.organization
        }

        moderation_admin = Decidim::User.find_by(moderation_admin_params)

        return moderation_admin unless moderation_admin.nil?

        create_moderation_admin(moderation_admin_params)
      end

      def create_moderation_admin(params)
        password = ::Devise.friendly_token(::Devise.password_length.last)
        additional_params = {
          password: password,
          password_confirmation: password,
          tos_agreement: true,
          email_on_notification: false,
          email_on_moderations: false
        }
        moderation_admin = Decidim::User.new(params.merge(additional_params))
        moderation_admin.skip_confirmation!
        moderation_admin.save
        moderation_admin
      end

      def cleaned_users
        @cleaned_users ||= @users.select(PUBLICY_SEARCHABLE_COLUMNS)
                                 .map { |u| u.serializable_hash(force_except: true) }
      end

      def merge_response_with_users(response)
        response.map { |resp| resp.merge("original_user" => @users.find(resp["id"])) }
      end

      def perform_block_user?
        ENV.fetch("PERFORM_BLOCK_USER", false)
      end

      def use_ssl?(url)
        url.scheme == "https"
      end

      def add_spam_detection_metadata!(user, metadata)
        user.update!(extended_data: user.extended_data
                                        .dup
                                        .deep_merge("spam_detection" => metadata))
      end

      def previously_unblocked?(user)
        user.extended_data.dig("spam_detection", "unblocked_at").present?
      end

      def previously_unmarked?(user)
        user.extended_data.dig("spam_detection", "unreported_at").present?
      end
    end
  end
end
