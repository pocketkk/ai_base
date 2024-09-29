# frozen_string_literal: true

require 'thread'

class Agent
  extend Forwardable

  attr_accessor :name,
                :messages,
                :previous_message,
                :row,
                :icon,
                :offset,
                :color,
                :container,
                :channel_name,
                :event_types,
                :image

  def initialize(name:, color: 1, channel_name: '', icon: '', event_types: [], container: nil, image: nil, ports: nil)
    @color = color
    @channel_name = channel_name
    @name = name
    @image = image || "#{name}_bot"
    @event_types = event_types
    @ports = ports
    @container = container || container_by_name
    @row = 0
    @offset = 0
    @messages = messages
    @previous_message = ''
    @icon = icon
    @build_path = "/path/to/#{name}_bot"  # Ensure the path to the bot’s directory is correct
  end


  def container_by_name

    host_config = {
      'NetworkMode' => 'agent_network',
      'Binds' => [
        '/home/pocketkk/ai/agents/swarm/logs:/app/logs',
        '/home/pocketkk/ai/agents/swarm/html:/app/html',
        '/home/pocketkk/ai/agents/swarm/history:/app/history',
        '/home/pocketkk/ai/agents/swarm/audio_in:/app/audio_in'
      ]
    }

    puts "Ports: #{@ports.inspect}"
    if @ports
      puts 'Setting PortBindings'
      host_config['PortBindings'] = { "#{@ports['container']}/tcp" => [{ 'HostPort' => "#{@ports['host']}" }] }
    end
    puts "Host Config after PortBindings: #{host_config.inspect}"

    @container ||= Docker::Container.create(
      'name' => "#{name}",
      'Cmd' => ['ruby', "#{name}_bot.rb"],
      'Image' => image,
      'Tty' => true,
      'Env' => [
        "OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}",
        "OPEN_WEATHER_API_KEY=#{ENV['OPEN_WEATHER_API_KEY']}",
        "ELEVEN_LABS_API_KEY=#{ENV['ELEVEN_LABS_API_KEY']}",
        "NEWS_API_KEY=#{ENV['NEWS_API_KEY']}",
        "CHANNEL_NAME=#{channel_name}",
        "EVENT_TYPES=#{event_types.join(',')}",
        "PERSIST=true"
      ],
      'HostConfig' =>  host_config
    )
  end

  def start(queue)
    container.start
    # Start a new thread that watches for new messages.
    Thread.new do
      loop do
        # Check for new message.
        if message != @previous_message
          @previous_message = message
          # Enqueue an event.
          queue.push({ type: :new_message, agent: self })
        end
        sleep 0.1
      end
    end
  end

  def raw_message
    logs(stdout: true, tail: 1)
  end

  def message
    raw_message.gsub("\0", '').gsub("\r\n", '').gsub(/\^A9/, '')
  end

  def bot_files_checksum
    files = Dir.glob(File.join(Dir.pwd, "#{name}_bot/**/*"))
    digests = files.map { |file| Digest::MD5.file(file).hexdigest }
    digests.join
  end

  def last_modified_time
    files = Dir.glob(File.join(Dir.pwd, "#{name}_bot/**/*"))
    files.map { |file| File.mtime(file) }.max
  end

  def_delegator :@container, :logs
end

