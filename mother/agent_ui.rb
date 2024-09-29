# frozen_string_literal: true
require 'open3'
require 'thread'
require 'ruby-audio'

require_relative 'windows/manager'

class AgentUI
  def initialize
    @queue = Queue.new
    @agent_manager = AgentManager.new
    @window_manager = Windows::Manager.new(@agent_manager.agents.count)
    @listening_thread = nil
    @listening_agents = nil
    @logger = Logger.new('logs/agent_ui.log')
    @redis = Redis.new(host: '0.0.0.0', port: 6379)
  end

  def run
    agent_manager.start_agents(@queue)

    listen_to_user_input
    listen_to_agents

    sleep 2

    Thread.new { play_audio }

    loop do
      event = @queue.pop # This will block until there is an event.
      break if event == 'exit'

      process_event(event)
    end

    shutdown
  ensure
    shutdown
  end

  def play_audio
    require 'fileutils'

    watch_folder = "audio_out"
    played_folder = "audio_out/played"

    # Create played_folder if it doesn't exist
    Dir.mkdir(played_folder) unless File.exist?(played_folder)

    while true
      Dir.entries(watch_folder).each do |file|
        next if File.directory?(file)

        if file.match(/\.(mp3|wav)$/)
          full_path = File.join(watch_folder, file)

          # Determine the appropriate player
          if file.match(/\.mp3$/)
            system("mpg123 '#{full_path}' > /dev/null 2>&1")
          elsif file.match(/\.wav$/)
            system("aplay '#{full_path}' > /dev/null 2>&1")
          end

          # Move the file to the played folder
          FileUtils.mv(full_path, File.join(played_folder, file))
        end
      end

      sleep 1 # Wait 1 second before checking again
    end
  end

  def shutdown
    @listening_thread.exit if @listening_thread
    @listening_agents.exit if @listening_agents

    agent_manager.stop_agents

    Curses.close_screen
  end

  def icon_for_agent(agent)
    return '🤖' if agent == 'mother'
    agent_name = agent.is_a?(Agent) ? agent.name : agent

    logger.info("Looking for icon for agent: #{agent_name}")
    found_agent = agent_manager.agents.select { |a| a.name.to_s == agent_name }.first

    return agent unless found_agent

    found_agent.icon
  end

  def color_for_agent(agent)
    return 2 if agent == 'mother'
    agent_name = agent.is_a?(Agent) ? agent.name : agent

    logger.info("Looking for color for agent: #{agent_name}")
    found_agent = agent_manager.agents.select { |a| a.name.to_s == agent_name }.first

    return 1 unless found_agent

    found_agent.color
  end

  def listen_to_user_input
    @redis.publish('openai_chat', { type: :agent_input, agent: 'mother', message: "System Message: Boot up complete.  AI online.  Say hello (don't introduce yourself) and something to inspire :)" }.to_json)

    @listening_thread = Thread.new do
      loop do
        user_input = window_manager.get_input
        if user_input == '/exit'
          @logger.info('User requested exit')
          @queue.push('exit')
          break
        end

        @logger.info('User Input: ' + user_input.inspect)

        if user_input.start_with?("/say ")
          @redis.publish('aws_polly', { type: :user_input, agent: 'mother', message: user_input.split('/say ')[-1] }.to_json)
        elsif user_input == "/pd"
          window_manager.scroll_down(50)
        elsif user_input == "/pu"
          window_manager.scroll_up(50)
        elsif user_input.start_with?("/stop ")
          agent_name = user_input.split('/stop ')[-1]
          process_stop_command(agent_name)
        elsif user_input.start_with?("/restart ")
          agent_name = user_input.split('/restart ')[-1]
          process_restart_command(agent_name)
        elsif user_input.start_with?("/start ")
          agent_name = user_input.split('/start ')[-1]
          process_start_command(agent_name)
        elsif user_input.start_with?("/create_hello_bot")
          create_hello_bot
        else
          @redis.publish('openai_chat', { type: :user_input, agent: 'mother', message: user_input}.to_json)
        end

        window_manager.agents_count = agent_manager.agents.count

        @queue.push({ type: :user_input, agent: 'mother', message: user_input })
      end
    end
  end

  def process_stop_command(agent_name)
    found_agent = find_agent(agent_name)
    if found_agent
      found_agent.container.stop
      @redis.publish('aws_polly', { type: :user_input, agent: 'mother', message: "Stopping #{agent_name} agent." }.to_json)
    else
      @redis.publish('aws_polly', { type: :user_input, agent: 'mother', message: "#{agent_name} agent not found." }.to_json)
    end
  end

  def process_start_command(agent_name)
    found_agent = find_agent(agent_name)
    if found_agent
      @agent_manager.rebuild_if_changed(found_agent)
      found_agent.container.start
      @redis.publish('aws_polly', { type: :user_input, agent: 'mother', message: "Starting #{agent_name} agent." }.to_json)
    else
      @redis.publish('aws_polly', { type: :user_input, agent: 'mother', message: "#{agent_name} agent not found." }.to_json)
    end
  end

  def process_restart_command(agent_name)
    found_agent = find_agent(agent_name)
    if found_agent
      found_agent.container.stop
      @agent_manager.rebuild_if_changed(found_agent)
      found_agent.container.start
      @redis.publish('aws_polly', { type: :user_input, agent: 'mother', message: "Restarting #{agent_name} agent." }.to_json)
    else
      @redis.publish('aws_polly', { type: :user_input, agent: 'mother', message: "#{agent_name} agent not found." }.to_json)
    end
  end

  def find_agent(agent_name)
    @agent_manager.agents.find { |a| a.name.to_s == agent_name }
  end

  def listen_to_agents
    @listening_agents = Thread.new do
      redis_client = Redis.new(host: '0.0.0.0', port: 6379)

      logger.info("REDIS: #{redis_client}")
      redis_client.subscribe('events') do |on|
        on.message do |channel, message|
          event = JSON.parse(message)
          unless ['user_input', 'new_user_embedding', 'new_agent_embedding'].include?(event['type'])
            @queue.push({ type: :agent_input, agent: event['agent'], message: event['message'] })
          end
        end
      end
    end
  end

  def create_hello_bot
    hello_bot_code = {
      "Dockerfile" => <<~DOCKERFILE,
        FROM ruby:3.0.2
        WORKDIR /app
        COPY . .
        RUN bundle install
        CMD ["ruby", "hello_bot.rb"]
      DOCKERFILE
      
      "Gemfile" => <<~GEMFILE,
        source 'https://rubygems.org'
        gem 'json'
        gem 'redis'
        gem 'pg'
      GEMFILE
      
      "hello_bot.rb" => <<~HELLOBOT
        require 'json'
        require 'redis'
        require 'pg'

        def main
          puts "Hello, World! This is a new bot."
        end

        main
      HELLOBOT
    }

    bot_event = {
      type: 'agent_input',
      message: 'create hello-bot',
      bot_name: 'hello',
      bot_code: hello_bot_code
    }
    @redis.publish('bot_builder', bot_event.to_json)

    @logger.info('Triggered BuilderBot to create and start the Hello World bot.')
  end

  def process_event(event)
    return if event == 'exit' # Don't process if 'exit'

    case event[:type]
    when :new_message
      logger.info("New message: #{event[:message]}")
      refresh_agent_message(event[:agent])
    when :user_input
      logger.info("User input: #{event[:message]}")
      window_manager.write_to_chat_window("User: #{event[:message]}")
    when :agent_input
      logger.info("Agent input: #{event[:message]}")
      window_manager.write_to_chat_window("Agent: (#{icon_for_agent(event[:agent])}): #{event[:message]}", color_for_agent(event[:agent]))
    end
    window_manager.refresh!
  end

  def refresh_agent_message(agent)
    max_name_length = agent_manager.max_name_length
    padded_name = "#{agent.icon} #{agent.name.upcase}:".ljust(max_name_length).force_encoding('UTF-8')

    window_width = window_manager.agents_window.maxx - 2
    message_space = window_width - max_name_length - 4 # magic number
    trimmed_message = agent.message[0, message_space].force_encoding('UTF-8')

    window_manager.agents_window.attrset(Curses.color_pair(agent.color))  # Set color here
    window_manager.agents_window.setpos(window_manager.inset_y + agent.row, window_manager.inset_x - 2)
    window_manager.agents_window.addstr(" " * message_space)
    window_manager.agents_window.setpos(window_manager.inset_y + agent.row, window_manager.inset_x - 2)
    window_manager.agents_window.addstr("#{padded_name} #{trimmed_message}")
    window_manager.agents_window.attrset(Curses::A_NORMAL)  # Reset color
  end

  private

  attr_reader :window_manager, :agent_manager, :listening_thread, :logger
end
