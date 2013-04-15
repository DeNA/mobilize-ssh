module Mobilize
  module Ssh
    def self.config
      Base.config('ssh')
    end

    def self.host(node)
      self.config['nodes'][node]['host']
    end

    def self.gateway(node)
      self.config['nodes'][node]['gateway']
    end

    def self.sudoers(node)
      self.config['nodes'][node]['sudoers']
    end

    def self.su_all_users(node)
      self.config['nodes'][node]['su_all_users']
    end

    def self.nodes
      self.config['nodes'].keys
    end

    def self.default_node
      self.nodes.first
    end

    #determine if current machine is on host domain, needs gateway if one is provided and it is not
    def self.needs_gateway?(node)
      host_domain_name = self.host(node)['name'].split(".")[-2..-1].join(".")
      return true if self.gateway(node) and Socket.domain_name != host_domain_name
    end

    def self.default_params
      time = Time.now.utc
      {
       '$utc_date'=>time.strftime("%Y-%m-%d"),
       '$utc_time'=>time.strftime("%H:%M"),
      }
    end
  end
end
