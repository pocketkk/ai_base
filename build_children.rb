require 'find'
require 'time'

CHANGELOG_PATH = "/home/pocketkk/ai_drive/Emma/swarm/logs/last_start_run.txt"

def read_last_update_time
  if File.exist?(CHANGELOG_PATH)
    Time.parse(File.read(CHANGELOG_PATH))
  else
    Time.at(0) # return Unix epoch if the file doesn't exist
  end
end

def write_last_update_time(time)
  File.write(CHANGELOG_PATH, time.to_s)
end

def nanny_changed?(last_update_time)
  nanny_dir = File.expand_path("~/ai_drive/Emma/swarm/nanny")
  last_modified = Dir.glob("#{nanny_dir}/**/*").map { |f| File.mtime(f) }.max
  puts "nanny_changed? #{last_update_time} #{last_modified} #{nanny_dir}"
  puts "last modified: #{last_modified}"
  last_modified > last_update_time
end

def build_containers(path, last_update_time)
  Find.find(path) do |dir|
    next if dir =~ /\/\.git/ # Skip .git directories
    next if dir =~ /\/nanny/ # Skip copied nanny directories

    if File.directory?(dir)
      # If no file in the directory was modified since the last update, skip this directory
      last_modified = Dir.glob("#{dir}/**/*").map { |f| File.mtime(f) }.max || Time.now
      next if last_modified < last_update_time && !nanny_changed?(last_update_time)

      if nanny_changed?(last_update_time)
        rm = "rm -rf #{dir}/nanny"
        puts "Dir.chdir(#{dir})  #{rm}"
        puts "Running #{system(rm)}"

        cp = "cp -r ~/ai_drive/Emma/swarm/nanny #{dir}/nanny"

        puts "Running #{system(cp)}"
      end

      container_name = File.basename(dir)

      docker_build_cmd = "docker build -t #{container_name} #{dir} --no-cache"
      puts "Output of Docker Build: #{system(docker_build_cmd)}"
      puts "Built container for #{container_name} at #{dir}"
    end
  end
end

# Specify the folders to recursively build containers
folders = [
  "~/ai_drive/Emma/swarm/children/"
]

system("dstopall")
system("dremoveall")

last_update_time = read_last_update_time()

folders.each do |folder|
  expanded_path = File.expand_path(folder)
  build_containers(expanded_path, last_update_time)
end

write_last_update_time(Time.now)