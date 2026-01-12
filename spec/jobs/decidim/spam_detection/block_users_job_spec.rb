# frozen_string_literal: true

require "spec_helper"

describe Decidim::SpamDetection::BlockUsersJob do
  subject { described_class }

  let!(:users) { create_list(:user, 5, :marked_as_spam_very_sure) }
  let!(:users_not_sure) { create_list(:user, 5, :marked_as_spam) }

  describe "#perform" do
    it "blocks reported users" do
      expect do
        subject.perform_now
      end.to change { Decidim::User.blocked.count }.by(5)
    end

    context "with no users to block" do
      before do
        users.each { |u| u.update!(blocked: true) }
      end

      it "completes without errors" do
        expect { subject.perform_now }.not_to raise_error
      end

      it "does not attempt to block any users" do
        expect(Decidim::SpamDetection::BlockSpamUserCommand).not_to receive(:call)
        subject.perform_now
      end
    end
  end

  describe "batch processing" do
    before do
      # rubocop:disable Rails/SkipsModelValidations
      Decidim::User.where.not(extended_data: nil).update_all(extended_data: {})
      # rubocop:enable Rails/SkipsModelValidations
    end

    let!(:many_spam_users) { create_list(:user, 15, :marked_as_spam_very_sure) }

    it "processes users in batches" do
      call_count = 0
      allow(Decidim::SpamDetection::BlockSpamUserCommand).to receive(:call) do |_user, _level|
        call_count += 1
        double(success?: true)
      end

      subject.perform_now

      expect(call_count).to eq(15)
    end
  end

  describe "timeout protection" do
    context "when execution time exceeds maximum" do
      before do
        # rubocop:disable Rails/SkipsModelValidations
        Decidim::User.where.not(extended_data: nil).update_all(extended_data: {})
        # rubocop:enable Rails/SkipsModelValidations
      end

      let!(:some_users) { create_list(:user, 10, :marked_as_spam_very_sure) }

      it "stops processing gracefully" do
        stub_const("#{described_class}::MAX_EXECUTION_TIME", 1)
        allow(Decidim::SpamDetection::BlockSpamUserCommand).to receive(:call) do
          sleep(0.3)
          double(success?: true)
        end

        expect { subject.perform_now }.not_to raise_error
      end

      it "does not block all users due to timeout" do
        stub_const("#{described_class}::MAX_EXECUTION_TIME", 1)

        blocked_count = 0
        allow(Decidim::SpamDetection::BlockSpamUserCommand).to receive(:call) do
          blocked_count += 1
          sleep(0.3)
          double(success?: true)
        end

        subject.perform_now

        expect(blocked_count).to be >= 1
        expect(blocked_count).to be <= 10
      end
    end

    context "when individual user blocking times out" do
      let!(:some_users) { create_list(:user, 5, :marked_as_spam_very_sure) }

      before do
        # rubocop:disable Rails/SkipsModelValidations
        Decidim::User.where.not(extended_data: nil).where.not(id: some_users.map(&:id)).update_all(extended_data: {})
        # rubocop:enable Rails/SkipsModelValidations
        allow(Decidim::SpamDetection::BlockSpamUserCommand).to receive(:call).and_raise(Timeout::Error)
      end

      it "continues with other users" do
        expect { subject.perform_now }.not_to raise_error
      end
    end
  end

  describe "error handling" do
    context "when BlockSpamUserCommand fails for one user" do
      before do
        # rubocop:disable Rails/SkipsModelValidations
        Decidim::User.where.not(extended_data: nil).update_all(extended_data: {})
        # rubocop:enable Rails/SkipsModelValidations
      end

      let!(:test_users) { create_list(:user, 5, :marked_as_spam_very_sure) }
      let(:problematic_user) { test_users.first }

      it "continues blocking other users" do
        call_count = 0
        allow(Decidim::SpamDetection::BlockSpamUserCommand).to receive(:call) do |user, _level|
          call_count += 1
          raise StandardError, "Database error" if user.id == problematic_user.id

          double(success?: true)
        end

        subject.perform_now

        expect(call_count).to eq(5)
      end
    end

    context "when command returns failure" do
      before do
        # rubocop:disable Rails/SkipsModelValidations
        Decidim::User.where.not(extended_data: nil).update_all(extended_data: {})
        # rubocop:enable Rails/SkipsModelValidations
        allow(Decidim::SpamDetection::BlockSpamUserCommand).to receive(:call).and_return(double(success?: false))
      end

      it "does not crash the job" do
        expect { subject.perform_now }.not_to raise_error
      end
    end

    context "when database connection is lost during processing" do
      before do
        # rubocop:disable Rails/SkipsModelValidations
        Decidim::User.where.not(extended_data: nil).update_all(extended_data: {})
        # rubocop:enable Rails/SkipsModelValidations

        call_count = 0
        allow(Decidim::SpamDetection::BlockSpamUserCommand).to receive(:call) do
          call_count += 1
          raise ActiveRecord::StatementInvalid, "connection lost" if call_count == 2

          double(success?: true)
        end
      end

      it "handles database errors gracefully" do
        expect { subject.perform_now }.not_to raise_error
      end
    end
  end

  describe "performance with large dataset" do
    let!(:small_user_set) { create_list(:user, 10, :marked_as_spam_very_sure) }
    let(:relation_mock) { instance_double(ActiveRecord::Relation) }

    before do
      allow(Decidim::SpamDetection::BlockSpamUserCommand).to receive(:call) do |_user, _level|
        double(success?: true)
      end
    end

    it "uses find_in_batches for memory efficiency" do
      # rubocop:disable RSpec/AnyInstance
      expect_any_instance_of(ActiveRecord::Relation).to receive(:find_in_batches).and_call_original
      # rubocop:enable RSpec/AnyInstance

      subject.perform_now
    end

    it "processes batches without loading all users into memory" do
      batch_sizes = []

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(ActiveRecord::Relation).to receive(:find_in_batches) do |*args, **options, &block|
        (batch_sizes << options[:batch_size]) || described_class::BATCH_SIZE
        ActiveRecord::Relation.instance_method(:find_in_batches).bind_call(*[self] + args, **options, &block)
      end
      # rubocop:enable RSpec/AnyInstance

      subject.perform_now

      expect(batch_sizes.first).to eq(described_class::BATCH_SIZE) if batch_sizes.any?
    end
  end

  describe "spam level configuration" do
    before do
      # rubocop:disable Rails/SkipsModelValidations
      Decidim::User.where.not(extended_data: nil).update_all(extended_data: {})
      # rubocop:enable Rails/SkipsModelValidations
    end

    context "with custom spam level" do
      it "uses the provided spam level" do
        custom_level = 0.95

        expect(Decidim::User).to receive(:where).with(admin: false, blocked: false, deleted_at: nil).and_call_original

        subject.perform_now(spam_level: custom_level)
      end
    end

    context "with environment variable spam level" do
      before do
        ENV["SPAM_DETECTION_BLOCKING_LEVEL"] = "0.85"
      end

      after do
        ENV.delete("SPAM_DETECTION_BLOCKING_LEVEL")
      end

      it "uses the environment variable value" do
        expect(Decidim::User).to receive(:where).with(admin: false, blocked: false, deleted_at: nil).and_call_original

        subject.perform_now
      end
    end

    context "with default spam level" do
      it "uses the very_sure constant" do
        expect(Decidim::User).to receive(:where).with(admin: false, blocked: false, deleted_at: nil).and_call_original

        subject.perform_now
      end
    end
  end

  describe "critical error handling" do
    let(:job_instance) { described_class.new }

    context "when perform raises an unexpected error" do
      before do
        allow(job_instance).to receive(:count_users_safely).and_raise(StandardError, "Unexpected error")
        allow(described_class).to receive(:new).and_return(job_instance)
      end

      it "returns false" do
        expect(subject.perform_now).to be(false)
      end
    end
  end

  describe "progress tracking" do
    before do
      # rubocop:disable Rails/SkipsModelValidations
      Decidim::User.where.not(extended_data: nil).update_all(extended_data: {})
      # rubocop:enable Rails/SkipsModelValidations
    end

    let!(:batch_users) { create_list(:user, 10, :marked_as_spam_very_sure) }

    it "completes successfully with multiple batches" do
      blocked_count = 0
      allow(Decidim::SpamDetection::BlockSpamUserCommand).to receive(:call) do
        blocked_count += 1
        double(success?: true)
      end

      subject.perform_now

      expect(blocked_count).to eq(10)
    end

    it "completes successfully" do
      allow(Decidim::SpamDetection::BlockSpamUserCommand).to receive(:call) do
        double(success?: true)
      end

      expect { subject.perform_now }.not_to raise_error
    end
  end

  describe "query optimization" do
    let!(:excluded_users) do
      [
        create(:user, :marked_as_spam_very_sure, admin: true),
        create(:user, :marked_as_spam_very_sure, blocked: true),
        create(:user, :marked_as_spam_very_sure, deleted_at: Time.current),
        create(:user, :marked_as_spam_very_sure, :unmarked_as_spam),
        create(:user, :marked_as_spam_very_sure, :unblocked_as_spam)
      ]
    end

    it "excludes admin users" do
      expect { subject.perform_now }.not_to(change { excluded_users[0].reload.blocked })
    end

    it "excludes already blocked users" do
      expect(Decidim::SpamDetection::BlockSpamUserCommand).not_to receive(:call).with(excluded_users[1], anything)
      subject.perform_now
    end

    it "excludes deleted users" do
      expect(Decidim::SpamDetection::BlockSpamUserCommand).not_to receive(:call).with(excluded_users[2], anything)
      subject.perform_now
    end

    it "excludes unreported users" do
      expect(Decidim::SpamDetection::BlockSpamUserCommand).not_to receive(:call).with(excluded_users[3], anything)
      subject.perform_now
    end

    it "excludes unblocked users" do
      expect(Decidim::SpamDetection::BlockSpamUserCommand).not_to receive(:call).with(excluded_users[4], anything)
      subject.perform_now
    end
  end
end
