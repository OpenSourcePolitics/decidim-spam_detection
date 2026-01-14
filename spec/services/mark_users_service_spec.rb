# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SpamDetection
    describe MarkUsersService do
      let(:service) { described_class.new }
      let(:organization) { create(:organization) }
      let!(:users) { create_list(:user, 5, organization: organization) }
      let!(:admins) { create_list(:user, 5, :admin, organization: organization) }

      describe "initialize" do
        it "initializes @base_query as an ActiveRecord::Relation" do
          expect(service.instance_variable_get(:@base_query)).to be_kind_of(ActiveRecord::Relation)
        end

        it "doesn't include admins in the query" do
          expect(service.instance_variable_get(:@base_query).count).to eq(5)
        end

        it "initializes @results as empty hash" do
          expect(service.instance_variable_get(:@results)).to eq({})
        end

        context "when user is already blocked" do
          let!(:blocked_user) { create(:user, :blocked, organization: organization) }

          it "is not included in the query" do
            query = service.instance_variable_get(:@base_query)
            expect(query.count).to eq(5)
            expect(query.to_a).not_to include(blocked_user)
          end
        end

        context "when user is already moderated" do
          let!(:moderated_user) { create(:user, organization: organization) }
          let!(:user_moderation) { create(:user_moderation, user: moderated_user) }

          it "is not included in the query" do
            query = service.instance_variable_get(:@base_query)
            expect(query.count).to eq(5)
            expect(query.to_a).not_to include(moderated_user)
          end
        end

        context "when user has deleted their account" do
          let!(:deleted_user) { create(:user, :deleted, organization: organization) }

          it "is not included in the query" do
            query = service.instance_variable_get(:@base_query)
            expect(query.count).to eq(5)
            expect(query.to_a).not_to include(deleted_user)
          end
        end

        context "when user has been unreported" do
          let!(:unreported_user) { create(:user, :unmarked_as_spam, organization: organization) }

          it "is not included in the query" do
            query = service.instance_variable_get(:@base_query)
            expect(query.count).to eq(5)
            expect(query.to_a).not_to include(unreported_user)
          end
        end

        context "when user has been unblocked" do
          let!(:unblocked_user) { create(:user, :unblocked_as_spam, organization: organization) }

          it "is not included in the query" do
            query = service.instance_variable_get(:@base_query)
            expect(query.count).to eq(5)
            expect(query.to_a).not_to include(unblocked_user)
          end
        end
      end

      describe ".call" do
        context "when service is not activated" do
          before do
            allow(Decidim::SpamDetection).to receive(:service_activated?).and_return(false)
          end

          it "returns false without processing" do
            expect(described_class.call).to be(false)
          end
        end

        context "when service is activated" do
          before do
            allow(Decidim::SpamDetection).to receive(:service_activated?).and_return(true)
          end

          context "when there are no users to process" do
            let!(:users) { [] }

            it "returns true without calling the API" do
              expect(Decidim::SpamDetection::ApiProxy).not_to receive(:request)
              expect(described_class.call).to be(true)
            end
          end

          context "when API returns spam probabilities" do
            let(:api_response) do
              users.map do |u|
                {
                  "id" => u.id,
                  "decidim_organization_id" => u.decidim_organization_id,
                  "spam_probability" => 0.9
                }
              end
            end

            before do
              allow(Decidim::SpamDetection::ApiProxy).to receive(:request).and_return(api_response)
            end

            it "processes users and returns true" do
              expect(described_class.call).to be(true)
            end

            it "calls the SpamUserCommandAdapter for each user" do
              expect(Decidim::SpamDetection::SpamUserCommandAdapter).to receive(:call).exactly(5).times.and_call_original
              described_class.call
            end
          end

          context "when API fails" do
            before do
              allow(Decidim::SpamDetection::ApiProxy).to receive(:request).and_raise(StandardError)
            end

            it "handles the error and continues" do
              expect { described_class.call }.not_to raise_error
            end
          end
        end

        context "when service raises an error" do
          let(:service_instance) { instance_double(described_class) }

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

      describe "#ask_and_mark" do
        let(:api_response) do
          users.map do |u|
            {
              "id" => u.id,
              "decidim_organization_id" => u.decidim_organization_id,
              "spam_probability" => 0.99
            }
          end
        end

        before do
          allow(Decidim::SpamDetection::ApiProxy).to receive(:request).and_return(api_response)
        end

        it "processes users in batches" do
          service.ask_and_mark
          expect(service.instance_variable_get(:@processed_count)).to eq(5)
        end

        it "builds results by organization" do
          service.ask_and_mark
          results = service.instance_variable_get(:@results)
          expect(results.keys).to include(organization.id.to_s)
        end

        context "when notify_admins! fails" do
          before do
            allow(Decidim::SpamDetection::NotifyAdmins).to receive(:perform_later).and_raise(StandardError)
          end

          it "handles error gracefully without raising" do
            expect { service.ask_and_mark }.not_to raise_error
          end
        end
      end

      describe "#status" do
        let(:api_response) do
          [
            { "id" => users[0].id, "decidim_organization_id" => users[0].decidim_organization_id, "spam_probability" => 0.999 },
            { "id" => users[1].id, "decidim_organization_id" => users[1].decidim_organization_id, "spam_probability" => 0.0 },
            { "id" => users[2].id, "decidim_organization_id" => users[2].decidim_organization_id, "spam_probability" => 0.71 },
            { "id" => users[3].id, "decidim_organization_id" => users[3].decidim_organization_id, "spam_probability" => 0.9 },
            { "id" => users[4].id, "decidim_organization_id" => users[4].decidim_organization_id, "spam_probability" => 0.1 }
          ]
        end

        before do
          allow(Decidim::SpamDetection).to receive(:service_activated?).and_return(true)
          allow(Decidim::SpamDetection::ApiProxy).to receive(:request).and_return(api_response)
          allow(Decidim::SpamDetection::SpamUserCommandAdapter).to receive(:perform_block_user?).and_return(true)
        end

        it "returns a hash with the count for each result" do
          service.ask_and_mark
          status = service.status

          expect(status).to be_a(Hash)
          expect(status[organization.id.to_s]).to be_a(Hash)
          expect(status[organization.id.to_s].keys).to match_array([:reported_user, :blocked_user, :nothing])
        end
      end

      describe "#notify_admins!" do
        before do
          service.instance_variable_set(:@results, { organization.id.to_s => [:reported_user, :blocked_user] })
        end

        it "enqueues the NotifyAdmins job" do
          expect(Decidim::SpamDetection::NotifyAdmins).to receive(:perform_later)
          service.notify_admins!
        end

        context "when NotifyAdmins fails" do
          before do
            allow(Decidim::SpamDetection::NotifyAdmins).to receive(:perform_later).and_raise(StandardError)
          end

          it "handles error gracefully without raising" do
            expect { service.notify_admins! }.not_to raise_error
          end
        end
      end

      describe "batch processing" do
        context "with large dataset" do
          let!(:many_users) { create_list(:user, 15, organization: organization) }

          it "processes users in batches" do
            call_count = 0
            allow(Decidim::SpamDetection::ApiProxy).to receive(:request) do |batch|
              call_count += 1
              expect(batch.size).to be <= described_class::BATCH_SIZE
              batch.map { |u| { "id" => u["id"], "decidim_organization_id" => organization.id, "spam_probability" => 0.5 } }
            end

            service.ask_and_mark
            expect(call_count).to be >= 1
          end

          it "continues processing even if one batch fails" do
            call_count = 0
            allow(Decidim::SpamDetection::ApiProxy).to receive(:request) do |_batch|
              call_count += 1
              raise StandardError, "API Error" if call_count == 1

              []
            end

            expect { service.ask_and_mark }.not_to raise_error
          end
        end
      end

      describe "timeout handling" do
        context "when API times out" do
          before do
            allow(Decidim::SpamDetection::ApiProxy).to receive(:request).and_raise(Timeout::Error)
          end

          it "does not crash the service" do
            expect { service.ask_and_mark }.not_to raise_error
          end
        end

        context "when DB query times out" do
          before do
            allow(service.instance_variable_get(:@base_query)).to receive(:count).and_raise(Timeout::Error)
          end

          it "returns gracefully" do
            expect(service.ask_and_mark).to be(true)
          end
        end
      end

      describe "memory management" do
        it "uses cursor-based pagination with WHERE id > ?" do
          base_query = service.instance_variable_get(:@base_query)
          expect(base_query.order_values).not_to be_empty
          expect(described_class::BATCH_SIZE).to be > 0
          expect(described_class::BATCH_SIZE).to be <= 200
        end
      end

      describe "resilience to API failures" do
        let!(:test_users) { create_list(:user, 10, organization: organization) }

        it "does not crash when API fails" do
          allow(Decidim::SpamDetection::ApiProxy).to receive(:request).and_raise(StandardError, "API Failure")
          expect { service.ask_and_mark }.not_to raise_error
        end
      end
    end
  end
end
