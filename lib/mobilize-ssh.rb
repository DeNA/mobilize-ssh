require "mobilize-ssh/version"
require "mobilize-base"
require "net/ssh"
require "net/ssh/gateway"
require "net/scp"
require "mobilize-ssh/extensions/net-ssh-connection-session"
require "mobilize-ssh/extensions/net-ssh-gateway"
require "mobilize-ssh/extensions/socket"

module Mobilize
  module Ssh
    def Ssh.home_dir
      File.expand_path('..',File.dirname(__FILE__))
    end
  end
end
require "mobilize-ssh/handlers/ssh"
require "mobilize-ssh/handlers/git"
