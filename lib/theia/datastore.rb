# frozen_string_literal: true

require 'redis'

module Theia
  module DataStore
    @@redis = nil

    class << self
      def redis
        @@redis
      end

      def connect!(redis_url)
        @@redis = Redis.new url: redis_url
      end

      def user(user_id)
        user_id = user_id.id if user_id.respond_to?(:id)
        Theia::DataStore::User.new(user_id)
      end

      def server(server_id)
        server_id = server_id.id if server_id.respond_to?(:id)
        Theia::DataStore::Server.new(server_id)
      end
    end

    class DataStoreBase
      def redis_key!
        ["theia", redis_key]
          .flatten
          .map(&:to_s)
          .map(&:strip)
          .join(':')
      end

      def to_h
        Theia::DataStore.redis.hgetall(redis_key!).map do |k, v|
          [k.to_sym, v]
        end.to_h
      end

      def remove(key)
        val = self[key]
        Theia::DataStore.redis.hdel(redis_key!, key.to_s)
        val
      end

      def get(key, default=nil)
        if Theia::DataStore.redis.hexists(redis_key!, key.to_s)
          self[key]
        else
          default
        end
      end

      def [](key)
        Theia::DataStore.redis.hget(redis_key!, key.to_s)
      end

      def []=(key, value)
        Theia::DataStore.redis.hset(redis_key!, key.to_s, value.to_s)
      end
    end

    class User < DataStoreBase
      attr_reader :user_id

      def initialize(user_id)
        @user_id = user_id.to_s
      end

      def redis_key
        ["user.#{@user_id}"]
      end
    end

    class Server < DataStoreBase
      attr_reader :server_id

      def initialize(server_id)
        @server_id = server_id.to_s
      end

      def redis_key
        ["server.#{@server_id}"]
      end

      def channel(channel_id)
        channel_id = channel_id.id if channel_id.respond_to?(:id)
        Theia::DataStore::ServerChannel.new(@server_id, channel_id)
      end

      def user(user_id)
        user_id = user_id.id if user_id.respond_to?(:id)
        Theia::DataStore::ServerUser.new(@server_id, user_id)
      end

      def known_users
        Theia::DataStore.redis.keys([redis_key!, 'user.*'].join(':')).map do |key|
          user_id = /user.(\d+)$/.match(key)&.[](1)
          next nil unless user_id
          Theia::DataStore::ServerUser.new(@server_id, user_id)
        end.compact
      end
    end

    class ServerChannel < DataStoreBase
      attr_reader :server_id, :channel_id

      def initialize(server_id, channel_id)
        @server_id = server_id.to_s
        @channel_id = channel_id.to_s
      end

      def redis_key
        ["server.#{@server_id}", "channel.#{@channel_id}"]
      end
    end

    class ServerUser < DataStoreBase
      attr_reader :server_id, :user_id

      def initialize(server_id, user_id)
        @server_id = server_id.to_s
        @user_id = user_id.to_s
      end

      def redis_key
        ["server.#{@server_id}", "user.#{@user_id}"]
      end
    end
  end
end
