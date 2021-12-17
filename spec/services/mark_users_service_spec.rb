# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SpamDetection
    describe MarkUsersService do
      let(:subject) { subject_class.new }
      let(:subject_class) { described_class }
      let(:organization) { create(:organization) }
      let!(:users) { create_list(:user, 5, organization: organization) }
      let(:users_instance_variable) { subject.instance_variable_get(:@users) }
      let!(:admins) { create_list(:user, 5, :admin, organization: organization) }
      let(:user_hash) do
        subject_class.merge_response_with_users(
          subject_class.cleaned_users(users_instance_variable), users_instance_variable
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
          expect(subject_class.cleaned_users(users_instance_variable).map(&:class)).to eq([Hash] * 5)
        end

        it "returns a hash of publicy_searchable_columns" do
          expect(subject_class.cleaned_users(users_instance_variable).first.keys.map(&:to_sym)).to match_array(publicy_searchable_columns)
        end

        it "doesn't include email or password" do
          expect(subject_class.cleaned_users(users_instance_variable).select { |user_hash| user_hash["email"] }).to eq([])
          expect(subject_class.cleaned_users(users_instance_variable).select { |user_hash| user_hash["password"] }).to eq([])
          expect(subject_class.cleaned_users(users_instance_variable).select { |user_hash| user_hash["password_confirmation"] }).to eq([])
        end
      end

      describe ".report_user" do
        it "reports the user" do
          expect { subject_class.report_user(user_hash) }.to change(Decidim::UserReport, :count)
        end

        describe "spam detection metadata" do
          let(:spam_probabilty) { 0.88 }

          before do
            subject_class.report_user(user_hash.merge("spam_probability" => spam_probabilty))
          end

          it "add spam detection metadata" do
            expect(user_hash["original_user"].reload.extended_data.dig("spam_detection", "reported_at")).not_to eq(nil)
            expect(user_hash["original_user"].reload.extended_data.dig("spam_detection", "spam_probability")).to eq(0.88)
          end
        end

        context "when users have already been reported in the past" do
          let!(:users) { create_list(:user, 5, :unmarked_as_spam, organization: organization) }

          it "doesn't reports the user" do
            expect { subject_class.report_user(user_hash) }.not_to change(Decidim::UserBlock, :count)
          end
        end
      end

      describe ".block_user" do
        it "blocks the user" do
          expect { subject_class.block_user(user_hash) }.to change(Decidim::UserBlock, :count)
        end

        it "create a moderation entry" do
          expect { subject_class.block_user(user_hash) }.to change(Decidim::UserModeration, :count)
        end

        describe "spam detection metadata" do
          let(:spam_probabilty) { 0.999 }

          before do
            subject_class.block_user(user_hash.merge("spam_probability" => spam_probabilty))
          end

          it "add spam detection metadata" do
            expect(user_hash["original_user"].reload.extended_data.dig("spam_detection", "blocked_at")).not_to eq(nil)
            expect(user_hash["original_user"].reload.extended_data.dig("spam_detection", "spam_probability")).to eq(0.999)
          end
        end

        context "when users have already been blocked in the past" do
          let!(:users) { create_list(:user, 5, :unblocked_as_spam, organization: organization) }

          it "doesn't reports the user" do
            expect { subject_class.block_user(user_hash) }.not_to change(Decidim::UserBlock, :count)
          end
        end
      end

      describe "#mark_spam_users" do
        let(:users_array) { [user_hash.merge("spam_probability" => spam_probabilty)] }

        context "when spam_probility is below probable" do
          let(:spam_probabilty) { 0.1 }

          it "does nothing" do
            instance = subject

            expect(instance.class).not_to receive(:block_user).with(users_array.first)
            expect(instance.class).not_to receive(:report_user).with(users_array.first)

            instance.mark_spam_users(users_array)
          end
        end

        context "when spam_probility is between very_sure and probable" do
          let(:spam_probabilty) { 0.8 }

          context "when perform_block_user is set to true" do
            before do
              allow(subject).to receive(:perform_block_user?).and_return(true)
            end

            it "calls report_user method" do
              instance = subject

              expect(instance.class).not_to receive(:block_user).with(users_array.first)
              expect(instance.class).to receive(:report_user).with(users_array.first).once

              instance.mark_spam_users(users_array)
            end
          end
        end

        context "when spam_probility is above very_sure" do
          let(:spam_probabilty) { 0.999 }

          context "when perform_block_user is set to true" do
            before do
              allow(subject).to receive(:perform_block_user?).and_return(true)
            end

            it "calls block_user method" do
              instance = subject

              expect(instance.class).to receive(:block_user).with(users_array.first).once
              expect(instance.class).not_to receive(:report_user).with(users_array.first)

              instance.mark_spam_users(users_array)
            end
          end

          it "calls report_user method" do
            instance = subject

            expect(instance.class).not_to receive(:block_user).with(users_array.first)
            expect(instance.class).to receive(:report_user).with(users_array.first).once

            instance.mark_spam_users(users_array)
          end
        end
      end

      describe "#send_request_to_api" do
        let(:users_data) { subject_class.cleaned_users(users_instance_variable) }
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
        let(:response) { subject_class.cleaned_users(users_instance_variable).map { |user| user.merge("spam_probability" => Random.new.rand(100.0)) } }
        let(:merged_user) { subject_class.merge_response_with_users(response, users_instance_variable) }

        it "returns an array of users with spam probability" do
          expect(merged_user.first).to be_kind_of(Hash)
          expect(merged_user.first["original_user"]).to be_kind_of(Decidim::User)
        end
      end

      describe ".moderation_user_for" do
        it "creates the admin" do
          expect { subject_class.moderation_user_for(users.first) }.to change(Decidim::User, :count)
        end

        context "when moderation admin exists" do
          let!(:moderation_admin) do
            create(:user,
                   :admin,
                   organization: organization,
                   name: "spam detection bot",
                   nickname: "Spam_detection_bot",
                   email: "spam_detection_bot@opensourcepolitcs.eu")
          end

          it "reuses the admin" do
            expect { subject_class.moderation_user_for(users.first) }.not_to change(Decidim::User, :count)
          end
        end
      end

      describe ".use_ssl?" do
        let(:url) { URI("http://something.example.org") }

        context "when scheme is https" do
          let(:url) { URI("https://something.example.org") }

          it "returns true" do
            expect(subject_class.use_ssl?(url)).to eq(true)
          end
        end

        it "returns false" do
          expect(subject_class.use_ssl?(url)).to eq(false)
        end
      end
    end
  end
end
