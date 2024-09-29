# frozen_string_literal: true

require 'curses'
require 'docker'
require 'pry'
require 'forwardable'
require 'redis'
#require_relative 'windows/frame'
require_relative 'agent'
require_relative 'agent_ui'
require_relative 'windows/base'
require_relative 'agent_manager'

Dir.glob(File.join(__dir__, 'windows', '**', '*.rb')).sort.each do |file|
  require_relative file
end

AgentUI.new.run
