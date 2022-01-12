# frozen_string_literal: true

require "decidim/dev/common_rake"

def precompile(path)
  Dir.chdir(path) do
    system("bundle exec rails assets:precompile")
  end
end

desc "Generates a dummy app for testing"
task test_app: "decidim:generate_external_test_app" do
  ENV["RAILS_ENV"] = "test"
  precompile("spec/decidim_dummy_app")
end

desc "Generates a development app."
task development_app: "decidim:generate_external_development_app"