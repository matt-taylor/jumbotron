# frozen_string_literal: true

module Jumbotron
  module Services
    module Canonical
      class AttachProviderIdentities < CommandTower::Services::ApplicationService
        validate :target, required: true
        validate :refs, is_a: Array, required: true

        def call
          conflict = refs.find { |ref| conflicting_identity?(ref) }
          if conflict
            context.fail!(
              application_error: Jumbotron::Errors::Canonical::ProviderIdentityConflictError.new
            )
            return
          end

          refs.each { |ref| ensure_identity!(ref) }
          context.target = target
        rescue ActiveRecord::RecordInvalid => e
          context.fail!(
            application_error: Jumbotron::Errors::Canonical::MutationFailedError.new(
              details: { message: e.message }
            )
          )
        end

        private

        def conflicting_identity?(ref)
          identity = find_identity(ref)
          return false unless identity

          identity.target_type != target.class.name || identity.target_id != target.id
        end

        def ensure_identity!(ref)
          return if find_identity(ref)

          ProviderIdentity.create!(
            provider: ref.provider,
            object_namespace: ref.namespace,
            provider_id: ref.id,
            target: target
          )
        end

        def find_identity(ref)
          ProviderIdentity.find_by(
            provider: ref.provider,
            object_namespace: ref.namespace,
            provider_id: ref.id
          )
        end
      end
    end
  end
end
