# frozen_string_literal: true

require "spec_helper"

describe "decidim:spam_detection:mark_users", type: :task do
  it "preloads the Rails environment" do
    expect(task.prerequisites).to include "environment"
  end

  it "runs gracefully" do
    expect { task.execute }.not_to raise_error
  end

  it "performs the job" do
    expect(Decidim::SpamDetection::MarkUsersJob).to receive(:perform_now)

    task.execute
  end
end
