# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SpamDetection
    describe ApiProxy do
      let(:subject) { described_class }
      let(:organization) { create(:organization) }
      let!(:users) { create_list(:user, 5, organization: organization) }
      let(:mark_user_service) { Decidim::SpamDetection::MarkUsersService.new }

      describe ".send_request_to_api" do
        let(:users_data) { mark_user_service.cleaned_users }
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

      describe ".send_request_in_batch" do
        let(:subdata_array) { ["foo" => "bar"] }
        let(:data_array) { subdata_array * 5 }

        before do
          allow(subject).to receive(:send_request_to_api).with(subdata_array).and_return(JSON.dump(subdata_array))
        end

        it "concatenates the responses" do
          response = subject.send(:send_request_in_batch, data_array, 1)

          expect(response).to eq(data_array)
          expect(response.length).to eq(5)
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
