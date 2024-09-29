# subscribe.rb
require 'redis'
require 'json'

module Nanny
  class Subscribe
    def initialize(nanny:, channel:, types:, &callback)
      @nanny = nanny
      @channel = channel
      @types = types
      @callback = callback
    end

    def start
      Thread.new do
        begin
          @nanny.logger.info("Subscribing to #{@channel} ...")
          @nanny.redis.subscribe(@channel.to_s) do |on|
            on.message do |_channel, message|
              begin
                @nanny.logger.info("Message Received: #{message[0..50]}")
                event = JSON.parse(message)
                @callback.call(event) if @types.include?(event['type'].to_sym)
              rescue => e
                @nanny.handle_error(e)
              end
            end
          end
        rescue => e
          @nanny.handle_error(e)
        end
      end
    end
  end
end
