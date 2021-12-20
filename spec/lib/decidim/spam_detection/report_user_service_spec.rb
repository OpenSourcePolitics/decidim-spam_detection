# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SpamDetection
    describe ReportUserService do
      let(:subject) { described_class.call(user, spam_probabilty) }
      let(:organization) { create(:organization) }
      let!(:user) { create(:user, organization: organization) }
      let(:spam_probabilty) { 0.1 }

      describe "#run" do
        it "reports the user" do
          expect { subject }.to change(Decidim::UserReport, :count)
        end

        it "#add spam detection metadata" do
          subject

          expect(user.reload.extended_data.dig("spam_detection", "reported_at")).not_to eq(nil)
          expect(user.reload.extended_data.dig("spam_detection", "spam_probability")).to eq(0.1)
        end

        context "when users have already been reported in the past" do
          let!(:users) { create_list(:user, 5, :unmarked_as_spam, organization: organization) }

          it "doesn't reports the user" do
            expect { subject }.not_to change(Decidim::UserBlock, :count)
          end
        end
      end
    end
  end
end
