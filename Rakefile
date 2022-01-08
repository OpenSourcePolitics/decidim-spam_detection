# frozen_string_literal: true

require "decidim/dev/common_rake"

desc "Generates a dummy app for testing"
task test_app: "decidim:generate_external_test_app"

desc "Generates a development app."
task development_app: "decidim:generate_external_development_app"

task :push_release_tag do
  status = %x|git status|.split("\n").last
  raise "You have uncommitted file, cannot continue..." if status != "nothing to commit, working tree clean"
  system("git tag v#{Decidim::SpamDetection.version}")
  system("git push")
  system("git push --tags")
end