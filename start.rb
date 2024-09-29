system('dockercleanimages')
system("ruby build_children.rb #{ARGV[0]}")
system('ruby mother/mother.rb')
