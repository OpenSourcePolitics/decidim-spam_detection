# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SpamDetection
    describe "Configuration" do
      let(:subject) { Decidim::SpamDetection }

      describe "spam_detection_api_url" do
        it "returns the default value" do
          expect(subject.spam_detection_api_url).to eq("http://localhost:8080/api")
        end
      end

      describe "spam_detection_api_auth_token" do
        it "returns the default value" do
          expect(subject.spam_detection_api_auth_token).to eq("dummy")
        end
      end

      describe "spam_detection_api_perform_block_user" do
        it "returns the default value" do
          expect(subject.spam_detection_api_perform_block_user).to eq(false)
        end
      end

      describe "spam_detection_api_force_activate_service" do
        it "returns the default value" do
          expect(subject.spam_detection_api_force_activate_service).to eq(false)
        end
      end

      describe "spam_detection_api_activate_service" do
        it "returns the default value" do
          expect(subject.spam_detection_api_activate_service.call).to eq(true)
        end

        context "when force is set to true" do
          before do
            allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
            allow(subject).to receive(:spam_detection_api_force_activate_service).and_return(true)
          end

          it "returns true" do
            expect(subject.spam_detection_api_activate_service.call).to eq(true)
          end
        end

        context "when url is not the default one" do
          before do
            allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
            allow(subject).to receive(:spam_detection_api_url).and_return("http://other.org:8080/api")
          end

          it "returns true" do
            expect(subject.spam_detection_api_activate_service.call).to eq(true)
          end
        end
      end

      describe ".service_activated?" do
        it "returns true if the spam service is activated" do
          expect(subject.service_activated?).to eq(true)
        end
      end
    end
  end
end
