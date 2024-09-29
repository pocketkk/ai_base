#bot_brain.rb
require_relative 'nanny'

module Nanny
  class BotBrain
    def initialize(bot_id, bot)
      @bot_id = bot_id
      @bot = bot
      @history = []
    end

    def remember(entry)
      @history << entry

      # create file if it doesn't exist
      File.open("/app/history/#{@bot_id}/conversation.txt", 'w') unless File.exist?("/app/history/#{@bot_id}/conversation.txt")

      # append to history file /app/#{bot_id}.txt
      File.open("/app/history/#{@bot_id}/conversation.txt", 'a') { |f| f.write("#{entry}\n") }

      true
    rescue => e
      @bot.tell_mother("Error: #{e}")
      raise e
    end

    def persist_message(message, type)
      id = @bot.save_message(message: message, source: type)

      result = @bot.publish(
        channel: 'openai_embed',
        message: { type: type, postgres_id: id, message: message}.to_json
      )
      @bot.tell_mother("Persisted message: #{message}, Persist result: #{id}, #{result}")
    end

    def conversation
      @bot.tell_mother("Conversation: #{@history}")

      @history
    end
  end
end
