# frozen_string_literal: true

source "https://rubygems.org"

ruby file: ".ruby-version"

# Lota isn't on RubyGems.org: bin/setup downloads its gems from Lota's
# GitHub release into vendor/cache, where Bundler finds them.
gem "lota", "0.1.3"

group :development, :test do
  gem "minitest", "~> 5.25"
  gem "rake", "~> 13.2"
end
