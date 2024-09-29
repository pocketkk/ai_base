# aws_polly_bot.rb
begin
  require_relative 'nanny/nanny'
  require 'open3'
  require 'aws-sdk-polly'

  LOG_PATH = '/app/logs/aws_polly_'

  class AwsPollyService
    def initialize(nanny)
      @nanny = nanny
      @polly = Aws::Polly::Client.new(region: 'us-west-2')
    end

    def convert_text_to_speech(text, voice='Kimberly')
      response = @polly.synthesize_speech({
        output_format: "mp3",
        engine: "neural", # standard | neural
        text: text,
        text_type: "text",
        voice_id: voice
      })


      @nanny.tell_mother("Response - TEST: #{response}")


      # Added comment
      # Create the directory if it doesn't exist
      Dir.mkdir('/app/audio_out') unless File.exists?('/app/audio_out')

      if response && response.audio_stream
        output_filename = "/app/audio_out/output_#{Time.now.strftime('%Y%m%d%H%M%S')}.mp3"

        IO.copy_stream(response.audio_stream, output_filename)

        'Audio saved.'
      else
        @nanny.tell_mother("Error: #{response&.code} - #{response&.message}")
        'Error converting text to speech.'
      end

    end
  end

  class AwsPollyBot < Nanny::NannyBot

    subscribe_to_channel ENV['CHANNEL_NAME'],
      types: ENV['EVENT_TYPES'].split(',').map(&:to_sym),
      callback: :process_event

    private

    def process_event(event)
      tell_mother('Processing event ...')

      text = event['message']
      voice = event['voice'] || ENV['VOICE']

      tell_mother("Text to speech: #{text}")

      response = AwsPollyService.new(@nanny).convert_text_to_speech(text, voice)
      publish_response(response)
    rescue => e
      tell_mother("Error: #{e.backtrace.join("\n")}")
      tell_mother("Error: #{e.message}")
    end

    def publish_response(response)
      tell_mother("Playing response: #{response}")

      result = publish(channel: 'events', message: { type: :agent_input, agent: ENV['CHANNEL_NAME'], message: response }.to_json)

      tell_mother("Published message: #{response}, Publish result: #{result}")

      response
    end
  end

  AwsPollyBot.new.run
rescue => e
  Logger.new(LOG_PATH).error(e.message)
  Logger.new(LOG_PATH).error(e.backtrace.join("\n"))
  Logger.new(LOG_PATH).info("Rescue me please!, waiting ...")

  loop { sleep 100 }
end
