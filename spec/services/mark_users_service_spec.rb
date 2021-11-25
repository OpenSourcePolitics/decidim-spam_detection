# frozen_string_literal: true

require 'spec_helper'

module Decidim
  module SpamDetection
    describe MarkUsersService do
      let(:subject) { described_class.new }
      let(:organization) { create(:organization) }
      let!(:users) { create_list(:user, 5, organization: organization) }
      let!(:admins) { create_list(:user, 5, :admin, organization: organization) }

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
        let(:user_hash) do
          subject.instance_variable_get(:@users)
                 .first
        end

        it 'reports the user' do
          expect { subject.report_user(user_hash) }.to change { Decidim::UserReport.count }
        end
      end
    end
  end
end
