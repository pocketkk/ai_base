# openai_service.rb
require 'net/http'
require 'uri'
require 'json'
# require 'tiktoken_ruby'

module Nanny
  class OpenAIChatService
    API_ENDPOINT = 'https://api.openai.com/v1/chat/completions'
    MODEL = 'gpt-3.5-turbo'
    CONTENT_TYPE = 'application/json'

    def initialize(api_key)
      @api_key = api_key
    end

    def system_instructions
      "You are an AI assistant.  You are friendly, helfpul, and creative."
    end

    def chat(message: nil, history: [], model: MODEL, system: system_instructions, functions: [], return_functions: false)
      #@message['content'] = message['content'].gsub(/jarvis/i, '') unless message.nil?

      @message = message
      @system = system
      @functions = functions
      @history = history
      @model = model
      uri = URI(API_ENDPOINT)
      request = create_request(uri, message)
      response = send_request(uri, request)

      parse(response)
    end

    def token_count(message)
      enc = Tiktoken.get_encoding("cl100k_base")
      enc.encode(message).length
    end

    private

    attr_reader :history, :message, :model, :functions

    def messages
      system_message +  history + current_message
    end

    def system_message
      [{ 'role' => 'system', 'content' => @system }]
    end

    def current_message
      return [] unless message

      [message]
    end

    def create_request(uri, message)
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{@api_key}"
      request['Content-Type'] = CONTENT_TYPE
      request.body = JSON.dump({
        'model' => model,
        'messages' => messages,
        'tools' => functions,
        'temperature' => 0.5,
        'max_tokens'=> 500,
      })

      request
    end

    def send_request(uri, request)
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(request)
      end
    end

    def parse(response)
      json_response = JSON.parse(response.body)
      choices = json_response['choices']
      choices&.first&.dig('message')
    end
  end
end
