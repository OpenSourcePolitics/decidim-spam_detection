# frozen_string_literal: true

require 'uri'
require 'net/http'

module Decidim
  module SpamDetection
    class MarkUsersService
      include Decidim::FormFactory

      URL = 'http://localhost:8080/api'
      PUBLICY_SEARCHABLE_COLUMNS = %i[
        id
        decidim_organization_id
        sign_in_count
        personal_url
        about
        avatar
        extended_data
        followers_count
        following_count
        invitations_count
        failed_attempts
        admin
      ].freeze

      SPAM_LEVEL = { very_sure: 0.99, probable: 0.7 }.freeze

      def initialize
        @users = Decidim::User.where(admin: false)
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
        url = URI(URL)
        http = Net::HTTP.new(url.host, url.port)
        request = Net::HTTP::Post.new(url)
        request['Content-Type'] = 'application/json'
        request.body = JSON.dump(data)
        response = http.request(request)
        response.read_body
      end

      def mark_spam_users(spam_probability_users_array)
        spam_probability_users_array.each do |spam_probability_hash|
          if spam_probability_hash['spam_probability'] > SPAM_LEVEL[:very_sure]
            block_user(spam_probability_hash)
          elsif spam_probability_hash['spam_probability'] > SPAM_LEVEL[:probable]
            report_user(spam_probability_hash)
          end
        end
      end

      def block_user(spam_probability_hash)
        user = spam_probability_hash['original_user']
        admin = moderation_user_for(user)

        form = form(Decidim::Admin::BlockUserForm).from_params(
          justification: 'The user was blocked because of a high spam probability by Decidim spam detection bot'
        )

        form.define_singleton_method(:user) { user }
        form.define_singleton_method(:current_user) { admin }
        form.define_singleton_method(:blocking_user) { admin }

        Decidim::Admin::BlockUser.call(form)
        Rails.logger.info("User with id #{user['id']} was blocked for spam")
      end

      def report_user(spam_probability_hash)
        user = spam_probability_hash['original_user']
        admin = moderation_user_for(user)

        form = form(Decidim::ReportForm).from_params(
          reason: 'spam',
          details: 'The user was marked at spam by Decidim spam detection bot'
        )

        report = Decidim::CreateUserReport.new(form, user, admin)
        report.define_singleton_method(:current_organization) { admin.organization }
        report.define_singleton_method(:current_user) { admin }
        report.define_singleton_method(:reportable) { user }
        report.call

        Rails.logger.info("User with id #{user.id} was reported for spam")
      end

      def moderation_user_for(user)
        moderation_admin_params = {
          name: 'spam detection bot',
          nickname: 'Spam_detection_bot',
          email: 'spam_detection_bot@opensourcepolitcs.eu',
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
        response.map { |resp| resp.merge('original_user' => @users.find(resp['id'])) }
      end
    end
  end
end
