# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SpamDetection
    describe MarkUsersService do
      let(:subject) { described_class.new }
      let(:organization) { create(:organization) }
      let!(:users) { create_list(:user, 5, organization: organization) }
      let(:users_instance_variable) { subject.instance_variable_get(:@users) }
      let(:results_instance_variable) { subject.instance_variable_get(:@results) }
      let!(:admins) { create_list(:user, 5, :admin, organization: organization) }
      let(:cleaned_users) do
        subject.merge_response_with_users(
          subject.cleaned_users
        )
      end
      let(:user_hash) do
        cleaned_users.first
      end

      describe "initialize" do
        describe "@users" do
          it "returns an active record relation" do
            expect(subject.instance_variable_get(:@base_query)).to be_kind_of(ActiveRecord::Relation)
          end

          it "doesn't includes admin in the query" do
            expect(subject.instance_variable_get(:@base_query).to_a.length).to eq(5)
          end

          context "when user is already blocked" do
            let!(:already_blocked_user) { create(:user, :blocked, organization: organization) }

            it "is not included in the query" do
              query = subject.instance_variable_get(:@base_query).to_a
              expect(query.length).to eq(5)
              expect(query).not_to include(already_blocked_user)
            end
          end

          context "when user is already moderated" do
            let!(:already_moderated_user) { create(:user, organization: organization) }
            let!(:user_moderation) { create(:user_moderation, user: already_moderated_user) }

            it "is not included in the query" do
              query = subject.instance_variable_get(:@base_query).to_a
              expect(query.length).to eq(5)
              expect(query).not_to include(already_moderated_user)
            end
          end

          context "when user has deleted his account" do
            let!(:already_deleted_user) { create(:user, :deleted, organization: organization) }

            it "is not included in the query" do
              query = subject.instance_variable_get(:@base_query).to_a
              expect(query.length).to eq(5)
              expect(query).not_to include(already_deleted_user)
            end
          end

          context "when users has been unreported" do
            let!(:unreported_user) { create(:user, :unmarked_as_spam, organization: organization) }

            it "is not included in the query" do
              query = subject.instance_variable_get(:@base_query).to_a
              expect(query.length).to eq(5)
              expect(query).not_to include(unreported_user)
            end
          end

          context "when users has been unblocked" do
            let!(:unblocked_user) { create(:user, :unblocked_as_spam, organization: organization) }

            it "is not included in the query" do
              query = subject.instance_variable_get(:@base_query).to_a
              expect(query.length).to eq(5)
              expect(query).not_to include(unblocked_user)
            end
          end
        end

        describe "@result" do
          it "initializes as empty hash" do
            expect(results_instance_variable).to eq({})
          end
        end
      end

      describe "#cleaned_users" do
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

        it "calls the adapter" do
          expect(Decidim::SpamDetection::SpamUserCommandAdapter).to receive(:call)
            .with(users_array.first)
            .and_call_original

          subject.mark_spam_users(users_array)
        end

        it "adds the output to results" do
          subject.mark_spam_users(users_array)

          expect(results_instance_variable).to eq({ user_hash["decidim_organization_id"].to_s => [:reported_user] })
        end

        context "when command times out" do
          before do
            allow(Decidim::SpamDetection::SpamUserCommandAdapter).to receive(:call).and_raise(Timeout::Error)
          end

          it "handles timeout gracefully and increments error count" do
            expect { subject.mark_spam_users(users_array) }.not_to raise_error
            expect(subject.instance_variable_get(:@error_count)).to eq(1)
          end
        end

        context "when command raises an error" do
          before do
            allow(Decidim::SpamDetection::SpamUserCommandAdapter).to receive(:call).and_raise(StandardError.new("API Error"))
          end

          it "handles error gracefully and increments error count" do
            expect { subject.mark_spam_users(users_array) }.not_to raise_error
            expect(subject.instance_variable_get(:@error_count)).to eq(1)
          end
        end
      end

      describe "#merge_response_with_users" do
        let(:response) { subject.cleaned_users.map { |user| user.merge("spam_probability" => Random.new.rand(100.0)) } }
        let(:merged_user) { subject.merge_response_with_users(response) }

        it "returns an array of users with spam probability" do
          expect(merged_user.first).to be_kind_of(Hash)
          expect(merged_user.first["original_user"]).to be_kind_of(Decidim::User)
        end

        it "filters out users not found in the batch" do
          response_with_unknown = response + [{ "id" => 999_999, "spam_probability" => 0.9 }]
          merged = subject.merge_response_with_users(response_with_unknown)

          expect(merged.length).to eq(response.length)
          expect(merged.map { |u| u["id"] }).not_to include(999_999)
        end
      end

      describe "#status" do
        let(:probabilities) { [0.999, 0.0, 0.71, 0.9, 0.1] }
        let(:users_array) do
          cleaned_users.map.with_index do |user, index|
            user.merge("spam_probability" => probabilities[index])
          end
        end

        before do
          allow(Decidim::SpamDetection::SpamUserCommandAdapter).to receive(:perform_block_user?).and_return(true)
        end

        it "returns a hash with the count for each return" do
          subject.mark_spam_users(users_array)

          expect(subject.status).to eq({ user_hash["decidim_organization_id"].to_s => { reported_user: 2, blocked_user: 1, nothing: 2 } })
        end
      end

      describe "notify_admins" do
        let(:results) do
          { organization.id.to_s => [:reported_user, :reported_user, :blocked_user, :nothing, :nothing] }
        end

        before do
          subject.instance_variable_set(:@results, results)
        end

        it "enqueues the notify admins job" do
          subject.notify_admins!

          expect(Decidim::SpamDetection::NotifyAdmins).to have_been_enqueued
        end

        context "when notify fails" do
          before do
            allow(Decidim::SpamDetection::NotifyAdmins).to receive(:perform_later).and_raise(StandardError)
          end

          it "handles error gracefully without raising" do
            expect { subject.notify_admins! }.not_to raise_error
          end
        end
      end

      describe "batch processing" do
        context "with large dataset" do
          let!(:many_users) { create_list(:user, 15, organization: organization) }

          before do
            allow(subject.instance_variable_get(:@base_query)).to receive(:count).and_return(250)
          end

          it "processes users in batches" do
            allow(Decidim::SpamDetection::ApiProxy).to receive(:request).and_return([])

            expect(Decidim::SpamDetection::ApiProxy).to receive(:request) do |batch|
              expect(batch.size).to be <= described_class::BATCH_SIZE
              []
            end.at_least(:once)

            subject.ask_and_mark
          end

          it "continues processing even if one batch fails" do
            call_count = 0
            allow(Decidim::SpamDetection::ApiProxy).to receive(:request) do |batch|
              call_count += 1
              raise StandardError, "API Error" if call_count == 2

              batch.map { |u| u.merge("spam_probability" => 0.5) }
            end

            expect { subject.ask_and_mark }.not_to raise_error
            expect(call_count).to be >= 1
          end
        end
      end

      describe "timeout handling" do
        context "when API times out" do
          before do
            allow(Decidim::SpamDetection::ApiProxy).to receive(:request).and_raise(Timeout::Error)
          end

          it "does not crash the service" do
            expect { subject.ask_and_mark }.not_to raise_error
          end
        end

        context "when DB query times out" do
          before do
            allow(subject.instance_variable_get(:@base_query)).to receive(:count).and_raise(Timeout::Error)
          end

          it "returns gracefully" do
            expect(subject.ask_and_mark).to be(true)
          end
        end
      end

      describe "memory management" do
        it "uses batch processing with offset and limit" do
          base_query = subject.instance_variable_get(:@base_query)
          expect(base_query.order_values).not_to be_empty

          expect(Decidim::SpamDetection::MarkUsersService::BATCH_SIZE).to be > 0
          expect(Decidim::SpamDetection::MarkUsersService::BATCH_SIZE).to be <= 200
        end
      end

      describe ".call class method" do
        context "when service is not activated" do
          before do
            allow(Decidim::SpamDetection).to receive(:service_activated?).and_return(false)
          end

          it "returns false without processing" do
            expect(described_class.call).to be(false)
          end

          it "does not call ask_and_mark" do
            service_instance = instance_double(described_class)
            allow(described_class).to receive(:new).and_return(service_instance)

            expect(service_instance).not_to receive(:ask_and_mark)
            described_class.call
          end
        end

        context "when service raises an error" do
          let(:service_instance) { described_class.new }

          before do
            allow(Decidim::SpamDetection).to receive(:service_activated?).and_return(true)
            allow(described_class).to receive(:new).and_return(service_instance)
            allow(service_instance).to receive(:ask_and_mark).and_raise(StandardError)
          end

          it "catches the error and returns false" do
            expect(described_class.call).to be(false)
          end
        end
      end

      describe "resilience to API failures" do
        let!(:test_users) { create_list(:user, 10, organization: organization) }

        it "does not crash when API fails" do
          allow(Decidim::SpamDetection::ApiProxy).to receive(:request).and_raise(StandardError, "API Failure")

          expect { subject.ask_and_mark }.not_to raise_error
        end
      end
    end
  end
end
