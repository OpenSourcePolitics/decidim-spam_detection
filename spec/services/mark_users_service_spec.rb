# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SpamDetection
    describe MarkUsersService do
      let(:subject) { described_class.new }
      let(:organization) { create(:organization) }
      let!(:users) { create_list(:user, 5, organization: organization) }
      let(:users_instance_variable) { subject.instance_variable_get(:@users) }
      let!(:admins) { create_list(:user, 5, :admin, organization: organization) }
      let(:user_hash) do
        subject.merge_response_with_users(
          subject.cleaned_users
        ).first
      end

      describe "initialize" do
        it "returns an array" do
          expect(users_instance_variable).to be_kind_of(ActiveRecord::Relation)
        end

        it "doesn't includes admin in the array" do
          expect(users_instance_variable.length).to eq(5)
        end

        context "when user is already blocked" do
          let!(:already_blocked_user) { create(:user, :blocked, organization: organization) }

          it "is not included in the query" do
            expect(users_instance_variable.length).to eq(5)
            expect(users_instance_variable).not_to include(already_blocked_user)
          end
        end

        context "when user is already moderated" do
          let!(:already_moderated_user) { create(:user, organization: organization) }
          let!(:user_moderation) { create(:user_moderation, user: already_moderated_user) }

          it "is not included in the query" do
            expect(users_instance_variable.length).to eq(5)
            expect(users_instance_variable).not_to include(already_moderated_user)
          end
        end

        context "when user has deleted his account" do
          let!(:already_deleted_user) { create(:user, :deleted, organization: organization) }

          it "is not included in the query" do
            expect(users_instance_variable.length).to eq(5)
            expect(users_instance_variable).not_to include(already_deleted_user)
          end
        end
      end

      describe ".cleaned_users" do
        let(:publicy_searchable_columns) do
          [:id, :decidim_organization_id, :sign_in_count, :personal_url, :about, :avatar, :extended_data, :followers_count, :following_count, :invitations_count, :failed_attempts, :admin].freeze
        end

        it "returns an array of hash" do
          expect(subject.cleaned_users.map(&:class)).to eq([Hash] * 5)
        end

        it "returns a hash of publicy_searchable_columns" do
          expect(subject.cleaned_users.first.keys.map(&:to_sym)).to match_array(publicy_searchable_columns)
        end

        it "doesn't include email or password" do
          expect(subject.cleaned_users.select { |user_hash| user_hash["email"] }).to eq([])
          expect(subject.cleaned_users.select { |user_hash| user_hash["password"] }).to eq([])
          expect(subject.cleaned_users.select { |user_hash| user_hash["password_confirmation"] }).to eq([])
        end
      end

      describe "#mark_spam_users" do
        let(:users_array) { [user_hash.merge("spam_probability" => spam_probability)] }

        context "when spam_probility is below probable" do
          let(:spam_probability) { 0.1 }

          it "does nothing" do
            instance = subject

            expect(Decidim::SpamDetection::BlockSpamUserAction).not_to receive(:call).with(users.first, spam_probability)
            expect(Decidim::SpamDetection::ReportSpamUserAction).not_to receive(:call).with(users.first, spam_probability)

            instance.mark_spam_users(users_array)
          end
        end

        context "when spam_probility is between very_sure and probable" do
          let(:spam_probability) { 0.8 }

          context "when perform_block_user is set to true" do
            before do
              allow(subject).to receive(:perform_block_user?).and_return(true)
            end

            it "calls report_user method" do
              instance = subject

              expect(Decidim::SpamDetection::BlockSpamUserAction).not_to receive(:call).with(users.first, spam_probability)
              expect(Decidim::SpamDetection::ReportSpamUserAction).to receive(:call).with(users.first, spam_probability).once

              instance.mark_spam_users(users_array)
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
              instance = subject

              expect(Decidim::SpamDetection::BlockSpamUserAction).to receive(:call).with(users.first, spam_probability).once
              expect(Decidim::SpamDetection::ReportSpamUserAction).not_to receive(:call).with(users.first, spam_probability)

              instance.mark_spam_users(users_array)
            end
          end

          it "calls report_user method" do
            instance = subject

            expect(Decidim::SpamDetection::BlockSpamUserAction).not_to receive(:call).with(users.first, spam_probability)
            expect(Decidim::SpamDetection::ReportSpamUserAction).to receive(:call).with(users.first, spam_probability).once

            instance.mark_spam_users(users_array)
          end
        end
      end

      describe "#send_request_to_api" do
        let(:users_data) { subject.cleaned_users }
        let(:returned_users_data) do
          users_data.map do |user_data|
            user_data.merge("spam_proability" => Random.new.rand(100.0))
          end
        end
        let(:url) { "http://localhost:8080/api" }

        before do
          stub_request(:post, url).with(
            body: JSON.dump(users_data),
            headers: {
              "Content-Type" => "application/json"
            }
          ).to_return(body: JSON.dump(returned_users_data))
        end

        it "sends an api call" do
          expect(subject.send_request_to_api(users_data)).to eq(JSON.dump(returned_users_data))
        end
      end

      describe "#send_request_in_batch" do
        let(:subdata_array) { ["foo" => "bar"] }
        let(:data_array) { subdata_array * 5 }

        it "concatenates the responses" do
          instance = subject
          allow(instance).to receive(:send_request_to_api).with(subdata_array).and_return(JSON.dump(subdata_array))

          response = instance.send_request_in_batch(data_array, 1)

          expect(response).to eq(data_array)
          expect(response.length).to eq(5)
        end
      end

      describe ".merge_response_with_users" do
        let(:response) { subject.cleaned_users.map { |user| user.merge("spam_probability" => Random.new.rand(100.0)) } }
        let(:merged_user) { subject.merge_response_with_users(response) }

        it "returns an array of users with spam probability" do
          expect(merged_user.first).to be_kind_of(Hash)
          expect(merged_user.first["original_user"]).to be_kind_of(Decidim::User)
        end
      end

      describe ".use_ssl?" do
        let(:url) { URI("http://something.example.org") }

        context "when scheme is https" do
          let(:url) { URI("https://something.example.org") }

          it "returns true" do
            expect(subject.use_ssl?(url)).to eq(true)
          end
        end

        it "returns false" do
          expect(subject.use_ssl?(url)).to eq(false)
        end
      end
    end
  end
end
