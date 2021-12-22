# frozen_string_literal: true

module Decidim
  module SpamDetection
    class SpamUserCommandAdapter
      SPAM_LEVEL = { very_sure: 0.99, probable: 0.7 }.freeze

      def self.for(probability_hash)
        if probability_hash["spam_probability"] > SPAM_LEVEL[:very_sure] && perform_block_user?
          Decidim::SpamDetection::BlockSpamUserCommand.call(probability_hash["original_user"], probability_hash["spam_probability"])
        elsif probability_hash["spam_probability"] > SPAM_LEVEL[:probable]
          Decidim::SpamDetection::ReportSpamUserCommand.call(probability_hash["original_user"], probability_hash["spam_probability"])
        end
      end

      def self.perform_block_user?
        ENV.fetch("PERFORM_BLOCK_USER", false)
      end
    end
  end
end
