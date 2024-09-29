require 'pg'
require 'redis'
require 'logger'
require_relative 'subscribe'
require_relative 'pg_client'
require_relative 'openai_chat_service'

module Nanny
  class ServiceNanny
    attr_reader :redis,
      :postgres,
      :logger,
      :options,
      :openai_chat_service

    def initialize(log_path:)
      @logger = Logger.new(STDOUT)

      @options = { log_path: log_path }
      @services = [:redis, :postgres, :openai_chat_service, :logger]
      @redis = initialize_redis
      @postgres = initialize_postgres
      @openai_chat_service = OpenAIChatService.new(ENV['OPENAI_API_KEY'])
      @logger = initialize_logger
    end

    def initialize_logger
      Logger.new(options[:log_path] + timestamp + '.log')
    end

    def timestamp
      Time.now.strftime('%Y%m%d')
    end

    def handle_error(error)
      raise error unless @logger

      @logger.error("Error: #{error}")
      @logger.error("Backtrace: #{error.backtrace.join("\n")}")

      raise error
    end

    OPEN_AI_MODELS = %w(
      gpt-4o-mini
      gpt-4o
      gpt-3.5-turbo-16k
      gpt-3.5-turbo
      gpt-4
    )

    LOCAL_MODELS = %w(
      ooga
    )

    def chat(
      message:,
      history: [],
      model: 'gpt-4o-mini',
      system: 'you are a helpful ai agent',
      functions: [],
      return_functions: false
    )

      tell_mother("I'm seeing this model:  #{model}")
      response = if OPEN_AI_MODELS.include?(model)
                   tell_mother("OpenAI Models chosen")
                   @openai_chat_service.chat(
                     message: message,
                     history: history,
                     model: model,
                     system: system,
                     functions: functions,
                     return_functions: return_functions
                   )
                 elsif LOCAL_MODELS.include?(model)
                   tell_mother("Local Models chosen")
                   @ooga_chat_service.chat(
                     message: message,
                     history: history,
                     return_functions: false,
                     system: system
                   )
                 end

      tell_mother("OpenAI: #{message}, Response: #{response}")

      response
    end

    def token_count(message)
      @openai_chat_service.token_count(message)
    end

    def save_message(message:, source:)
      @postgres.save_message(message: message, source: source)
    end

    def get_embedding(message)
      @openai_embedding_service.get_embedding(message)
    end

    def tell_mother(message)
      @logger.info(message) if @logger

      puts message
    end

    def subscribe(channel:, types:, &callback)
      Subscribe.new(nanny: self, channel: channel, types: types, &callback).start do |event|
        callback.call(event)
      end
    end

    def publish(channel:, message:)
      @redis.publish(channel, message)
    end

    def subscribe_and_wait(channel:, message:)
      @logger.info("Subscribe and wait #{channel} ...")
      @channel_name = SecureRandom.uuid

      Thread.new do
        @redis.subscribe(channel_name) do |on|
          on.message do |_channel, message|
            begin
              @nanny.logger.info("Message Received: #{message[0..50]}")
              @event = JSON.parse(message)

              yield(event) if block_given?
            rescue => e
              @nanny.handle_error(e)
            end
          end
        end
      end

      while @event.nil?
        sleep(0.1)
      end
    end

    private

    def initialize_redis
      Redis.new(host: 'redis_container', port: 6379)
    end

    def initialize_postgres
      PGClient.new('postgres_container', 'postgres', 'postgres', 'postgres')
    end

    def initialize_tables
      @logger.info('Initializing tables ...')

      unless @postgres.table_exists?('messages')
        @logger.info('Creating table: messages')
        table_name = 'messages'
        options_hash = {
          id: 'serial PRIMARY KEY',
          source: :string,
          content: :string,
          embeddings_id: :string,
          created_at: 'timestamp DEFAULT CURRENT_TIMESTAMP'
        }

        @postgres.create_table(table_name, options_hash)
      end
    end
  end

end
