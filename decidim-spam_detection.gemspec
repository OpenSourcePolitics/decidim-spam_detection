# frozen_string_literal: true

$LOAD_PATH.push File.expand_path("lib", __dir__)

require "decidim/spam_detection/version"

Gem::Specification.new do |s|
  s.version = Decidim::SpamDetection.version
  s.authors = ["Armand Fardeau"]
  s.email = ["fardeauarmand@gmail.com"]
  s.license = "AGPL-3.0"
  s.homepage = "https://github.com/OpenSourcePolitics/decidim-spam_detection"
  s.required_ruby_version = ">= 2.7"

  s.name = "decidim-spam_detection"
  s.summary = "A decidim spam_detection module"
  s.description = <<-DESCRIPTION
  SpamDetection is a detection bot made by OpenSourcePolitics. 
  It works with a spam detection service (https://github.com/OpenSourcePolitics/spam_detection) 
  which marks the user with a spam probability score, 
  between 0.7 and 0.99 it is probable, and above 0.99 it is very sure.
  DESCRIPTION

  s.files = Dir["{app,config,lib}/**/*", "LICENSE-AGPLv3.txt", "Rakefile", "README.md"]

  s.add_dependency "decidim-core", "~> #{Decidim::SpamDetection.version}"
end
