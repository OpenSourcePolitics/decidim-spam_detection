# frozen_string_literal: true

require "spec_helper"

describe "decidim:spam_detection:block_users", type: :task do
  it "preloads the Rails environment" do
    expect(task.prerequisites).to include "environment"
  end

  it "runs gracefully" do
    expect { task.execute }.not_to raise_error
  end

  it "performs the job" do
    expect(Decidim::SpamDetection::BlockUsersJob).to receive(:perform_later)

    task.execute
  end
end
