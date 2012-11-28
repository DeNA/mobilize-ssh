module Mobilize
  module Ssher
    def Ssher.config
      Base.config('ssh')[Base.env]
    end

    def Ssher.tmp_file_dir
      dir = "#{Base.root}/tmp/ssher/"
      "mkdir -p #{dir}".bash
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

    def Ssher.pop_comm_dir(comm_dir,file_hash)
      "rm -rf #{comm_dir}".bash
      file_hash.each do |fname,fdata|
        fpath = "#{comm_dir}/#{fname}"
        #for now, only gz is binary
        binary = fname.ends_with?(".gz") ? true : false
        #read data from cache, put it in a tmp_file
        Ssher.tmp_file(fdata,binary,fpath)
      end
      return true if file_hash.keys.length>0
    end

    def Ssher.scp(node,from_path,to_path)
      name,key,port,user = Ssher.host(node).ie{|h| ['name','key','port','user'].map{|k| h[k]}}
      key_path = "#{Base.root}/config/#{key}"
      opts = {:port=>(port || 22),:keys=>key_path}
      if Ssher.needs_gateway?(node)
        gname,gkey,gport,guser = Ssher.gateway(node).ie{|h| ['name','key','port','user'].map{|k| h[k]}}
        gkey_path = "#{Base.root}/config/#{gkey}"
        gopts = {:port=>(gport || 22),:keys=>gkey_path}
        return Net::SSH::Gateway.sync(gname,guser,name,user,from_path,to_path,gopts,opts)
      else
        Net::SCP.start(name,user,opts) do |scp|
          scp.upload!(from_path,to_path,:recursive=>true)
        end
      end
      return true
    end

    def Ssher.run(node,command,file_hash=nil,except=true,su_user=nil,err_file=nil)
      name,key,port,user,dir = Ssher.host(node).ie{|h| ['name','key','port','user','dir'].map{|k| h[k]}}
      key_path = "#{Base.root}/config/#{key}"
      opts = {:port=>(port || 22),:keys=>key_path}
      su_user ||= user
      file_hash ||= {}
      #make sure the dir for this command is clear
      comm_md5 = [su_user,node,command,file_hash.keys.to_s].join.to_md5
      comm_dir = "#{Ssher.tmp_file_dir}#{comm_md5}"
      #populate comm dir with any files
      Ssher.pop_comm_dir(comm_dir,file_hash)
      #move any files up to the node
      rem_dir = nil
      if File.exists?(comm_dir)
        #make sure user starts in rem_dir
        rem_dir = "#{dir}#{comm_md5}/"
        command = ["cd #{rem_dir}",command].join(";") if dir
        Ssher.scp(node,comm_dir,rem_dir)
        "rm -rf #{comm_dir}".bash
        if su_user
          chown_command = "sudo chown -R #{su_user} #{rem_dir}"
          Ssher.run(node,chown_command)
        end
      else
        #cd to dir if provided
        command = ["cd #{dir}",command].join(";") if dir
      end
      if su_user != user
        #wrap the command in sudo su -c
        command = %{sudo su #{su_user} -c "#{command}"}
      end
      result = nil
      #one with gateway, one without
      if Ssher.needs_gateway?(node)
         gname,gkey,gport,guser = Ssher.gateway(node).ie{|h| ['name','key','port','user'].map{|k| h[k]}}
         gkey_path = "#{Base.root}/config/#{gkey}"
         gopts = {:port=>(gport || 22),:keys=>gkey_path}
         result = Net::SSH::Gateway.run(gname,guser,name,user,command,gopts,opts,except,err_file)
      else
         Net::SSH.start(name,user,opts) do |ssh|
           result = ssh.run(command,except,err_file)
         end
      end
      #delete remote dir if necessary
      if rem_dir
        del_cmd = "rm -rf #{rem_dir}"
        if su_user
          del_cmd = %{sudo su #{su_user} -c "#{del_cmd}"}
        end
        Ssher.run(node,del_cmd)
      end
      result
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

    def Ssher.tmp_file(fdata,binary=false,fpath=nil)
      #creates a file under tmp/files with an md5 from the data
      tmp_file_path = fpath || "#{Ssher.tmp_file_dir}#{(fdata + Time.now.utc.to_f.to_s).to_md5}"
      write_mode = binary ? "wb" : "w"
      #make sure folder is created
      "mkdir -p #{tmp_file_path.split("/")[0..-2].join("/")}".bash
      #write data to path
      File.open(tmp_file_path,write_mode) {|f| f.print(fdata)}
      return tmp_file_path
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
  end
end
