# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SpamDetection
    describe ReportSpamUserCommand do
      let(:subject) { described_class.call(user, spam_probabilty) }
      let(:organization) { create(:organization) }
      let!(:user) { create(:user, organization: organization) }
      let(:spam_probabilty) { 0.1 }

      describe "#call" do
        it "reports the user" do
          expect { subject }.to change(Decidim::UserReport, :count)
        end

        it "#add spam detection metadata" do
          subject

          expect(user.reload.extended_data.dig("spam_detection", "reported_at")).not_to eq(nil)
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
