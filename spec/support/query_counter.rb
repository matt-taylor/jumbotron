# frozen_string_literal: true

module Jumbotron
  module Spec
    module QueryCounter
      IGNORE = /\A(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE SAVEPOINT)/i

      def capture_queries(&)
        sqls = []
        callback = lambda do |_name, _start, _finish, _id, payload|
          sql = payload[:sql].to_s
          next if payload[:cached]
          next if payload[:name] == "SCHEMA"
          next if IGNORE.match?(sql)

          sqls << sql
        end
        result = ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &)
        [sqls, result]
      end

      def count_queries(&)
        capture_queries(&).first.size
      end
    end
  end
end

RSpec.configure do |config|
  config.include Jumbotron::Spec::QueryCounter
end
