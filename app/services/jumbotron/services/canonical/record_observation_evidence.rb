# frozen_string_literal: true

module Jumbotron
  module Services
    module Canonical
      class RecordObservationEvidence < CommandTower::Services::ApplicationService
        validate :change_set, required: true
        validate :provider, is_a: String, required: true
        validate :adapter_scope, is_a: String, required: true
        validate :observed_at, required: true

        def call
          unless change_set.any?
            context.observation_batch_id = nil
            context.historical_change_count = 0
            return
          end

          batch = ObservationBatch.create!(
            provider: provider,
            adapter_scope: adapter_scope,
            observed_at: observed_at,
            metadata: {}
          )

          change_set.each do |entry|
            HistoricalChange.create!(
              observation_batch: batch,
              subject_type: entry.subject.class.name,
              subject_id: entry.subject.id,
              attribute_name: entry.attribute,
              previous_value: entry.previous,
              new_value: entry.new_value,
              observed_at: observed_at,
              provider: provider
            )
          end

          context.observation_batch_id = batch.id
          context.historical_change_count = change_set.size
        rescue ActiveRecord::RecordInvalid => e
          context.fail!(
            application_error: Jumbotron::Errors::Canonical::ObservationEvidenceFailedError.new(
              details: { message: e.message }
            )
          )
        end
      end
    end
  end
end
