class Net::SSH::Connection::Session
  def run(command)
    stdout,stderr = ["",""]
    self.exec!(command) do |ch, stream, data|
      if stream == :stderr
        stderr += data
      else
        stdout += data
      end
    end
    raise stderr if stderr.length>0
    return stdout
  end
end
