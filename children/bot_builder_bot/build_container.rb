# children/bot_builder_bot/build_container.rb
require 'fileutils'

class BuildContainer
  def initialize(new_bot_code, bot_name)
    @new_bot_code = new_bot_code
    @bot_name = bot_name
  end

  def build
    bot_dir = "/app/children/#{@bot_name}_bot"
    FileUtils.mkdir_p(bot_dir)

    # Write new bot code to appropriate files
    @new_bot_code.each do |filename, content|
      File.write("#{bot_dir}/#{filename}", content)
    end
  rescue => e
    puts "Error in building container: #{e.message}"
    raise e
  end
end
