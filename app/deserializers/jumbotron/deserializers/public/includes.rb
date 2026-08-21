# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Public
      module Includes
        module_function

        def parse(raw)
          return CommandTower::Deserializers::CoercionResult.ok([]) if raw.nil?

          list = raw.is_a?(Array) ? raw : [raw]
          symbols = list.map { |item| item.is_a?(String) ? item.strip.to_sym : item }
          unless symbols.all? { |item| item.is_a?(Symbol) && item != :"" }
            return CommandTower::Deserializers::CoercionResult.fail(code: "invalid_request", field: "include")
          end

          unknown = symbols - Jumbotron::Public::ALLOWED_INCLUDES
          if unknown.any?
            return CommandTower::Deserializers::CoercionResult.fail(
              code: "invalid_request",
              field: "include",
              details: { unknown: unknown }
            )
          end

          CommandTower::Deserializers::CoercionResult.ok(symbols.uniq)
        end
      end
    end
  end
end
