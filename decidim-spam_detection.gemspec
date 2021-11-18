# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)

require "decidim/spam_detection/version"

Gem::Specification.new do |s|
  s.version = Decidim::SpamDetection.version
  s.authors = ["Armand Fardeau"]
  s.email = ["fardeauarmand@gmail.com"]
  s.license = "AGPL-3.0"
  s.homepage = "https://github.com/decidim/decidim-module-spam_detection"
  s.required_ruby_version = ">= 2.7"

  s.name = "decidim-spam_detection"
  s.summary = "A decidim spam_detection module"
  s.description = "."

  s.files = Dir["{app,config,lib}/**/*", "LICENSE-AGPLv3.txt", "Rakefile", "README.md"]

  s.add_dependency "decidim-core", "~> #{Decidim::SpamDetection.version}"
end
