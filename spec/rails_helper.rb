# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require File.expand_path("../rails_app/config/environment.rb", __dir__)
abort("The Rails environment is running in <#{Rails.env}> mode!") unless Rails.env.test?
require "rspec/rails"
require "factory_bot_rails"
require "jumbotron/testing"

Jumbotron::Testing.install!

ActiveRecord::Migrator.migrations_paths = [
  Jumbotron::Engine.root.join("db/migrate").to_s,
  Rails.root.join("db/migrate").to_s
]

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include ActiveJob::TestHelper
  config.use_transactional_fixtures = true
  config.filter_rails_from_backtrace!

  config.before { Rails.cache.clear }

  support = Jumbotron::Engine.root.join("spec/support")
  Rails.autoloaders.main.ignore(support) if defined?(Rails) && Rails.autoloaders.main
  Dir[support.join("**/*.rb")].each { |f| require f }
end
