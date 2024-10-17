# frozen_string_literal: true

require "decidim/dev/common_rake"

def js_configuration(path)
  babel_file_path = File.join(Dir.pwd, "babel.config.json")

  Dir.chdir(path) do
    FileUtils.cp(babel_file_path, "babel.config.json")
    system("yarn add graphql-ws")
    system("yarn add @tarekraafat/autocomplete.js")
    system("yarn add @babel/plugin-proposal-private-methods")
    system("yarn add @babel/plugin-proposal-private-property-in-object")
    system("yarn install")
  end
end

desc "Generates a dummy app for testing"
task test_app: "decidim:generate_external_test_app" do
  ENV["RAILS_ENV"] = "test"
  js_configuration("spec/decidim_dummy_app")
end

desc "Generates a development app."
task development_app: "decidim:generate_external_development_app" do
  js_configuration("development_app")
end
