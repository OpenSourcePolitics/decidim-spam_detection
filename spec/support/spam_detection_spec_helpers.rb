# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SpamDetection
    module SpecHelpers
      def self.serialize_users(users)
        users.map do |user|
          {
            "id" => user.id,
            "decidim_organization_id" => user.decidim_organization_id,
            "sign_in_count" => user.sign_in_count,
            "personal_url" => user.personal_url,
            "about" => user.about,
            "avatar" => nil,
            "extended_data" => user.extended_data,
            "followers_count" => user.followers_count,
            "following_count" => user.following_count,
            "invitations_count" => user.invitations_count,
            "failed_attempts" => user.failed_attempts,
            "admin" => user.admin
          }
        end
      end

      def self.merge_with_users(response, users)
        user_map = users.index_by(&:id)

        response.map do |resp|
          user = user_map[resp["id"]]
          user ? resp.merge("original_user" => user) : nil
        end.compact
      end
    end
  end
end
