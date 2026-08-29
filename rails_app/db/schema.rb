# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_28_220001) do
  create_table "jumbotron_bookmakers", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "changed_at", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "observed_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "jumbotron_game_participants", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "changed_at", null: false
    t.datetime "created_at", null: false
    t.bigint "game_id", null: false
    t.datetime "observed_at", null: false
    t.datetime "record_observed_at"
    t.string "record_summary_current"
    t.string "record_summary_entering"
    t.string "record_summary_post_game"
    t.string "result"
    t.string "role"
    t.integer "score"
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "team_id"], name: "idx_jumbotron_gp_game_team", unique: true
    t.index ["game_id"], name: "index_jumbotron_game_participants_on_game_id"
    t.index ["team_id"], name: "index_jumbotron_game_participants_on_team_id"
  end

  create_table "jumbotron_games", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "changed_at", null: false
    t.datetime "created_at", null: false
    t.bigint "league_id", null: false
    t.string "lifecycle", default: "scheduled", null: false
    t.boolean "neutral_site", default: false, null: false
    t.datetime "observed_at", null: false
    t.string "progress_clock_display"
    t.string "progress_clock_mode"
    t.integer "progress_clock_seconds"
    t.string "progress_segment_kind"
    t.integer "progress_segment_number"
    t.string "progress_state"
    t.bigint "schedule_group_id"
    t.datetime "scheduled_at"
    t.bigint "season_id", null: false
    t.bigint "season_phase_id"
    t.datetime "updated_at", null: false
    t.bigint "venue_id"
    t.index ["league_id"], name: "index_jumbotron_games_on_league_id"
    t.index ["schedule_group_id"], name: "index_jumbotron_games_on_schedule_group_id"
    t.index ["season_id"], name: "index_jumbotron_games_on_season_id"
    t.index ["season_phase_id"], name: "index_jumbotron_games_on_season_phase_id"
    t.index ["venue_id"], name: "index_jumbotron_games_on_venue_id"
  end

  create_table "jumbotron_historical_changes", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "attribute_name", null: false
    t.datetime "created_at", null: false
    t.text "new_value", size: :long, collation: "utf8mb4_bin"
    t.bigint "observation_batch_id", null: false
    t.datetime "observed_at", null: false
    t.text "previous_value", size: :long, collation: "utf8mb4_bin"
    t.string "provider", null: false
    t.bigint "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["observation_batch_id"], name: "idx_jumbotron_hist_changes_batch"
    t.index ["subject_type", "subject_id"], name: "idx_jumbotron_hist_changes_subject"
    t.check_constraint "json_valid(`new_value`)", name: "new_value"
    t.check_constraint "json_valid(`previous_value`)", name: "previous_value"
  end

  create_table "jumbotron_leagues", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "sport_id", null: false
    t.datetime "updated_at", null: false
    t.index ["sport_id"], name: "index_jumbotron_leagues_on_sport_id"
  end

  create_table "jumbotron_line_observations", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "bookmaker_id", null: false
    t.datetime "changed_at", null: false
    t.datetime "created_at", null: false
    t.bigint "game_id", null: false
    t.decimal "line_value", precision: 8, scale: 3
    t.string "market", limit: 32, null: false
    t.bigint "observation_batch_id", null: false
    t.datetime "observed_at", null: false
    t.string "outcome", limit: 32, null: false
    t.integer "price_american"
    t.string "source", limit: 32, null: false
    t.datetime "updated_at", null: false
    t.index ["bookmaker_id"], name: "index_jumbotron_line_observations_on_bookmaker_id"
    t.index ["game_id", "bookmaker_id", "market", "outcome", "source", "observed_at"], name: "idx_jumbotron_line_obs_latest"
    t.index ["game_id"], name: "index_jumbotron_line_observations_on_game_id"
    t.index ["observation_batch_id"], name: "index_jumbotron_line_observations_on_observation_batch_id"
  end

  create_table "jumbotron_observation_batches", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "adapter_scope", null: false
    t.datetime "created_at", null: false
    t.text "metadata", size: :long, collation: "utf8mb4_bin"
    t.datetime "observed_at", null: false
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "adapter_scope", "observed_at"], name: "idx_jumbotron_obs_batches_scope_time"
    t.check_constraint "json_valid(`metadata`)", name: "metadata"
  end

  create_table "jumbotron_provider_identities", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "object_namespace", limit: 64, null: false
    t.string "provider", limit: 64, null: false
    t.string "provider_id", limit: 191, null: false
    t.bigint "target_id", null: false
    t.string "target_type", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "object_namespace", "provider_id"], name: "idx_jumbotron_pi_identity", unique: true
    t.index ["target_type", "target_id"], name: "idx_jumbotron_pi_target"
  end

  create_table "jumbotron_schedule_groups", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.string "name", null: false
    t.integer "number"
    t.bigint "season_id", null: false
    t.bigint "season_phase_id"
    t.datetime "updated_at", null: false
    t.index ["season_id", "season_phase_id", "kind", "name"], name: "idx_jumbotron_sg_identity", unique: true
    t.index ["season_id"], name: "index_jumbotron_schedule_groups_on_season_id"
    t.index ["season_phase_id"], name: "index_jumbotron_schedule_groups_on_season_phase_id"
  end

  create_table "jumbotron_season_phases", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "season_id", null: false
    t.datetime "updated_at", null: false
    t.index ["season_id"], name: "index_jumbotron_season_phases_on_season_id"
  end

  create_table "jumbotron_seasons", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "ends_on"
    t.bigint "league_id", null: false
    t.string "name", null: false
    t.date "starts_on"
    t.datetime "updated_at", null: false
    t.index ["league_id"], name: "index_jumbotron_seasons_on_league_id"
  end

  create_table "jumbotron_sports", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "jumbotron_teams", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "abbreviation"
    t.datetime "changed_at", null: false
    t.datetime "created_at", null: false
    t.string "key", limit: 191, null: false
    t.string "name", null: false
    t.string "nickname"
    t.datetime "observed_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_jumbotron_teams_on_key", unique: true
  end

  create_table "jumbotron_venues", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "changed_at", null: false
    t.string "city"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "observed_at", null: false
    t.string "region"
    t.datetime "updated_at", null: false
  end

  create_table "messaging_channel_deliveries", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "channel_key", null: false
    t.bigint "communication_id", null: false
    t.datetime "created_at", null: false
    t.integer "execution_attempt_count", default: 0, null: false
    t.datetime "execution_claimed_at"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["communication_id", "channel_key"], name: "index_messaging_channel_deliveries_on_comm_and_channel", unique: true
    t.index ["communication_id"], name: "index_messaging_channel_deliveries_on_communication_id"
    t.index ["status", "execution_claimed_at", "updated_at"], name: "index_messaging_channel_deliveries_on_execution_recovery"
  end

  create_table "messaging_communications", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "accept_request_fingerprint"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "execution_handoff_status", null: false
    t.string "host_event_identity"
    t.text "metadata"
    t.string "notification_type_key", null: false
    t.string "status"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["status", "execution_handoff_status", "updated_at"], name: "index_messaging_communications_on_handoff_recovery"
    t.index ["user_id", "notification_type_key", "host_event_identity"], name: "index_messaging_communications_on_idempotency_namespace", unique: true
    t.index ["user_id"], name: "index_messaging_communications_on_user_id"
  end

  create_table "messaging_delivery_attempts", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "channel_delivery_id", null: false
    t.datetime "created_at", null: false
    t.string "error_class"
    t.string "error_code"
    t.datetime "finished_at"
    t.string "normalized_provider_status"
    t.string "provider_message_id"
    t.datetime "started_at", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_delivery_id", "status"], name: "index_messaging_delivery_attempts_on_delivery_and_status"
    t.index ["channel_delivery_id"], name: "index_messaging_delivery_attempts_on_channel_delivery_id"
  end

  create_table "messaging_destination_plans", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "communication_id", null: false
    t.datetime "created_at", null: false
    t.text "decision"
    t.datetime "updated_at", null: false
    t.index ["communication_id"], name: "index_messaging_destination_plans_on_communication_id", unique: true
  end

  create_table "messaging_endpoint_pushover_credentials", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.text "application_token_ciphertext", null: false
    t.datetime "created_at", null: false
    t.integer "encryption_key_version", default: 1, null: false
    t.bigint "messaging_endpoint_id", null: false
    t.datetime "updated_at", null: false
    t.text "user_key_ciphertext", null: false
    t.index ["messaging_endpoint_id"], name: "index_messaging_pushover_credentials_on_endpoint_id", unique: true
  end

  create_table "messaging_endpoints", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "active_fingerprint"
    t.text "address_ciphertext"
    t.string "address_fingerprint", null: false
    t.string "channel_key", null: false
    t.datetime "created_at", null: false
    t.integer "encryption_key_version", default: 1, null: false
    t.datetime "last_successful_use_at"
    t.string "lifecycle_state", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "masked_display_value", null: false
    t.datetime "revoked_at"
    t.string "single_active_slot"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "verification_state", null: false
    t.datetime "verified_at"
    t.index ["single_active_slot"], name: "index_messaging_endpoints_single_active_slot", unique: true
    t.index ["user_id", "channel_key", "active_fingerprint"], name: "index_messaging_endpoints_active_fingerprint", unique: true
    t.index ["user_id", "channel_key"], name: "index_messaging_endpoints_owner_channel"
    t.index ["user_id"], name: "index_messaging_endpoints_on_user_id"
    t.check_constraint "`lifecycle_state` in (_utf8mb4'active',_utf8mb4'revoked',_utf8mb4'invalid',_utf8mb4'retired')", name: "chk_messaging_endpoints_lifecycle"
    t.check_constraint "`verification_state` in (_utf8mb4'unverified',_utf8mb4'pending',_utf8mb4'verified',_utf8mb4'failed')", name: "chk_messaging_endpoints_verification"
  end

  create_table "messaging_inbox_items", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "archived_at"
    t.bigint "communication_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "status"
    t.datetime "updated_at", null: false
    t.datetime "viewed_at"
    t.index ["communication_id"], name: "index_messaging_inbox_items_on_communication_id", unique: true
    t.index ["deleted_at", "archived_at", "viewed_at"], name: "index_messaging_inbox_items_on_lifecycle"
  end

  create_table "messaging_notification_preferences", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "notification_type_key", null: false
    t.text "state", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "notification_type_key"], name: "index_messaging_notification_preferences_unique", unique: true
    t.index ["user_id"], name: "index_messaging_notification_preferences_on_user_id"
  end

  create_table "user_secrets", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "death_time"
    t.string "extra"
    t.string "reason"
    t.string "secret"
    t.datetime "updated_at", null: false
    t.integer "use_count", default: 0
    t.integer "use_count_max"
    t.bigint "user_id", null: false
    t.index ["secret"], name: "index_user_secrets_on_secret", unique: true
    t.index ["user_id"], name: "index_user_secrets_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.boolean "email_validated", default: false
    t.string "first_name", default: "", null: false
    t.string "last_known_timezone"
    t.timestamp "last_known_timezone_update"
    t.datetime "last_login"
    t.string "last_login_strategy"
    t.string "last_name", default: "", null: false
    t.integer "password_consecutive_fail", default: 0
    t.string "password_digest", default: "", null: false
    t.string "phone_number"
    t.boolean "phone_number_validated", default: false, null: false
    t.string "recovery_password_digest", default: "", null: false
    t.string "roles", default: ""
    t.integer "successful_login", default: 0
    t.datetime "updated_at", null: false
    t.string "username"
    t.string "verifier_token"
    t.datetime "verifier_token_last_reset"
    t.index ["phone_number"], name: "index_users_on_phone_number", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "jumbotron_game_participants", "jumbotron_games", column: "game_id"
  add_foreign_key "jumbotron_game_participants", "jumbotron_teams", column: "team_id"
  add_foreign_key "jumbotron_games", "jumbotron_leagues", column: "league_id"
  add_foreign_key "jumbotron_games", "jumbotron_schedule_groups", column: "schedule_group_id"
  add_foreign_key "jumbotron_games", "jumbotron_season_phases", column: "season_phase_id"
  add_foreign_key "jumbotron_games", "jumbotron_seasons", column: "season_id"
  add_foreign_key "jumbotron_games", "jumbotron_venues", column: "venue_id"
  add_foreign_key "jumbotron_historical_changes", "jumbotron_observation_batches", column: "observation_batch_id"
  add_foreign_key "jumbotron_leagues", "jumbotron_sports", column: "sport_id"
  add_foreign_key "jumbotron_line_observations", "jumbotron_bookmakers", column: "bookmaker_id"
  add_foreign_key "jumbotron_line_observations", "jumbotron_games", column: "game_id"
  add_foreign_key "jumbotron_line_observations", "jumbotron_observation_batches", column: "observation_batch_id"
  add_foreign_key "jumbotron_schedule_groups", "jumbotron_season_phases", column: "season_phase_id"
  add_foreign_key "jumbotron_schedule_groups", "jumbotron_seasons", column: "season_id"
  add_foreign_key "jumbotron_season_phases", "jumbotron_seasons", column: "season_id"
  add_foreign_key "jumbotron_seasons", "jumbotron_leagues", column: "league_id"
  add_foreign_key "messaging_channel_deliveries", "messaging_communications", column: "communication_id", on_delete: :cascade
  add_foreign_key "messaging_communications", "users"
  add_foreign_key "messaging_delivery_attempts", "messaging_channel_deliveries", column: "channel_delivery_id", on_delete: :cascade
  add_foreign_key "messaging_destination_plans", "messaging_communications", column: "communication_id", on_delete: :cascade
  add_foreign_key "messaging_endpoint_pushover_credentials", "messaging_endpoints", on_delete: :cascade
  add_foreign_key "messaging_endpoints", "users"
  add_foreign_key "messaging_inbox_items", "messaging_communications", column: "communication_id", on_delete: :cascade
  add_foreign_key "messaging_notification_preferences", "users"
  add_foreign_key "user_secrets", "users"
end
