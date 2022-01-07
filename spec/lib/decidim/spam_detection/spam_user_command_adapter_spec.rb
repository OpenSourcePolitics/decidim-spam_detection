# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SpamDetection
    describe SpamUserCommandAdapter do
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

      describe "#call" do
        context "when spam_probility is below probable" do
          let(:spam_probability) { 0.1 }

          it "does nothing" do
            expect(Decidim::SpamDetection::BlockSpamUserCommand).not_to receive(:call).with(user, spam_probability)
            expect(Decidim::SpamDetection::ReportSpamUserCommand).not_to receive(:call).with(user, spam_probability)

            subject.call(user_hash)
          end

          it "runs without error" do
            expect(subject.call(user_hash)).to be_success
          end

          it "broadcast a result" do
            expect(subject.call(user_hash).result).to eq(:nothing)
          end
        end

        context "when spam_probility is between very_sure and probable" do
          let(:spam_probability) { 0.8 }

          context "when perform_block_user is set to true" do
            before do
              allow(subject).to receive(:perform_block_user?).and_return(true)
            end

            it "calls report_user method" do
              expect(Decidim::SpamDetection::BlockSpamUserCommand).not_to receive(:call).with(user, spam_probability)
              expect(Decidim::SpamDetection::ReportSpamUserCommand).to receive(:call).with(user, spam_probability).once

              subject.call(user_hash)
            end

            it "runs without error" do
              expect(subject.call(user_hash)).to be_success
            end

            it "broadcast a result" do
              expect(subject.call(user_hash).result).to eq(:reported_user)
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
              expect(Decidim::SpamDetection::BlockSpamUserCommand).to receive(:call).with(user, spam_probability).once
              expect(Decidim::SpamDetection::ReportSpamUserCommand).not_to receive(:call).with(user, spam_probability)

              subject.call(user_hash)
            end

            it "runs without error" do
              expect(subject.call(user_hash)).to be_success
            end

            it "broadcast a result" do
              expect(subject.call(user_hash).result).to eq(:blocked_user)
            end
          end

          it "calls report_user method" do
            expect(Decidim::SpamDetection::BlockSpamUserCommand).not_to receive(:call).with(user, spam_probability)
            expect(Decidim::SpamDetection::ReportSpamUserCommand).to receive(:call).with(user, spam_probability).once

            subject.call(user_hash)
          end

          it "runs without error" do
            expect(subject.call(user_hash)).to be_success
          end

          it "broadcast a result" do
            expect(subject.call(user_hash).result).to eq(:reported_user)
          end
        end
      end
    end
  end
end
