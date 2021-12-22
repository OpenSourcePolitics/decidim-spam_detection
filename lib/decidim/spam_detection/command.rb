require 'decidim/spam_detection/command_errors'

module Decidim
  module SpamDetection
    module Command
      attr_reader :result

      module ClassMethods
        def call(*args, **kwargs)
          new(*args, **kwargs).call
        end
      end

      def self.prepended(base)
        base.extend ClassMethods
      end

      def call
        fail NotImplementedError unless defined?(super)

        @called = true
        @result = super

        self
      end

      def success?
        called? && !failure?
      end

      def failure?
        called? && errors.any?
      end

      def errors
        return super if defined?(super)

        @errors ||= Decidim::SpamDetection::CommandErrors.new
      end

      private

      def called?
        @called ||= false
      end
    end
  end
end