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
          let(:subject) { "Resum de detecció de correu brossa" }
          let(:default_subject) { "Spam detection digest" }

          let(:body) { "Aquí teniu l&#39;informe de la tasca de detecció de correu brossa" }
          let(:default_body) { "Here is the report of the spam detection task" }

          include_examples "localised email"
        end

        describe "email body" do
          it "includes reported_user count" do
            expect(email_body(mail)).to include("Reported users count: #{results[:reported_user]}")
          end

          it "includes reported_user link" do
            expect(email_body(mail)).to include("<a href=\"http://#{user.organization.host}/admin/moderated_users?blocked=false\">See the list of all reported accounts on the site</a>")
          end

          it "includes blocked_user count" do
            expect(email_body(mail)).to include("Blocked users count: #{results[:blocked_user]}")
          end

          it "includes blocked_user link" do
            expect(email_body(mail)).to include("<a href=\"http://#{user.organization.host}/admin/moderated_users?blocked=true\">See the list of all blocked accounts on the site</a>")
          end
        end
      end
    end
  end
end
