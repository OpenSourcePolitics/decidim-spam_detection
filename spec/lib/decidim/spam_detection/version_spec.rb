# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SpamDetection
    describe "Version" do
      let(:described_class) { Decidim::SpamDetection }

      describe ".version" do
        it "returns a string version" do
          expect(described_class.version).to be_kind_of(String)
        end
      end

      describe ".decidim_version" do
        it "returns a string version" do
          expect(described_class.decidim_version).to be_kind_of(String)
        end

        it "returns a valid version" do
          expect(described_class.decidim_version).to match(/\d+\.\d+/)
        end
      end
    end
  end
end
