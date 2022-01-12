# frozen_string_literal: true

require "spec_helper"

describe Decidim::SpamDetection::NotifyAdmins do
  subject { described_class }

  let(:organization) { create(:organization) }
  let(:admin) { create(:user, :admin, organization: organization) }
  let(:results) do
    {
      organization.id.to_s => { reported_user: 2, blocked_user: 1, nothing: 2 }
    }
  end

  describe "#perform" do
    let(:mailer) { double :mailer }

    it "sends an email to admins" do
      expect(Decidim::SpamDetection::SpamDetectionMailer)
        .to receive(:notify_detection)
        .with(admin, { reported_user: 2, blocked_user: 1, nothing: 2 })
        .and_return(mailer)

      expect(mailer)
        .to receive(:deliver_now)

      subject.perform_now(results)
    end

    context "when multiple organizations are present" do
      let(:second_organization) { create(:organization) }
      let(:second_admin) { create(:user, :admin, organization: second_organization) }
      let(:results) do
        {
          organization.id.to_s => { reported_user: 2, blocked_user: 1, nothing: 2 },
          second_organization.id.to_s => { reported_user: 3, blocked_user: 4, nothing: 6 }
        }
      end

      it "sends an email to admins" do
        clear_emails
        expect(emails.length).to eq(0)

        subject.perform_now(results)

        expect(emails.length).to eq(results.count)
      end
    end

    context "when results is only filled with nothing key" do
      let(:results) do
        { organization.id.to_s => { nothing: 2 } }
      end

      it "sends an email to admins" do
        expect(Decidim::SpamDetection::SpamDetectionMailer)
          .not_to receive(:notify_detection)
          .with(admin, { reported_user: 2, blocked_user: 1, nothing: 2 })

        subject.perform_now(results)
      end
    end
  end
end
