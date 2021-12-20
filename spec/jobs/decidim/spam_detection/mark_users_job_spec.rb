# frozen_string_literal: true

require "spec_helper"

describe Decidim::SpamDetection::MarkUsersJob do
  subject { described_class }

  it "calls the mark users service" do
    expect(Decidim::SpamDetection::MarkUsersService).to receive(:run)

    subject.perform_now
  end
end
