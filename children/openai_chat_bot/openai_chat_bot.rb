# openai_chat_bot.rb
begin
  require_relative 'nanny/nanny'

  LOG_PATH = '/app/logs/open_ai_chatbot_'

  class OpenAIChatBot < Nanny::NannyBot

    subscribe_to_channel ENV['CHANNEL_NAME'],
      types: ENV['EVENT_TYPES'].split(',').map(&:to_sym),
      callback: :process_event

    def initialize
      super

      tell_mother('Initializing OpenAI Chat Bot ...')
      @bot_brain = Nanny::BotBrain.new('openai_chat_bot', self)
      @new_response = nil
      tell_mother('All brained up')
    end

    private

    def preferences
      ''
    end

    def facts
      ''
    end

    def process_event(event)
      tell_mother('Processing event ...')

      system = <<~SYSTEM
        ASSISTANT: Emma
          * You are a personal assistant named 'Emma'.
          * You're a little funny, but you're not a comedian.
          * You're a little sarcastic, but you're not a jerk.
          * The user's name is Jason and he's an 50 year old software engineer, twice exceptional with giftedness and autism

      SYSTEM

      new_message = {'role' => 'user', 'content' => event['message']}

      response = chat(
        message: new_message,
        history: @bot_brain.conversation,
        functions: [
        ],
        return_functions: true,
        system: system,
        model: 'gpt-4o-mini'
      )

      tell_mother("Received message: #{event['message']}, Response: #{response}")

      @bot_brain.remember(new_message)
      @bot_brain.remember(response)

      unless event['message']['callback_channel'].nil?
        publish_callback(channel: event['message']['callback_channel'], message: response ? response['content'] : nil)
      else
        tell_mother("Publishing response: #{response['content']}") if response && response['content']
        publish_response(response['content']) if response && response['content']
      end
    end

    def process_news(response)
      @news_response = response

      response = chat(
        message: nil,
        history: @bot_brain.conversation,
        functions: [
          {name: 'html', description: 'Displays HTML to user.', parameters: html_parameters},
          {name: 'news', description: 'Retrieves news articles.', parameters: news_parameters}

        ],
        return_functions: true,
        system: system,
        model: 'gpt-4o-mini'
      )

      tell_mother("Function Response: #{response}")

      @bot_brain.remember(response)
    end

    def publish_callback(channel:, message:)
      tell_mother("Received message: #{message} from channel: #{channel}")
      publish(channel: channel, message: { type: :agent_input, agent: ENV['CHANNEL_NAME'], message: message}.to_json)
    end

    def publish_response(text)
      publish(channel: 'events', message: { type: :agent_input, agent: ENV['CHANNEL_NAME'], message: text}.to_json)
      publish(channel: 'aws_polly', message: { type: :agent_input, agent: ENV['CHANNEL_NAME'], message: text}.to_json)

      tell_mother("Published message: #{text}, Publish result.")

      text
    end
  end

  OpenAIChatBot.new.run
rescue => e
  Logger.new(LOG_PATH).error(e.message)
  Logger.new(LOG_PATH).error(e.backtrace.join("\n"))
  Logger.new(LOG_PATH).info("Rescue me please!, waiting ...")

  loop { sleep 100 }
end
