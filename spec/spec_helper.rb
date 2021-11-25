# frozen_string_literal: true

require "simplecov"
require "codecov"

SimpleCov.start "rails"
SimpleCov.formatter = SimpleCov::Formatter::Codecov if ENV["CODECOV"]

require "decidim/dev"

ENV["ENGINE_ROOT"] = File.dirname(__dir__)

Decidim::Dev.dummy_app_path = File.expand_path(File.join("spec", "decidim_dummy_app"))

require "decidim/dev/test/base_spec_helper"
