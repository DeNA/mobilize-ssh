class Socket
  def Socket.official_hostname
    Socket.gethostbyname(Socket.gethostname).first
  end

  def Socket.domain_name
    Socket.official_hostname.split(".")[-2..-1].join(".")
  end
end
