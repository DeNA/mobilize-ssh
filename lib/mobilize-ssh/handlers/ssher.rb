module Mobilize
  module Ssher
    def Ssher.config
      Base.config('ssh')[Base.env]
    end

    def Ssher.tmp_file_dir
      dir = "#{Base.root}/tmp/ssher/"
      FileUtils.mkpath(tmp_file_folder)
      return dir
    end

    def Ssher.host(node)
      Ssher.config['nodes'][node]['host']
    end

    def Ssher.gateway(node)
      Ssher.config['nodes'][node]['gateway']
    end

    #determine if current machine is on host domain, needs gateway if one is provided and it is not
    def Ssher.needs_gateway?(node)
      host_domain_name = Ssher.host(node)['name'].split(".")[-2..-1].join(".")
      return true if Ssher.gateway(node) and Socket.domain_name == host_domain_name
    end

    def Ssher.read(node,path)
      Ssher.run(node,"cat #{path}")
    end

    def Ssher.write(node,data,to_path,binary=false)
      return Ssher.gate_write(node,data,to_path,binary) if Ssher.needs_gateway?(node)
      from_path = Ssher.tmp_file(data,binary)
      Ssher.scp(node,from_path,to_path)
      "rm #{from_path}".bash
      return true
    end

    def Ssher.scp(node,from_path,to_path)
      return Ssher.gate_scp(node,from_path,to_path) if Ssher.needs_gateway?(node)
      name,key,port,user = Ssher.host_params(node).ie{|h| ['name','key','port','user'].map{|k| h[k]}}
      opts = {:port=>(port || 22),:keys=>key}
      Net::SCP.start(name,user,opts) do |scp|
        scp.upload!(from_path,to_path,:recursive=>true)
      end
      return true
    end

    def Ssher.tmp_file(data,binary=false,fpath=nil)
      #creates a file under tmp/files with an md5 from the data
      tmp_file_path = fpath || "#{Ssher.tmp_file_dir}#{(data.to_s + Time.now.utc.to_f.to_s).to_md5}"
      write_mode = binary ? "wb" : "w"
      #make sure folder is created
      "mkdir -p #{tmp_file_path.split("/")[0..-2]}".bash
      #write data to path
      File.open(tmp_file_path,write_mode) {|f| f.print(data)}
      return tmp_file_path
    end

    def Ssher.run(node,command,except=true,su_user=nil,err_file=nil,*file_dst_ids)
      return Ssher.gate_run(node,command,except,err_log_path) if Ssher.needs_gateway?(node)
      name,key,port,user = Ssher.host_params(node).ie{|h| ['name','key','port','user'].map{|k| h[k]}}
      opts = {:port=>(port || 22),:keys=>key}
      su_user ||= user
      #make sure the dir for this command is clear
      comm_dir = "#{Ssher.tmp_file_dir}#{[su_user,node,command,file_dst_ids.to_s].join.to_md5}"
      "rm -rf #{comm_dir}".bash
      file_dst_ids.each do |fdi|
        fname = dst.name.split("/").last
        fpath = "#{comm_dir}/#{fname}"
        #for now, only gz is binary
        binary = fname.ends_with?(".gz") ? true : false
        #read data from cache, put it in a tmp_file
        data = dst.read_cache
        Ssher.tmp_file(data,binary,fpath)
      end
      Net::SSH.start(name,user,opts) do |ssh|
        return ssh.run(command,except,suuser,err_file,*file_dst_ids)
      end
      "rm -rf #{comm_dir}".bash
      true
    end
    def Ssher.gate_run(node,command,except=true,suuser=nil,err_file=nil,*file_dst_ids)
      gname,gkey,gport,guser = Ssher.gateway_params(gate_id).ie{|h| ['name','key','port','user'].map{|k| h[k]}}
      name,key,port,user = Ssher.host_params(node).ie{|h| ['name','keys','port','user'].map{|k| h[k]}}
      gopts = {:port=>(gport || 22),:keys=>gkey}
      opts = {:port=>(port || 22),:keys=>key}
      return Net::SSH::Gateway.sh(gname,guser,name,user,command,gopts,opts,except,err_log_path)
    end

    #Socket.gethostname is localhost
    def Ssher.gate_write(node,data,to_path,binary=false)
      gname,gkey,gport,guser = Ssher.gateway_params(gate_id).ie{|h| ['name','key','port','user'].map{|k| h[k]}}
      name,key,port,user = Ssher.host_params(node).ie{|h| ['name','keys','port','user'].map{|k| h[k]}}
      gopts = {:port=>(gport || 22),:keys=>gkey}
      opts = {:port=>(port || 22),:keys=>key}
      from_path = Ssher.tmp_file(data,binary)
      Net::SSH::Gateway.sync(gname,guser,from_path,to_path,name,gopts,{},opts,Socket.gethostname,ENV['LOGNAME'],user)
      "rm #{from_path}".bash
      return true
    end

    def Ssher.gate_scp(gateid,hostid,frompath,topath)
      gname,gkey,gport,guser = Ssher.gateway_params(gate_id).ie{|h| ['name','key','port','user'].map{|k| h[k]}}
      name,key,port,user = Ssher.host_params(node).ie{|h| ['name','keys','port','user'].map{|k| h[k]}}
      gopts = {:port=>(gport || 22),:keys=>gkey}
      opts = {:port=>(port || 22),:keys=>key}
      return Net::SSH::Gateway.sync(gname,guser,from_path,to_path,name,gopts,{},opts,Socket.gethostname,ENV['LOGNAME'],user)
    end
  end
end
