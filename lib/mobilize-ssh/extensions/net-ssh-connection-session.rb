class Net::SSH::Connection::Session
  def exec_w_err(command,except=true,errlog=nil)
    result = ["",""]
    f = File.open(errlog,"a") if errlog
    self.exec!(command) do |ch, stream, data|
      if stream == :stderr
        result[-1] += data
        f.print(data) if f
      else
        result[0] += data
      end
    end
    f.close if f
    if result.last.length>0
      if except
        raise result.last
      else
        return result
      end
    else
      return result.first
    end
  end
end
