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

        context "when users has been unreported" do
          let!(:unreported_user) { create(:user, :unmarked_as_spam, organization: organization) }

          it "is not included in the query" do
            expect(users_instance_variable.length).to eq(5)
            expect(users_instance_variable).not_to include(unreported_user)
          end
        end

        context "when users has been unblocked" do
          let!(:unblocked_user) { create(:user, :unblocked_as_spam, organization: organization) }

          it "is not included in the query" do
            expect(users_instance_variable.length).to eq(5)
            expect(users_instance_variable).not_to include(unblocked_user)
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
        let(:users_array) { [user_hash.merge("spam_probability" => 0.99)] }

        it "calls the facotry" do
          expect(Decidim::SpamDetection::SpamUserCommandAdapter).to receive(:for).with(users_array.first)

          subject.mark_spam_users(users_array)
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
    end
  end
end
