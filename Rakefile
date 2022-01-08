# frozen_string_literal: true

require "decidim/dev/common_rake"

desc "Generates a dummy app for testing"
task test_app: "decidim:generate_external_test_app"

desc "Generates a development app."
task development_app: "decidim:generate_external_development_app"

task :push_tag do
  system("git tag v#{Decidim::SpamDetection.version}")
  system("git push --tags")
  print("v#{Decidim::SpamDetection.version}")
end
