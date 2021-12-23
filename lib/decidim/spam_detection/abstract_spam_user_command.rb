# frozen_string_literal: true

require "uri"
require "net/http"

module Decidim
  module SpamDetection
    class AbstractSpamUserCommand
      SPAM_USER = {
        name: ENV.fetch("SPAM_DETECTION_NAME", "spam detection bot"),
        nickname: ENV.fetch("SPAM_DETECTION_NICKNAME", "Spam_detection_bot"),
        email: ENV.fetch("SPAM_DETECTION_EMAIL", "spam_detection_bot@opensourcepolitcs.eu")
      }.freeze

      include Decidim::FormFactory

      def initialize(user, probability)
        @user = user
        @probability = probability
        @moderator = moderation_user
      end

      def call
        raise NotImplementedError
      end

      def moderation_user
        moderation_admin_params = {
          name: SPAM_USER[:name],
          nickname: SPAM_USER[:nickname],
          email: SPAM_USER[:email],
          admin: true,
          organization: @user.organization
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

      def add_spam_detection_metadata!(metadata)
        @user.update!(extended_data: @user.extended_data
                                        .dup
                                        .deep_merge("spam_detection" => metadata))
      end
    end
  end
end
