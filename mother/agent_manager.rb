#Emma/swarm/mother/agent_manager.rb
class AgentManager
  # Configure Docker read and write timeouts
  Docker.options[:read_timeout] = 500
  Docker.options[:write_timeout] = 500

  def initialize
    @logger = Logger.new('logs/agent_manager.log')
    @checksums = {}
    prepare_resources
    initialize_agents
  end
  def listen_for_agents
    @listening_agents = Thread.new do
      redis_client = Redis.new(host: '0.0.0.0', port: 6379)

      @logger.info("REDIS: #{redis_client}")
      redis_client.subscribe('agent_manager') do |on|
        on.message do |channel, message|
          @logger.info("Agent Manager received message: #{message}")

          event = JSON.parse(message)
          handle_agent_manager_event(event)
        end
      end
    end
  end
  def initialize_agents
    aws_polly = create_aws_polly_agent
    openai_chat = create_openai_chat_agent
    bot_builder = create_bot_builder_agent

    Thread.new { listen_for_agents }

    @agents = [openai_chat, aws_polly, bot_builder]

    @agents.each do |agent|
      @checksums[agent.name] = agent.bot_files_checksum
    end
  end

  def start_bot(bot_name)
    # Start the new bot through Agent initialization and start process
    @logger.info("Removing container with that name")
    Docker::Container.get(bot_name).delete rescue @logger.error("No container found for #{bot_name}")

    build_container(bot_name)

    @logger.info("Starting #{bot_name}...")

    agent = Agent.new(
      logger: @logger,
      name: bot_name,
      channel_name: bot_name,
      color: 2,
      icon: "\u{1F43A}",
      event_types: ['user_input', 'agent_input']
      )

    @logger.info("Agent Manager starting #{agent}")
    agent.start(@queue) if @queue
    add_agent(agent)
  rescue =>e
    @logger.error("Error while starting #{bot_name}: #{e}")
  end

  def build_container(bot_name)
    build_path = File.expand_path("~/ai_drive/Emma/swarm/children/#{bot_name}_bot")

    # Build the Docker image
    docker_build_cmd = "docker build -t #{bot_name} #{build_path} --no-cache"
    puts "Output of Docker Build: #{system(docker_build_cmd)}"
    if $?.success?
      puts "Built container for #{bot_name} at #{build_path}"
      @logger.info("Built container for #{bot_name} at #{build_path}")
    else
      error_message = "Failed to build container for #{bot_name} at #{build_path}"
      puts error_message
      @logger.error(error_message)
    end
  end

  def create_aws_polly_agent
    Agent.new(
      name: :aws_polly,
      color: 2,
      icon: "\u{1F60A}",
      channel_name: 'aws_polly',
      event_types: ['user_input', 'agent_input'],
      container: Docker::Container.create(
        'name' => 'aws_polly',
        'Cmd' => ['ruby', 'aws_polly_bot.rb'],
        'Image' => 'aws_polly_bot',
        'Tty' => true,
        'Env' => [
          "OPENAI_API_KEY=#{ENV['OPENAI_API_KEY']}",
          "OPEN_WEATHER_API_KEY=#{ENV['OPEN_WEATHER_API_KEY']}",
          "AWS_ACCESS_KEY_ID=#{ENV['AWS_ACCESS_KEY_ID']}",
          "AWS_SECRET_ACCESS_KEY=#{ENV['AWS_SECRET_ACCESS_KEY']}",
          "CHANNEL_NAME=aws_polly",
          "EVENT_TYPES=user_input,agent_input",
          "PERSIST=true",
          "PULSE_SERVER=unix:/tmp/.pulse-socket",
          "VOICE=Emma"
        ],
        'HostConfig' => {
          'NetworkMode' => 'agent_network',
          'Binds' => [
            '/home/pocketkk/ai_drive/Emma/swarm/logs:/app/logs',
            '/home/pocketkk/ai_drive/Emma/swarm/history:/app/history',
            '/home/pocketkk/ai_drive/Emma/swarm/audio_out:/app/audio_out',
            '/tmp/.pulse-socket:/tmp/.pulse-socket'
          ],
          'Devices' => [
            {
              'PathOnHost' => '/dev/snd',
              'PathInContainer' => '/dev/snd',
              'CgroupPermissions' => 'rwm'
            }
          ]
        }
      )
    )
  end

  def create_openai_chat_agent
    Agent.new(
      name: :openai_chat,
      color: 5,
      icon: "\u{1F916}",
      channel_name: 'openai_chat',
      event_types: ['user_input', 'agent_input']
    )
  end
  def create_bot_builder_agent
    Agent.new(
      name: :bot_builder,
      color: 3,
      icon: "\u{1F528}",
      channel_name: 'bot_builder',
      event_types: ['agent_input'],
      container: Docker::Container.create(
        'name' => 'bot_builder',
        'Cmd' => ['ruby', 'bot_builder_bot.rb'],
        'Image' => 'bot_builder_bot',
        'Tty' => true,
        'Env' => [
          "CHANNEL_NAME=bot_builder",
          "EVENT_TYPES=agent_input,new_bot_code",
          "PERSIST=true"
        ],
        'HostConfig' => {
          'NetworkMode' => 'agent_network',
          'Binds' => [
            '/home/pocketkk/ai_drive/Emma/swarm/logs:/app/logs',
            '/home/pocketkk/ai_drive/Emma/swarm/history:/app/history',
            '/home/pocketkk/ai_drive/Emma/swarm/children:/app/children'
          ]
        }
      )
    )
  end

  # Return a sorted list of agents and assign row numbers
  def agents
    @logger.info "agents: #{@agents}"

    problem = @agents.select { |agent| agent.name.nil? } 

    @logger.info "problem: #{problem}"

    sorted = @agents.sort { |a, b| a.name <=> b.name }
    sorted.map { |agent| agent.row = sorted.index(agent) + 1; agent }
  rescue => e
    @logger.error "Error in agents: #{e.backtrace}"
    @agents
  end

  # Add a new agent to the list
  def add_agent(agent)
    @agents << agent
  end

  # Get the max length of agent names for display alignment
  def max_name_length
    @agents.map { |agent| "#{agent.icon} #{agent.name}:".length }.max
  end

  # Start all agents and pass the queue to each
  def start_agents(queue)
    @queue = queue
    @agents.each { |agent| agent.start(queue) }
  end

  # Stop all agents and associated containers
  def stop_agents
    @agents.each { |agent| agent.container.stop }
    @redis.container.stop
    @postgres.container.stop
  end

  # Prepare resources by setting up necessary containers
  def prepare_resources
    # Stop and remove existing redis and postgres containers
    system('docker stop redis_container')
    system('docker rm redis_container')

    system('docker stop postgres_container')
    system('docker rm postgres_container')

    # Create and start redis container
    @redis = Agent.new(
      name: :redis_container,
      container: Docker::Container.create(
        'name' => 'redis_container',
        'Cmd' => ['redis-server', '--appendonly', 'yes'],
        'Image' => 'redis',
        'Tty' => true,
        'ExposedPorts' => { '6379/tcp' => {} },
        'HostConfig' => {
          'PortBindings' => { '6379/tcp' => [{ 'HostPort' => '6379' }] },
          'NetworkMode' => 'agent_network'
        }
      )
    )

    # Create and start postgres container
    @postgres = Agent.new(
      name: :postgres_container,
      container: Docker::Container.create(
        'name' => 'postgres_container',
        'Cmd' => ['postgres'],
        'Image' => 'postgres',
        'Tty' => true,
        'ExposedPorts' => { '5432/tcp' => {} },
        'Env' => [
          'POSTGRES_PASSWORD=postgres',
          'POSTGRES_USER=postgres'
        ],
        'HostConfig' => {
          'PortBindings' => { '5432/tcp' => [{ 'HostPort' => '5432' }] },
          'NetworkMode' => 'agent_network',
          'Binds' => ['/home/pocketkk/ai/agents/swarm/postgres_data:/var/lib/postgresql/data']
        }
      )
    )

    @postgres.container.start
    @redis.container.start

    # Stop and remove existing agent containers
    %w(openai_chat aws_polly bot_builder).each do |agent_name|
      system("docker stop #{agent_name}")
      system("docker rm #{agent_name}")
    end
  end

  def rebuild_container(agent)
    image_name = agent.image
    Docker::Image.build_from_dir("children/#{agent.name}_bot", { 't' => image_name }) do |v|
      json = JSON.parse(v) rescue {}
      if json.key?('stream')
        @logger.info(json['stream'])
      elsif json.key?('error')
        @logger.error(json['error'])
      else
        @logger.info(v.strip)
      end
    end
  end

  def rebuild_if_changed(agent)
    current_checksum = agent.bot_files_checksum
    @logger.info("Current checksum for #{agent.name}: #{current_checksum}")
    if @checksums[agent.name] != current_checksum
      @logger.info("Changes detected for #{agent.name}. Rebuilding container...")
      rebuild_container(agent)
      @checksums[agent.name] = current_checksum
      @logger.info("Rebuild complete for #{agent.name}.")
    else
      @logger.info("No changes detected for #{agent.name}. Skipping rebuild.")
    end
  end

  def rebuild_if_changed(agent)
    current_checksum = agent.bot_files_checksum
    @logger.info("Current checksum for #{agent.name}: #{current_checksum}")
    @logger.info("Forcing rebuild for testing purposes...")
    rebuild_container(agent)
    @checksums[agent.name] = current_checksum
    @logger.info("Rebuild complete for #{agent.name}.")
  end

  def handle_agent_manager_event(event)
    unless event['start_bot'].nil?
      @logger.info("Starting #{event['start_bot']}")

      start_bot(event['start_bot'])
    end
  end
end
