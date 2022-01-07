# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SpamDetection
    describe ApiProxy do
      let(:subject) { subject_class.new(users_data, batch_size) }
      let(:subject_class) { described_class }
      let(:organization) { create(:organization) }
      let!(:users) { create_list(:user, 5, organization: organization) }
      let(:mark_user_service) { Decidim::SpamDetection::MarkUsersService.new }
      let(:users_data) { mark_user_service.cleaned_users }
      let(:returned_users_data) do
        users_data.map do |user_data|
          user_data.merge("spam_proability" => Random.new.rand(100.0))
        end
      end
      let(:url) { "http://localhost:8080/api" }
      let(:batch_size) { 1000 }
      let(:request) do
        stub_request(:post, url).with(
          body: JSON.dump(users_data),
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      describe "#request" do
        before do
          request.to_return(body: JSON.dump(returned_users_data))
        end

        it "initializes the api proxy" do
          expect(Decidim::SpamDetection::ApiProxy.request(users_data, batch_size).class).to be(Array)
        end
      end

      describe "#send_request_to_api" do
        context "when api responds in a short time" do
          before do
            request.to_return(body: JSON.dump(returned_users_data))
          end

          it "sends an api call" do
            expect(subject.send_request_to_api(users_data)).to eq(JSON.dump(returned_users_data))
          end
        end

        context "when api doesn't responds in a short time" do
          before do
            request.to_raise(Net::ReadTimeout)
          end

          it "retries api call then raise" do
            instance = subject

            expect do
              instance.send_request_to_api(users_data)
              expect(instance.instance_variable_get(:@retries)).to eq([])
            end.to raise_error(Net::ReadTimeout)
          end
        end
      end

      describe "#send_request_in_batch" do
        let(:subdata_array) { ["foo" => "bar"] }
        let(:users_data) { subdata_array * 5 }
        let(:batch_size) { 1 }

        it "concatenates the responses" do
          instance = subject
          allow(instance).to receive(:send_request_to_api).with(subdata_array).and_return(JSON.dump(subdata_array))

          expect(instance.send_request_in_batch).to eq(users_data)
          expect(instance.send_request_in_batch.length).to eq(5)
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
