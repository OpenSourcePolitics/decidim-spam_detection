# frozen_string_literal: true

require "uri"
require "net/http"

module Decidim
  module SpamDetection
    class BlockSpamUserAction < Decidim::SpamDetection::AbstractSpamUserAction
      def run
        form = form(Decidim::Admin::BlockUserForm).from_params(
          justification: "The user was blocked because of a high spam probability by Decidim spam detection bot"
        )

        moderator = @moderator
        user = @user

        form.define_singleton_method(:user) { user }
        form.define_singleton_method(:current_user) { moderator }
        form.define_singleton_method(:blocking_user) { moderator }

        Decidim::Admin::BlockUser.call(form)

        add_spam_detection_metadata!({
                                       "blocked_at" => Time.current,
                                       "spam_probability" => @probability
                                     })

        @user.create_user_moderation
        Rails.logger.info("User with id #{@user["id"]} was blocked for spam")
      end
    end
  end
end
