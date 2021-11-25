# frozen_string_literal: true

require "decidim/core/test/factories"

FactoryBot.define do
  factory :spam_detection_component, parent: :component do
    name { Decidim::Components::Namer.new(participatory_space.organization.available_locales, :spam_detection).i18n_name }
    manifest_name { :spam_detection }
    participatory_space { create(:participatory_process, :with_steps) }
  end

  # Add engine factories here
end
