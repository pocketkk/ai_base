# children/bot_builder_bot/bot_builder_bot.rb
require 'json'
require_relative 'nanny/nanny_bot'
require_relative 'build_container'

LOG_PATH = '/app/logs/bot_builder_bot'

class BotBuilderBot < Nanny::NannyBot
  BUILD_CHANNEL = 'builder_channel'

  subscribe_to_channel ENV['CHANNEL_NAME'],
    types: ENV['EVENT_TYPES'].split(',').map(&:to_sym),
    callback: :process_event

  private

  def process_event(event)
    tell_mother('Processing build event...')

    tell_mother("Event: #{event}")

    bot_code = event['bot_code']
    bot_name = event['bot_name']

    tell_mother("Bot name is #{bot_name}")
    tell_mother("Bot code is #{bot_code}")

    builder = BuildContainer.new(bot_code, bot_name)
    builder.build # Only builds the bot files, does not build Docker image

    tell_mother("Bot #{bot_name} built successfully. Requesting to start...")
    publish_response(bot_name)
  rescue => e
    tell_mother("Error building bot: #{e.message}, #{e.backtrace}")
  end

  def publish_response(response)
    tell_mother("Playing response: #{response}")

    result = publish(channel: 'agent_manager', message: { type: :agent_input, agent: ENV['CHANNEL_NAME'], message: "Start bot #{response}", start_bot: response }.to_json)

    tell_mother("Published message: #{response}, Publish result: #{result}")

    response
  end
end

BotBuilderBot.new.run
