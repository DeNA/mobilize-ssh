class Net::SSH::Connection::Session
  #from http://stackoverflow.com/questions/3386233/how-to-get-exit-status-with-rubys-netssh-library
  def run(command)
    ssh = self
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
    response
  end
end
