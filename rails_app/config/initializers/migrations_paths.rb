# frozen_string_literal: true

# CT copy-on-install migrations live under the dummy host. Jumbotron Engine
# migrations are already on the path via the Engine.
host_migrate = Rails.root.join("db/migrate").to_s
Rails.application.config.paths["db/migrate"] << host_migrate
