require 'aws-sdk'
require 'optparse'
require 'yaml'

class PreConfiguration

  class << self

    def setup options
      @@profiles = Hash.new { |hash, key| hash[key] = {} }
      load_config_file
      load_profiles
      select_profile
      config_aws
      load_instances options
    end

    def instances
      @@instances
    end

   private

    def load_config_file
      begin
        @@config_file = File.open(Dir.home + '/.aws/config', 'r')
      rescue Errno::ENOENT => e
        puts "AWS config file doesn't exist. Create at ~/.aws/config"
        raise
      end
    end

    def load_profiles
      active_profile = ''
      @@config_file.readlines.each do |line|
        if /^\[(.*)\]$/.match line.strip
          active_profile = $1
        elsif /(\S+)(?:\s)*=(?:\s)*(\S+)/.match line.strip
          @@profiles[active_profile][$1.to_sym] = $2
        end
      end
    end

    def select_profile
      puts 'Available profiles: '
      @@profiles.keys.sort.each_with_index { |k, idx| puts "#{idx + 1}. #{k}" }

      profile_idx = nil
      begin
        print "Please choose a valid profile: "
        profile_idx = gets.chomp.to_i
      end until profile_idx.between? 1, @@profiles.size
      @@profile = @@profiles[@@profiles.keys.sort[profile_idx - 1]]
    end

    def config_aws
      AWS.config access_key_id:     @@profile[:aws_access_key_id],
                 secret_access_key: @@profile[:aws_secret_access_key],
                 region:            @@profile[:region]
    end

    def load_instances options
      begin
        @@instances = File.open(options[:instances], 'r').map do |l|
          l.strip.downcase unless l.empty? || l.nil?
        end
      rescue Errno::ENOENT
        abort "The specified instances file doesn't exist"
      end
    end
  end
end

class EC2Instance
  def initialize instance_id
    @aws_i = AWS.ec2.instances[instance_id]
  end

  def start
    @aws_i.start
    sleep 3 until @aws_i.status == :running
    puts "Instance #{@aws_i.tags['Name']} is running"
  end

  def stop
    if @aws_i.status == :stopped
      puts "Instance #{@aws_i.tags['Name']} was already stopped"
      return
    else
      @aws_i.stop
      sleep 3 until @aws_i.status == :stopped
      puts "Instance #{@aws_i.tags['Name']} stopped"
    end
  end

  def status
    puts "Instance #{@aws_i.tags['Name']} is #{@aws_i.status}"
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: script.rb [options]"

  opts.on('-i', '--instances INSTANCES_FILE', '=MANDATORY', 'File containing instances') { |v| options[:instances] = v }
  opts.on('--start',  'Start the instances') { |v| options[:start] = v }
  opts.on('--stop',   'Stop the instances') { |v| options[:stop]  = v }
  opts.on('--status', 'Retrieve the status of the instances')  { |v| options[:status]  = v }
end.parse!

if $0 == __FILE__
  raise OptionParser::MissingArgument, "--instances INSTANCES_FILE" if options[:instances].nil?
  raise OptionParser::MissingArgument, "--start OR --stop OR --status" if options[:start].nil? && options[:stop].nil? && options[:status].nil?
end


PreConfiguration.setup options

PreConfiguration.instances.each do |i_str|
  i = EC2Instance.new i_str
  if options[:start]
    i.start
  elsif options[:stop]
    i.stop
  elsif options[:status]
    i.status
  end
end