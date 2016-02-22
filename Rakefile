desc "setup ctf symlink"
task :ctf_symlink do
  puts "adding ctf symlink to /usr/local/bin..."
  current_dir = Dir.pwd
  ctf_path = current_dir + '/ctf.rb'
  `ln -s #{ctf_path} /usr/local/bin/ctf`
  puts 'Done!'
end
