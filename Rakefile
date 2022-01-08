# frozen_string_literal: true

require "decidim/dev/common_rake"

desc "Generates a dummy app for testing"
task test_app: "decidim:generate_external_test_app"

desc "Generates a development app."
task development_app: "decidim:generate_external_development_app"

task :push_tag_and_release do
  system("git tag v#{Decidim::SpamDetection.version}")
  system("git push --tags")
  system("gh release create v#{Decidim::SpamDetection.version}")
end
