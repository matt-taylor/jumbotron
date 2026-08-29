# frozen_string_literal: true

module Jumbotron
  module Services
    module Canonical
      class UpsertVenue < CommandTower::Services::ApplicationService
        validate :venue_input, required: false
        validate :observed_at, required: true
        validate :change_set, required: true

        def call
          if venue_input.nil?
            context.venue = nil
            return
          end

          ref = venue_input.provider_identities.first
          identity = ProviderIdentity.find_by(
            provider: ref.provider,
            object_namespace: ref.namespace,
            provider_id: ref.id
          )

          venue = resolve_venue(identity)

          attach = AttachProviderIdentities.call(target: venue, refs: venue_input.provider_identities)
          unless attach.success?
            context.fail!(application_error: attach.errors.first)
            return
          end

          context.venue = venue
        rescue ActiveRecord::RecordNotUnique
          context.venue = recover_after_race!
        rescue ActiveRecord::RecordInvalid => e
          context.fail!(
            application_error: Jumbotron::Errors::Canonical::MutationFailedError.new(
              details: { message: e.message }
            )
          )
        end

        private

        def resolve_venue(identity)
          if identity&.target.is_a?(Venue)
            update_existing!(identity.target_id)
          else
            create_new!
          end
        end

        def update_existing!(venue_id)
          venue = Venue.lock.find(venue_id)
          material = false
          if venue.name != venue_input.name
            change_set.record(
              subject: venue,
              attribute: "name",
              previous: venue.name,
              new_value: venue_input.name
            )
            venue.name = venue_input.name
            material = true
          end
          material |= apply_location!(venue)
          venue.changed_at = observed_at if material
          venue.observed_at = observed_at
          venue.save!
          venue
        end

        def create_new!
          venue = Venue.create!(
            name: venue_input.name,
            city: venue_input.city,
            region: venue_input.region,
            observed_at: observed_at,
            changed_at: observed_at
          )
          change_set.record(subject: venue, attribute: "name", previous: nil, new_value: venue.name)
          if venue.city.present?
            change_set.record(subject: venue, attribute: "city", previous: nil, new_value: venue.city)
          end
          if venue.region.present?
            change_set.record(subject: venue, attribute: "region", previous: nil, new_value: venue.region)
          end
          venue
        end

        def apply_location!(venue)
          material = false
          {
            city: venue_input.city,
            region: venue_input.region
          }.each do |key, value|
            next if value.nil?
            next if venue.public_send(key) == value

            change_set.record(
              subject: venue,
              attribute: key.to_s,
              previous: venue.public_send(key),
              new_value: value
            )
            venue.public_send("#{key}=", value)
            material = true
          end
          material
        end

        def recover_after_race!
          ref = venue_input.provider_identities.first
          identity = ProviderIdentity.find_by!(
            provider: ref.provider,
            object_namespace: ref.namespace,
            provider_id: ref.id
          )
          Venue.lock.find(identity.target_id)
        end
      end
    end
  end
end
