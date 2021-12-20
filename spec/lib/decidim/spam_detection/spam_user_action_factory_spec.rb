# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SpamDetection
    describe SpamUserActionFactory do
      let(:subject) { described_class }
      let(:organization) { create(:organization) }
      let!(:user) { create(:user, organization: organization) }
      let(:users_instance_variable) { subject.instance_variable_get(:@users) }
      let!(:admins) { create_list(:user, 1, :admin, organization: organization) }
      let(:mark_user_service) { Decidim::SpamDetection::MarkUsersService.new }
      let(:user_hash) do
        mark_user_service.merge_response_with_users(mark_user_service.cleaned_users)
                         .map { |user| user.merge("spam_probability" => spam_probability) }
                         .first
      end

      describe ".for" do
        context "when spam_probility is below probable" do
          let(:spam_probability) { 0.1 }

          it "does nothing" do
            expect(Decidim::SpamDetection::BlockSpamUserAction).not_to receive(:call).with(user, spam_probability)
            expect(Decidim::SpamDetection::ReportSpamUserAction).not_to receive(:call).with(user, spam_probability)

            subject.for(user_hash)
          end
        end

        context "when spam_probility is between very_sure and probable" do
          let(:spam_probability) { 0.8 }

          context "when perform_block_user is set to true" do
            before do
              allow(subject).to receive(:perform_block_user?).and_return(true)
            end

            it "calls report_user method" do
              expect(Decidim::SpamDetection::BlockSpamUserAction).not_to receive(:call).with(user, spam_probability)
              expect(Decidim::SpamDetection::ReportSpamUserAction).to receive(:call).with(user, spam_probability).once

              subject.for(user_hash)
            end
          end
        end

        context "when spam_probility is above very_sure" do
          let(:spam_probability) { 0.999 }

          context "when perform_block_user is set to true" do
            before do
              allow(subject).to receive(:perform_block_user?).and_return(true)
            end

            it "calls block_user method" do
              expect(Decidim::SpamDetection::BlockSpamUserAction).to receive(:call).with(user, spam_probability).once
              expect(Decidim::SpamDetection::ReportSpamUserAction).not_to receive(:call).with(user, spam_probability)

              subject.for(user_hash)
            end
          end

          it "calls report_user method" do
            expect(Decidim::SpamDetection::BlockSpamUserAction).not_to receive(:call).with(user, spam_probability)
            expect(Decidim::SpamDetection::ReportSpamUserAction).to receive(:call).with(user, spam_probability).once

            subject.for(user_hash)
          end
        end
      end
    end
  end
end
