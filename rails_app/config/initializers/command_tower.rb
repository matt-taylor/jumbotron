# frozen_string_literal: true

# Minimal CT host wiring for Jumbotron dummy.
# No HTTP mount — clients need CommandTower boot + users schema only.
CommandTower.configure do |config|
  config.jwt.hmac_secret = ENV.fetch("SECRET_KEY_BASE") { Rails.application.secret_key_base }
  config.admin.enable = false
  config.application.url = ENV.fetch("APPLICATION_URL", "http://localhost:3000")
end
