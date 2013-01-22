################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2013 Atalanta Systems Ltd
#     License: Apache License, Version 2.0
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
################################################################################

module Cucumber::Chef::Helpers::ChefClient

################################################################################

  # call this in a Before hook
  def chef_set_client_config(config={})
    @chef_client_config = (@chef_client_config || {
      :log_level => :info,
      :log_location => "/var/log/chef/client.log",
      :chef_server_url => "https://api.opscode.com/organizations/#{config[:orgname]}",
      :validation_client_name => "#{config[:orgname]}-validator",
      :ssl_verify_mode => :verify_none,
      :environment => nil # use default; i.e. set no value
    }).merge(config)
    log("setting chef client config $#{@chef_client_config.inspect}$")

    true
  end

################################################################################

  # call this before chef_run_client
  def chef_set_client_attributes(name, attributes={})
    @servers[name] ||= Hash.new
    @servers[name][:chef_client] = (@servers[name][:chef_client] || {}).merge(attributes) { |k,o,n| (k = (o + n).uniq) }
    log("setting chef client attributes to $#{@servers[name][:chef_client].inspect}$ for container $#{name}$")

    true
  end

################################################################################

  def chef_run_client(name,*args)
    chef_config_client(name)
    artifacts =
    log("removing artifacts #{Cucumber::Chef::Config[:artifacts].values.collect{|z| "$#{z}$" }.join(' ')}")
    (command_run_remote(name, "/bin/rm -fv #{Cucumber::Chef::Config[:artifacts].values.join(' ')}") rescue nil)

    log("running chef client on container $#{name}$")

    output = nil
    bm = ::Benchmark.realtime do
      output = command_run_remote(name, ["/usr/bin/chef-client --json-attributes /etc/chef/attributes.json --node-name #{name}", args].flatten.join(" "))
    end
    log("chef client run on container $#{name}$ took %0.4f seconds" % bm)

    output
  end

################################################################################

  def chef_config_client(name)
    # make sure our configuration location is there
    client_rb = File.join("/", container_root(name), "etc/chef/client.rb")
    FileUtils.mkdir_p(File.dirname(client_rb))

    max_key_size = @chef_client_config.keys.collect{ |z| z.to_s.size }.max

    File.open(client_rb, 'w') do |f|
      f.puts(Cucumber::Chef.generate_do_not_edit_warning("Chef Client Configuration"))
      f.puts
      @chef_client_config.merge(:node_name => name).each do |(key,value)|
        next if value.nil?
        f.puts("%-#{max_key_size}s  %s" % [key, value.inspect])
      end
      f.puts
      f.puts("Mixlib::Log::Formatter.show_time = true")
    end

    attributes_json = File.join("/", container_root(name), "etc", "chef", "attributes.json")
    FileUtils.mkdir_p(File.dirname(attributes_json))
    File.open(attributes_json, 'w') do |f|
      f.puts((@servers[name][:chef_client] || {}).to_json)
    end

    # make sure our log location is there
    log_location = File.join("/", container_root(name), @chef_client_config[:log_location])
    FileUtils.mkdir_p(File.dirname(log_location))

    command_run_local("cp /etc/chef/validation.pem #{container_root(name)}/etc/chef/ 2>&1")

    true
  end

################################################################################

  def chef_client_artifacts(name)
    # this is messy and needs to be refactored into a more configurable
    # solution; but for now this should do the trick

    ssh_private_key_file = Cucumber::Chef.locate(:file, ".cucumber-chef", "id_rsa-#{Cucumber::Chef::Config[:lab_user]}")
    File.chmod(0400, ssh_private_key_file)

    ssh = ZTK::SSH.new

    ssh.config.proxy_host_name = $test_lab.public_ip
    ssh.config.proxy_user = Cucumber::Chef::Config[:lab_user]
    ssh.config.proxy_keys = ssh_private_key_file

    ssh.config.host_name = name
    ssh.config.user = Cucumber::Chef::Config[:lxc_user]
    ssh.config.keys = ssh_private_key_file

    feature_file = $scenario.file_colon_line.split(":").first
    feature_line = $scenario.file_colon_line.split(":").last
    scenario_tag = $scenario.name.gsub(" ", "_")

    feature_name = File.basename(feature_file, ".feature")
    feature_dir = feature_file.split("/")[-2]

    Cucumber::Chef::Config[:artifacts].each do |label, remote_path|
      result = ssh.exec("/bin/bash -c '[[ -f #{remote_path} ]] ; echo $?'", :silence => true)
      if (result.output =~ /0/)
        log("retrieving artifact $#{remote_path}$ from container $#{name}$")

        local_path = File.join(Cucumber::Chef.locate(:directory, ".cucumber-chef"), "artifacts", feature_dir, "#{feature_name}.txt")
        tmp_path = File.join("/tmp", label)

        FileUtils.mkdir_p(File.dirname(local_path))
        ssh.download(remote_path, tmp_path)
        data = IO.read(tmp_path).chomp

        message = "#{$scenario.name} (#{File.basename(feature_file)}:#{feature_line}:#{label})"
        header = ("-" * message.length)

        f = File.open(local_path, "a")
        f.write("#{header}\n")
        f.write("#{message}\n")
        f.write("#{header}\n")
        f.write("#{data}\n")

        File.chmod(0644, local_path)
      end
    end

    true
  end

################################################################################

end

################################################################################
