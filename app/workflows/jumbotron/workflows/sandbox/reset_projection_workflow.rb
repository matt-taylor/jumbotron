# frozen_string_literal: true

module Jumbotron
  module Workflows
    module Sandbox
      class ResetProjectionWorkflow < CommandTower::Workflows::ApplicationWorkflow
        include Jumbotron::Workflows::PublicRead

        retry_strategy :none

        def call(**kwargs)
          deserialized = Jumbotron::Deserializers::Public::ResetSandboxProjection.call(kwargs)
          return map_deserializer_failure(deserialized) unless deserialized.success?

          request = deserialized.input
          projection = Jumbotron::SandboxProjection.find_by(name: request.sandbox)
          return missing_projection if projection.nil?
          return unsafe_projection if unsafe_projection?(projection)

          built = Jumbotron::Services::Sandbox::BuildSourceSnapshot.call(
            projection: projection,
            start_week: request.start_week,
            anchor_day: request.anchor_day,
            now: request.now
          )
          return map_service_failure(built) unless built.success?

          reset_in_transaction(projection, built.data[:snapshot], request.now)
        end

        private

        def reset_in_transaction(projection, snapshot, reset_at)
          transaction do
            projection = Jumbotron::SandboxProjection.lock.find(projection.id)
            counts = exact_retry?(projection, snapshot) ? retry_counts : reconcile!(projection, snapshot, reset_at)
            validation = Jumbotron::Services::Sandbox::ValidateProjectedSeason.call(
              projection: projection,
              snapshot: snapshot,
              now: reset_at
            )
            fail_transaction!(map_service_failure(validation)) unless validation.success?

            counts[:start_week] = validation.data[:start_week_game_count]
            counts[:naturally_locked] = validation.data[:naturally_locked_game_count]
            persist_success!(projection, snapshot, reset_at)
            render_result!(projection, snapshot, counts, reset_at)
          end
        end

        def reconcile!(projection, snapshot, reset_at)
          change_set = Jumbotron::Canonical::ChangeSet.new
          added = 0

          snapshot.games.each do |projected_game|
            projected = Jumbotron::Services::Sandbox::ProjectGame.call(
              projection: projection,
              projected_game: projected_game,
              observed_at: reset_at,
              change_set: change_set
            )
            fail_transaction!(map_service_failure(projected)) unless projected.success?
            added += 1 if projected.data[:created]
          end

          removed = remove_stale!(projection, snapshot)
          geometry = Jumbotron::Services::Sandbox::RemoveEmptyProjectionGeometry.call(projection: projection)
          fail_transaction!(map_service_failure(geometry)) unless geometry.success?
          seed_all!(projection, snapshot, reset_at, change_set)
          {
            added: added,
            updated: snapshot.games.count - added,
            removed: removed,
            start_week: 0,
            naturally_locked: 0
          }
        end

        def remove_stale!(projection, snapshot)
          current_source_ids = snapshot.games.map(&:source_game_id)
          stale = projection.sandbox_game_mappings.where.not(source_game_id: current_source_ids).to_a
          stale.each do |mapping|
            result = Jumbotron::Services::Sandbox::RemoveMappedGame.call(mapping: mapping)
            fail_transaction!(map_service_failure(result)) unless result.success?
          end
          stale.count
        end

        def seed_all!(projection, snapshot, reset_at, change_set)
          mappings = projection.sandbox_game_mappings.index_by(&:source_game_id)
          snapshot.games.each do |projected_game|
            result = Jumbotron::Services::Sandbox::SeedProjectedGame.call(
              game: mappings.fetch(projected_game.source_game_id).sandbox_game,
              observed_at: reset_at,
              change_set: change_set
            )
            fail_transaction!(map_service_failure(result)) unless result.success?
          end
        end

        def render_result!(projection, snapshot, counts, reset_at)
          assembled = Jumbotron::Services::Public::AssembleSandboxProjectionReset.call(
            projection: projection,
            snapshot: snapshot,
            counts: counts,
            reset_at: reset_at
          )
          fail_transaction!(map_service_failure(assembled)) unless assembled.success?

          success(payload: { sandbox_reset: assembled.data[:public_reset] }, http_status: :ok)
        end

        def persist_success!(projection, snapshot, reset_at)
          projection.update!(
            last_reset_fingerprint: snapshot.fingerprint,
            last_reset_at: reset_at,
            last_date_shift_days: snapshot.date_shift_days
          )
        end

        def exact_retry?(projection, snapshot)
          projection.last_reset_fingerprint == snapshot.fingerprint
        end

        def retry_counts
          { added: 0, updated: 0, removed: 0, start_week: 0, naturally_locked: 0 }
        end

        def unsafe_projection?(projection)
          projection.adapter_id != "sandbox_nfl" ||
            projection.sandbox_season.league.name != "nfl-sandbox" ||
            projection.source_season_id == projection.sandbox_season_id
        end

        def missing_projection
          failure(
            errors: [Jumbotron::Errors::Sandbox::ProjectionNotFoundError.new],
            http_status: :not_found
          )
        end

        def unsafe_projection
          failure(
            errors: [
              Jumbotron::Errors::Sandbox::ProjectionRejectedError.new(
                details: {
                  code: "sandbox_target_forbidden",
                  message: "reset target is not a registered sandbox season"
                }
              )
            ],
            http_status: :unprocessable_entity
          )
        end
      end
    end
  end
end
