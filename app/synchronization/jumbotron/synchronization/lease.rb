# frozen_string_literal: true

require "securerandom"

module Jumbotron
  module Synchronization
    class UnsupportedStoreError < StandardError; end

    # Narrow single-writer lease. Contract is backend-neutral; atomic acquire/release
    # require a capable cache/store (MemoryStore or RedisCacheStore). NullStore is rejected.
    class Lease
      DEFAULT_TTL_SECONDS = 120
      KEY_PREFIX = "jumbotron:synchronization:lease"

      COMPARE_AND_DELETE_LUA = <<~LUA
        if redis.call("get", KEYS[1]) == ARGV[1] then
          return redis.call("del", KEYS[1])
        else
          return 0
        end
      LUA

      Result = Data.define(:acquired, :token, :scope) do
        def acquired?
          acquired
        end
      end

      def self.scope(adapter_id:, endpoint:, acquisition:)
        parts = [
          adapter_id.to_s,
          endpoint.to_s,
          *normalized_acquisition_parts(acquisition)
        ]
        parts.join(":")
      end

      def self.normalized_acquisition_parts(acquisition)
        hash = acquisition.respond_to?(:to_h) ? acquisition.to_h : {}
        hash = hash.transform_keys(&:to_s)
        hash.keys.sort.map { |key| hash[key].to_s }
      end

      def initialize(store: Rails.cache, ttl: DEFAULT_TTL_SECONDS)
        @store = store
        @ttl = Integer(ttl)
        assert_capable_store!
      end

      def acquire(scope)
        assert_capable_store!
        token = SecureRandom.uuid
        key = cache_key(scope)
        written = store.write(
          key,
          token,
          unless_exist: true,
          expires_in: ttl,
          raw: true
        )
        if written
          Result.new(acquired: true, token: token, scope: scope)
        else
          Result.new(acquired: false, token: nil, scope: scope)
        end
      end

      def release(scope, token:)
        assert_capable_store!
        return false if token.nil?

        compare_and_delete(cache_key(scope), token.to_s)
      end

      private

      attr_reader :store, :ttl

      def cache_key(scope)
        "#{KEY_PREFIX}:#{scope}"
      end

      def assert_capable_store!
        case store
        when ActiveSupport::Cache::NullStore
          raise UnsupportedStoreError,
                "ActiveSupport::Cache::NullStore cannot satisfy Synchronization::Lease"
        when ActiveSupport::Cache::MemoryStore,
             ActiveSupport::Cache::RedisCacheStore
          nil
        else
          raise UnsupportedStoreError,
                "#{store.class} cannot satisfy Synchronization::Lease atomic acquire/release"
        end
      end

      def compare_and_delete(key, token)
        case store
        when ActiveSupport::Cache::MemoryStore
          memory_compare_and_delete(key, token)
        when ActiveSupport::Cache::RedisCacheStore
          redis_compare_and_delete(key, token)
        else
          raise UnsupportedStoreError, "#{store.class} cannot ownership-safe release"
        end
      end

      def memory_compare_and_delete(key, token)
        store.send(:synchronize) do
          current = store.read(key, raw: true)
          next false unless current == token

          store.delete(key)
          true
        end
      end

      def redis_compare_and_delete(key, token)
        normalized = store.send(:normalize_key, key, store.options)
        store.redis.then do |redis|
          deleted = redis.call("eval", COMPARE_AND_DELETE_LUA, 1, normalized, token)
          deleted.to_i.positive?
        end
      end
    end
  end
end
