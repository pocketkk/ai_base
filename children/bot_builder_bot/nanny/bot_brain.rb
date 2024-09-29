#bot_brain.rb
require_relative 'nanny'
require 'fileutils'

module Nanny
  class BotBrain
    def initialize(bot_id, bot)
      @bot_id = bot_id
      @bot = bot
      @history = []
      ensure_history_directory
    end

    def ensure_history_directory
      history_dir = "/app/history/#{@bot_id}"
      FileUtils.mkdir_p(history_dir) unless Dir.exist?(history_dir)
    end

    def remember(entry)
      @history << entry

      # create file if it doesn't exist
      ensure_history_directory
      history_file = "/app/history/#{@bot_id}/conversation.txt"
      File.open(history_file, 'w') unless File.exist?(history_file)

      # append to history file
      File.open(history_file, 'a') { |f| f.write("#{entry}\n") }

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
