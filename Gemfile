# frozen_string_literal: true

source "https://rubygems.org"

ruby RUBY_VERSION

gem "decidim", "~> 0.27.0"
gem "decidim-spam_detection", path: "."

gem "bootsnap", "~> 1.4"
gem "puma", ">= 5.0.0"
gem "uglifier", "~> 4.1"
gem "webpacker", "6.0.0.rc.5"

group :development, :test do
  gem "byebug", "~> 11.0", platform: :mri
  gem "rubocop-faker"
  gem "rubocop-performance", "~> 1.6.0"

  gem "decidim-dev", "~> 0.27.0"
end

group :development do
  gem "faker", "~> 2.14"
  gem "letter_opener_web", "~> 1.4"
  gem "listen", "~> 3.1"
  gem "spring", "~> 2.0"
  gem "spring-watcher-listen", "~> 2.0"
  gem "web-console", "~> 3.7"
end

group :test do
  gem "codecov", require: false
end
