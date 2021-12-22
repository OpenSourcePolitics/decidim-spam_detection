# frozen_string_literal: true

module Decidim
  module SpamDetection
    class SpamUserCommandAdapter
      prepend Decidim::SpamDetection::Command
      SPAM_LEVEL = { very_sure: 0.99, probable: 0.7 }.freeze

      def self.perform_block_user?
        ENV.fetch("PERFORM_BLOCK_USER", false)
      end

      def initialize(probability_hash)
        @probability = probability_hash["spam_probability"]
        @user = probability_hash["original_user"]
      end

      def call
        if @probability > SPAM_LEVEL[:very_sure] && self.class.perform_block_user?
          Decidim::SpamDetection::BlockSpamUserCommand.call(@user, @probability)
          :blocked_user
        elsif @probability > SPAM_LEVEL[:probable]
          Decidim::SpamDetection::ReportSpamUserCommand.call(@user, @probability)
          :reported_user
        else
          :nothing
        end
      end
    end
  end
end
