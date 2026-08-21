# frozen_string_literal: true

module Jumbotron
  module Adapters
    class Base
      class << self
        include LineAcquisition

        def register!
          Registry.register(self)
        end

        def registered?
          Registry.registered?(self)
        end

        def adapter_id(value = nil)
          if value.nil?
            return @adapter_id if defined?(@adapter_id) && @adapter_id

            raise ConfigurationError, "#{name} must declare adapter_id"
          end

          @adapter_id = value.to_s
        end

        def provider(value = nil)
          return @provider || raise(ConfigurationError, "#{name} must declare provider") if value.nil?

          @provider = value.to_s.downcase
        end

        def sport(value = nil)
          return @sport || raise(ConfigurationError, "#{name} must declare sport") if value.nil?

          @sport = value.to_s
        end

        def league(value = nil)
          return @league || raise(ConfigurationError, "#{name} must declare league") if value.nil?

          @league = value.to_s
        end

        def endpoint(name, resource:, transformer:)
          endpoints[name.to_sym] = { resource: resource, transformer: transformer }
        end

        def endpoints
          @endpoints ||= {}
        end

        # Declare: policy :id, type:, cadence: nil, eligible: nil
        # Lookup:  policy(:id)
        def policy(id, type: nil, cadence: nil, eligible: nil)
          key = id.to_sym
          declaring = !type.nil? || !cadence.nil? || !eligible.nil?

          unless declaring
            return policies.fetch(key) do
              raise UnknownPolicyError, "#{name} has no policy :#{key}"
            end
          end

          raise ConfigurationError, "#{name} policy :#{key} must declare type" if type.nil?

          policies[key] = PolicyDefinition.new(
            id: key,
            type: type.to_sym,
            cadence: cadence,
            eligible: eligible
          )
        end

        def policies
          @policies ||= {}
        end

        def policy_ids
          policies.keys
        end

        def discovery(id, endpoint: nil)
          key = id.to_sym
          if endpoint.nil?
            return discoveries.fetch(key) do
              raise UnknownDiscoveryError, "#{name} has no discovery :#{key}"
            end
          end

          discoveries[key] = DiscoveryDefinition.new(id: key, endpoint: endpoint.to_sym)
        end

        def discoveries
          @discoveries ||= {}
        end

        def discovery_ids
          discoveries.keys
        end

        def operation(name)
          Registry.assert_unique_keys!
          definition = endpoints[name.to_sym]
          raise ConfigurationError, "#{self.name} has no endpoint :#{name}" unless definition

          Operation.new(
            adapter: self,
            resource: definition[:resource],
            transformer: definition[:transformer]
          )
        end

        def registry_key
          [provider, sport, league]
        end

        def acquisition_scope_for(_game)
          raise ConfigurationError, "#{name} must implement acquisition_scope_for"
        end

        def scopes_for_discovery(_definition)
          raise ConfigurationError, "#{name} must implement scopes_for_discovery"
        end

        def provider_cooling_down?
          false
        end

        def provider_retry_after
          0
        end
      end
    end
  end
end
