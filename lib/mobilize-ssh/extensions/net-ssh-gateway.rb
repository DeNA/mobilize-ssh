class Net::SSH::Gateway
  def self.run(gname,guser,name,user,command,gopts={},opts={})
    gate = self
    gateway = gate.new(gname,guser,gopts)
    response = nil
    gateway.ssh(name,user,opts) do |ssh|
      #from http://stackoverflow.com/questions/3386233/how-to-get-exit-status-with-rubys-netssh-library
      stdout_data = ""
      stderr_data = ""
      exit_code = nil
      exit_signal = nil
      ssh.open_channel do |channel|
        channel.exec(command) do |chan, success|
          unless success
            abort "FAILED: couldn't execute command (ssh.channel.exec)"
          end
          channel.on_data do |ch,data|
            stdout_data+=data
          end

          channel.on_extended_data do |ch,type,data|
            stderr_data+=data
          end

          channel.on_request("exit-status") do |ch,data|
            exit_code = data.read_long
          end

          channel.on_request("exit-signal") do |ch, data|
            exit_signal = data.read_long
          end
        end
      end
      ssh.loop
      response = {'stdout'=>stdout_data, 'stderr'=>stderr_data, 'exit_code'=>exit_code, 'exit_signal'=>exit_signal}
    end
    response
  end
  def self.sync(gname,guser,name,user,from_path,to_path,gopts={},opts={})
    gateway = self.new(gname,guser,gopts)
    gateway.scp(name,user,opts) do |scp|
      scp.upload!(from_path,to_path,:recursive=>true)
    end
    return true
  end
  #allow scp through gateway
  def scp(name, user, opts={}, &block)
    local_port = open(name, opts[:port] || 22)
    begin
      Net::SCP.start("127.0.0.1", user, opts.merge(:port => local_port), &block)
    ensure
      close(local_port) if block || $!
    end
  end
end
