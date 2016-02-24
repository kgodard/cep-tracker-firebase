desc "setup ctf stuff"
task :ctf_setup do
  current_dir = Dir.pwd
  ctf_path = current_dir + '/ctf.rb'
  unless File.exists?('/usr/local/bin/ctf')
    puts "adding ctf symlink to /usr/local/bin..."
    `ln -s #{ctf_path} /usr/local/bin/ctf`
  end

  if `grep CTF_DIR ~/.bash_profile`.empty?
    puts "adding CTF_DIR to .bash_profile..."
    `echo 'export CTF_DIR="#{current_dir}"' >> ~/.bash_profile`

    puts "reloading .bash_profile..."
    `source ~/.bash_profile`
  end

  puts 'Done!'
end
