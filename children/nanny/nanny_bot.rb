#nanny_bot.rb
require 'forwardable'
require_relative 'nanny'

module Nanny
  class NannyBot
    extend Forwardable

    class << self
      attr_accessor :subscription_channel, :subscription_types, :callback_method, :subscriptions
    end

    def_delegators :@nanny,
      :tell_mother,
      :chat,
      :token_count,
      :save_message,
      :publish,
      :subscribe,
      :subscribe_and_wait,
      :get_embedding,
      :handle_error,
      :weather_service

    def initialize
      @nanny = Nanny::ServiceNanny.new(log_path: LOG_PATH)

      tell_mother('Initializing ...')
    rescue => e
      puts "Error initializing ...#{e.backtrace}"
      @nanny.tell_mother("Error initializing ...#{e.backtrace}")
      @nanny.handle_error(e)
    end

    def self.subscribe_to_channel(channel, types: nil, callback: nil)
      message_types = types if types.is_a?(Array)
      message_types = [types] if types.is_a?(Symbol)

      self.subscriptions ||= []
      self.subscriptions << {channel: channel, types: message_types, callback: callback}
    end

    def run
      tell_mother('Starting up ...')
      subscribe_to_channels

      if ENV['PERSIST'] == 'true'
        loop { sleep 1 }
      end
    rescue => e
      handle_error(e)
    ensure
      tell_mother('Shutting down ...')
    end

    def subscribe_to_channels

      self.class.subscriptions.each do |subscription|
        tell_mother("Subscribing: #{subscription[:channel]}: #{subscription[:types]}")

        subscribe(channel: subscription[:channel], types: subscription[:types]) do |message|
          tell_mother("Received message: #{message}")
          send(subscription[:callback], message) if subscription[:callback]
        end
      end
    rescue => e
      handle_error(e)
    end
  end
end
