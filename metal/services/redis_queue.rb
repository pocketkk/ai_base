# redis_queue.rb
require 'redis'
require 'pry'
require 'json'

class RedisQueue
  def initialize
    @redis = Redis.new(host: '0.0.0.0', port: 6379)
  end

  def run(channel:, message:)
    @redis.publish(channel, content(message))
  end

  def content(message)
    {
      type: 'agent_input',
      agent: 'redis_queue',
      message: message
    }.to_json
  end
end

puts ARGV[0]
puts ARGV[1]
RedisQueue.new.run(channel: ARGV[0], message: ARGV[1])
