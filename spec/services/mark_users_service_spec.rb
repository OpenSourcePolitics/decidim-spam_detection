# frozen_string_literal: true

require 'spec_helper'

module Decidim
  module SpamDetection
    describe MarkUsersService do
      let(:subject) { described_class.new }
      let(:organization) { create(:organization) }
      let!(:users) { create_list(:user, 5, organization: organization) }
      let!(:admins) { create_list(:user, 5, :admin, organization: organization) }
      let(:user_hash) do
        subject.instance_variable_get(:@users)
               .first
      end

      describe 'initialize' do
        let(:users_instance_variable) { subject.instance_variable_get(:@users) }
        let(:publicy_searchable_columns) do
          %i[
            id
            decidim_organization_id
            sign_in_count
            personal_url
            about
            avatar
            extended_data
            followers_count
            following_count
            invitations_count
            failed_attempts
            admin
          ].freeze
        end

        it 'returns an array' do
          expect(users_instance_variable).to be_kind_of(Array)
        end

        it "doesn't includes admin in the array" do
          expect(users_instance_variable.length).to eq(5)
        end

        it 'returns an array of hash' do
          expect(users_instance_variable.map(&:class)).to eq([Hash] * 5)
        end

        it 'returns a hash of publicy_searchable_columns' do
          expect(users_instance_variable.first.keys.map(&:to_sym)).to match_array(publicy_searchable_columns)
        end

        it "doesn't include email or password" do
          expect(users_instance_variable.select { |user_hash| user_hash['email'] }).to eq([])
          expect(users_instance_variable.select { |user_hash| user_hash['password'] }).to eq([])
          expect(users_instance_variable.select { |user_hash| user_hash['password_confirmation'] }).to eq([])
        end
      end

      describe '#moderation_user' do
        it 'returns the first admin' do
          expect(subject.moderation_user_for(users.first)).to eq(admins.first)
        end
      end

      describe '#report_user' do
        it 'reports the user' do
          expect { subject.report_user(user_hash) }.to change(Decidim::UserReport, :count)
        end
      end

      describe '#block_user' do
        it 'reports the user' do
          expect { subject.block_user(user_hash) }.to change(Decidim::UserBlock, :count)
        end
      end

      describe "#mark_spam_users" do
        let(:users_array) { [user_hash.merge("spam_probability" => spam_probabilty)] }

        context "when spam_probility is below probable" do
          let(:spam_probabilty) { 0.1 }

          it "does nothing" do
            instance = subject

            expect(instance).not_to receive(:block_user).with(users_array.first)
            expect(instance).not_to receive(:report_user).with(users_array.first)

            instance.mark_spam_users(users_array)
          end
        end

        context "when spam_probility is between very_sure and probable" do
          let(:spam_probabilty) { 0.8 }

          it "calls block_user method" do
            instance = subject

            expect(instance).not_to receive(:block_user).with(users_array.first)
            expect(instance).to receive(:report_user).with(users_array.first).once

            instance.mark_spam_users(users_array)
          end
        end

        context "when spam_probility is above very_sure" do
          let(:spam_probabilty) { 0.999 }

          it "calls block_user method" do
            instance = subject

            expect(instance).to receive(:block_user).with(users_array.first).once
            expect(instance).not_to receive(:report_user).with(users_array.first)

            instance.mark_spam_users(users_array)
          end
        end
      end

      describe "#send_request_to_api" do
        let(:users_data) { subject.instance_variable_get(:@users) }
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
              "Content-Type" => 'application/json'
            }
          ).to_return(body: JSON.dump(returned_users_data))
        end

        it "sends an api call" do
          expect(subject.send_request_to_api(users_data)).to eq(JSON.dump(returned_users_data))
        end
      end
    end
  end
end
