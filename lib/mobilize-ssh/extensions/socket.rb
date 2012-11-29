class Socket
  def Socket.official_hostname
    begin
      Socket.gethostbyname(Socket.gethostname).first
    rescue
      Socket.gethostname
    end
  end

  def Socket.domain_name
    Socket.official_hostname.split(".")[-2..-1].join(".")
  end
end
