# frozen_string_literal: true

class InMemoryRedis
  def initialize
    @data = {}
  end

  def set(key, value, ex: nil, nx: false)
    purge(key)
    return false if nx && @data.key?(key)

    @data[key] = { value: value.to_s, expires_at: ex ? Time.now + ex : nil }
    nx ? true : "OK"
  end

  def get(key)
    purge(key)
    @data[key]&.fetch(:value)
  end

  def getdel(key)
    value = get(key)
    @data.delete(key)
    value
  end

  def del(*keys)
    keys.count { |key| purge(key) || !@data.delete(key).nil? }
  end

  def exists?(key)
    purge(key)
    @data.key?(key)
  end

  def ttl(key)
    purge(key)
    entry = @data[key]
    return -2 unless entry
    return -1 unless entry[:expires_at]

    (entry[:expires_at] - Time.now).ceil
  end

  def keys(_pattern = "*")
    @data.keys.each { |key| purge(key) }
    @data.keys
  end

  private

  def purge(key)
    entry = @data[key]
    @data.delete(key) if entry && entry[:expires_at] && entry[:expires_at] <= Time.now
    nil
  end
end

RSpec.configure do |config|
  config.before { Tokens::EmailConfirmation.redis = InMemoryRedis.new }
  config.after { Tokens::EmailConfirmation.redis = nil }
end
