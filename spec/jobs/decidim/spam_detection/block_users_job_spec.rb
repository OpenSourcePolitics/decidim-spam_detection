# frozen_string_literal: true

require "spec_helper"

describe Decidim::SpamDetection::BlockUsersJob do
  subject { described_class }

  let!(:users) { create_list(:user, 5, :marked_as_spam_very_sure) }
  let!(:users_not_sure) { create_list(:user, 5, :marked_as_spam) }

  describe "#perform" do
    it "blocks reported users" do
      expect do
        subject.perform_now
      end.to change { Decidim::User.blocked.count }.by(5)
    end
  end
end
