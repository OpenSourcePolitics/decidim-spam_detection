# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SpamDetection
    describe BlockSpamUserCommand do
      let(:subject) { described_class.call(user, spam_probabilty) }
      let(:organization) { create(:organization) }
      let!(:user) { create(:user, organization: organization) }
      let(:spam_probabilty) { 0.1 }

      describe "#call" do
        it "blocks the user" do
          expect { subject }.to change(Decidim::UserBlock, :count)
        end

        it "creates a log" do
          expect { subject }.to change(Decidim::ActionLog, :count)
          expect(Decidim::ActionLog.last.extra.dig("extra", "current_justification")).to eq("The user was blocked because of a high spam probability by Decidim spam detection bot with a probability of #{spam_probabilty}%")
        end

        it "create a moderation entry" do
          expect { subject }.to change(Decidim::UserModeration, :count)
        end

        it "add spam detection metadata" do
          subject

          expect(user.reload.extended_data.dig("spam_detection", "blocked_at")).not_to eq(nil)
          expect(user.reload.extended_data.dig("spam_detection", "spam_probability")).to eq(0.1)
        end

        it "runs without error" do
          expect(subject).to be_success
        end

        it "broadcast a result" do
          expect(subject.result).to eq(:ok)
        end
      end
    end
  end
end
