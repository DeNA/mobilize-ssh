class Net::SSH::Gateway
  def self.sh(gname,guser,name,user,command,gopts={},hopts={},except=true,err_log_path=nil)
    f = File.open(err_log_path,"a") if err_log_path
    gateway = self.new(gname,guser,gopts)
    gateway.ssh(name,user,opts) do |ssh|
      result = ["",""]
      ssh.exec!(command) do |ch, stream, data|
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
  def self.sync(gname,guser,name,user,from_path,to_path,gopts={},opts={})
    gateway = self.new(ghost,guser,gopts)
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
