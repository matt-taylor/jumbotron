# frozen_string_literal: true

module Jumbotron
  module Services
    module Canonical
      class EnsureBookmaker < CommandTower::Services::ApplicationService
        validate :identity, required: true
        validate :name, is_a: String, required: true
        validate :observed_at, required: true

        def call
          existing = find_identity
          bookmaker = if existing&.target.is_a?(Bookmaker)
                        update_existing!(existing.target)
                      else
                        create_new!
                      end

          attach = AttachProviderIdentities.call(target: bookmaker, refs: [identity])
          unless attach.success?
            context.fail!(application_error: attach.errors.first)
            return
          end

          context.bookmaker = bookmaker
          context.created = existing.nil?
        rescue ActiveRecord::RecordNotUnique
          recovered = find_identity
          context.bookmaker = update_existing!(recovered.target)
          context.created = false
        rescue ActiveRecord::RecordInvalid => e
          context.fail!(
            application_error: Jumbotron::Errors::Canonical::MutationFailedError.new(
              details: { message: e.message }
            )
          )
        end

        private

        def find_identity
          ProviderIdentity.find_by(
            provider: identity.provider,
            object_namespace: identity.namespace,
            provider_id: identity.id
          )
        end

        def create_new!
          Bookmaker.create!(
            name: name,
            observed_at: observed_at,
            changed_at: observed_at
          )
        end

        def update_existing!(bookmaker)
          locked = Bookmaker.lock.find(bookmaker.id)
          if locked.name != name
            locked.name = name
            locked.changed_at = observed_at
          end
          locked.observed_at = observed_at
          locked.save!
          locked
        end
      end
    end
  end
end
