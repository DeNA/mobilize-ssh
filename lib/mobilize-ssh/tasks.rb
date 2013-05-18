require 'yaml'
namespace :mobilize do
  desc "Set up config and log folders and files"
  task :setup_ssh do
    sample_dir = File.dirname(__FILE__) + '/../samples/'
    sample_files = Dir.entries(sample_dir)
    config_dir = (ENV['MOBILIZE_CONFIG_DIR'] ||= "config/mobilize/")
    log_dir = (ENV['MOBILIZE_LOG_DIR'] ||= "log/")
    full_config_dir = "#{ENV['PWD']}/#{config_dir}"
    full_log_dir = "#{ENV['PWD']}/#{log_dir}"
    unless File.exists?(full_config_dir)
      puts "creating #{config_dir}"
      `mkdir -p #{full_config_dir}`
    end
    unless File.exists?(full_log_dir)
      puts "creating #{log_dir}"
      `mkdir -p #{full_log_dir}`
    end
    sample_files.each do |fname|
      unless File.exists?("#{full_config_dir}#{fname}")
        puts "creating #{config_dir}#{fname}"
        `cp #{sample_dir}#{fname} #{full_config_dir}#{fname}`
      end
    end
    #make sure that the jobtracker.yml is updated to include the
    #mobilize-ssh library
    jt_config_file = "#{config_dir}jobtracker.yml"
    if File.exists?(jt_config_file)
      yml_hash = YAML.load_file(jt_config_file)
      yml_hash.keys.each do |k|
        if yml_hash[k]['extensions'] and !yml_hash[k]['extensions'].include?('mobilize-ssh')
          puts "adding mobilize-ssh to jobtracker.yml/#{k}/extensions"
          yml_hash[k]['extensions'] = yml_hash[k]['extensions'].to_a + ['mobilize-ssh']
        end
      end
      File.open(jt_config_file,"w") {|f| f.print(yml_hash.to_yaml)}
    end
  end
end
