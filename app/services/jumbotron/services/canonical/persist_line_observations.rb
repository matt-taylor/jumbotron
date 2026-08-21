# frozen_string_literal: true

require "bigdecimal"

module Jumbotron
  module Services
    module Canonical
      class PersistLineObservations < CommandTower::Services::ApplicationService
        validate :ingest, required: true

        def call
          unless ingest.is_a?(Jumbotron::Canonical::LineIngestInput)
            context.fail!(
              application_error: Jumbotron::Errors::Canonical::InvalidLineIngestError.new(
                details: { message: "ingest must be Canonical::LineIngestInput" }
              )
            )
            return
          end

          if ingest.game_identities.blank? || ingest.provider.blank? || ingest.adapter_scope.blank? ||
             ingest.observed_at.blank?
            context.fail!(
              application_error: Jumbotron::Errors::Canonical::InvalidLineIngestError.new(
                details: { message: "provider, adapter_scope, observed_at, and game_identities are required" }
              )
            )
            return
          end

          created = 0
          updated = 0
          bookmakers_created = 0
          resolved_ids = {}

          transaction do
            game = resolve_game!
            batch = ObservationBatch.create!(
              provider: ingest.provider,
              adapter_scope: ingest.adapter_scope,
              observed_at: ingest.observed_at,
              metadata: {}
            )

            ingest.observations.each do |row|
              bookmaker = resolved_ids[bookmaker_key(row.bookmaker_identity)]
              unless bookmaker
                ensured = EnsureBookmaker.call(
                  identity: row.bookmaker_identity,
                  name: row.bookmaker_name,
                  observed_at: ingest.observed_at
                )
                fail_transaction!(ensured) unless ensured.success?

                bookmaker = ensured.data[:bookmaker]
                resolved_ids[bookmaker_key(row.bookmaker_identity)] = bookmaker
                bookmakers_created += 1 if ensured.data[:created]
              end

              case persist_row!(game, bookmaker, batch, row)
              when :created
                created += 1
              when :updated
                updated += 1
              end
            end

            context.observation_batch_id = batch.id
            context.bookmakers_resolved = resolved_ids.size
            context.bookmakers_created = bookmakers_created
            context.observations_created = created
            context.observations_updated = updated
          end
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
          context.fail!(
            application_error: Jumbotron::Errors::Canonical::MutationFailedError.new(
              details: { message: e.message }
            )
          )
        end

        private

        def resolve_game!
          ingest.game_identities.each do |ref|
            identity = ProviderIdentity.find_by(
              provider: ref.provider,
              object_namespace: ref.namespace,
              provider_id: ref.id
            )
            return identity.target if identity&.target.is_a?(Game)
          end

          fail_transaction!(Jumbotron::Errors::Canonical::GameNotFoundError.new)
        end

        def persist_row!(game, bookmaker, batch, row)
          existing = LineObservation.lock.where(
            game_id: game.id,
            bookmaker_id: bookmaker.id,
            market: row.market,
            outcome: row.outcome,
            source: row.source
          ).order(observed_at: :desc, id: :desc).first

          if existing && same_values?(existing, row)
            existing.observed_at = ingest.observed_at
            existing.save!
            return :updated
          end

          LineObservation.create!(
            game: game,
            bookmaker: bookmaker,
            observation_batch: batch,
            market: row.market,
            outcome: row.outcome,
            source: row.source,
            line_value: row.line_value,
            price_american: row.price_american,
            observed_at: ingest.observed_at,
            changed_at: ingest.observed_at
          )
          :created
        end

        def same_values?(existing, row)
          same_decimal?(existing.line_value, row.line_value) &&
            existing.price_american == row.price_american
        end

        def same_decimal?(left, right)
          return true if left.nil? && right.nil?
          return false if left.nil? || right.nil?

          BigDecimal(left.to_s) == BigDecimal(right.to_s)
        end

        def bookmaker_key(identity)
          [identity.provider, identity.namespace, identity.id]
        end
      end
    end
  end
end
