# frozen_string_literal: true

require "spec_helper"

module Decidim
  module SpamDetection
    describe SpamDetectionMailer, type: :mailer do
      let(:locale) { "en" }
      let(:user) { create(:user, :admin, locale: locale) }
      let(:results) do
        { reported_user: 2, blocked_user: 1, nothing: 2 }
      end

      describe "notify_detection" do
        let(:mail) { described_class.notify_detection(user, results) }

        describe "localisation" do
          let(:subject) { "Informe de la tasca automàtica detecció de spam" }
          let(:default_subject) { "Automated spam detection task digest" }

          let(:body) { "Aquí teniu l&#39;informe de la tasca de detecció de spam" }
          let(:default_body) { "Here is the report of the automated spam detection task." }

          include_examples "localised email"
        end

        describe "email body" do
          it "includes reported_user count" do
            expect(email_body(mail)).to include("Spam accounts reported: #{results[:reported_user]}")
          end

          it "includes reported_user link" do
            expect(email_body(mail)).to include("<a href=\"http://#{user.organization.host}/admin/moderated_users?blocked=false\">See the list of all reported accounts</a>")
          end

          it "includes blocked_user count" do
            expect(email_body(mail)).to include("Spam accounts blocked: #{results[:blocked_user]}")
          end

          it "includes blocked_user link" do
            expect(email_body(mail)).to include("<a href=\"http://#{user.organization.host}/admin/moderated_users?blocked=true\">See the list of all blocked accounts</a>")
          end
        end
      end
    end
  end
end
