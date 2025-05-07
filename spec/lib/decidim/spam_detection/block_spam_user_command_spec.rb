# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SpamDetection
    describe BlockSpamUserCommand do
      subject { described_class.call(user, spam_probability) }

      let(:organization) { create(:organization) }
      let!(:user) { create(:user, organization: organization) }
      let(:spam_probability) { 0.1 }

      shared_examples "a successful block" do
        it "blocks the user" do
          expect { subject }.to change(Decidim::UserBlock, :count).by(1)
        end

        it "creates a log" do
          expect { subject }.to change(Decidim::ActionLog, :count).by(1)
          expect(Decidim::ActionLog.last.extra.dig("extra", "current_justification"))
            .to eq("Our automatic spam account detection task has blocked you. If this is an error. Contact the platform administrators who will be able to restore your account.")
        end

        it "creates a moderation entry" do
          expect { subject }.to change(Decidim::UserModeration, :count).by(1)
        end

        it "adds spam detection metadata" do
          subject
          expect(user.reload.extended_data.dig("spam_detection", "blocked_at")).not_to be_nil
          expect(user.reload.extended_data.dig("spam_detection", "spam_probability")).to eq(spam_probability)
        end

        it "runs without error" do
          expect(subject).to be_success
        end

        it "broadcasts a result" do
          expect(subject.result).to eq(:ok)
        end
      end

      describe "#call" do
        include_examples "a successful block"

        context "when extended_data is nil" do
          before { user.update!(extended_data: nil) }

          it "broadcasts ok" do
            expect(subject.result).to eq(:ok)
          end
        end

        context "when nickname contains forbidden unicode characters" do
          let!(:user) do
            user = create(:user, organization: organization)
            user.nickname = "forbıdden_nıckname"
            user.save!(validate: false)
            user
          end

          include_examples "a successful block"
        end

        context "when nickname contains emojis" do
          let!(:user) do
            user = create(:user, organization: organization)
            user.nickname = "weird🤖name🚀"
            user.save!(validate: false)
            user
          end

          include_examples "a successful block"
        end

        context "when nickname contains strange accents" do
          let!(:user) do
            user = create(:user, organization: organization)
            user.nickname = "nîcknäme_çurîeux"
            user.save!(validate: false)
            user
          end

          include_examples "a successful block"
        end
      end
    end
  end
end
