# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "factory_bot_rails"
# Rails 8.1.3.1 still calls JSON.parse(json, options) positionally; json 3.0 is keyword-only.
gem "json", "< 3"
gem "mysql2"
gem "rails", ENV.fetch("BUNDLER_RAILS_VERSION", "~> 8")
gem "rspec_junit_formatter"
gem "rspec-rails"
gem "rubocop", require: false
gem "rubocop-rails", require: false
gem "rubocop-rspec", require: false
