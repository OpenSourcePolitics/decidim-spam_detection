# frozen_string_literal: true

module Decidim
  module Admin
    class UnreportUser < Rectify::Command
      # Public: Initializes the command.
      #
      # reportable - A Decidim::User - The user reported
      # current_user - the user performing the action
      def initialize(reportable, current_user)
        @reportable = reportable
        @current_user = current_user
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid, together with the resource.
      # - :invalid if the resource is not reported
      #
      # Returns nothing.
      def call
        return broadcast(:invalid) unless @reportable.reported?

        unreport!
        add_spam_detection_metadata!
        broadcast(:ok, @reportable)
      end

      private

      def unreport!
        Decidim.traceability.perform_action!(
          "unreport",
          @reportable.user_moderation,
          @current_user,
          extra: {
            reportable_type: @reportable.class.name,
            username: @reportable.name,
            user_id: @reportable.id
          }
        ) do
          @reportable.user_moderation.destroy!
        end
      end

      def add_spam_detection_metadata!
        return if @reportable.extended_data.dig("spam_detection", "marked_as_spam_at").blank?

        @reportable.update!(extended_data: @reportable.extended_data.dup.deep_merge("spam_detection" => { "unreported_at": Time.current }))
      end
    end
  end
end
