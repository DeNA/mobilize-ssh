module Mobilize
  module Ssh
    def Ssh.config
      Base.config('ssh')
    end

    def Ssh.tmp_file_dir
      Ssh.config['tmp_file_dir']
    end

    def Ssh.host(node)
      Ssh.config['nodes'][node]['host']
    end

    def Ssh.gateway(node)
      Ssh.config['nodes'][node]['gateway']
    end

    def Ssh.sudoers(node)
      Ssh.config['nodes'][node]['sudoers']
    end

    def Ssh.su_all_users(node)
      Ssh.config['nodes'][node]['su_all_users']
    end

    def Ssh.default_node
      Ssh.config['default_node']
    end

    #determine if current machine is on host domain, needs gateway if one is provided and it is not
    def Ssh.needs_gateway?(node)
      host_domain_name = Ssh.host(node)['name'].split(".")[-2..-1].join(".")
      return true if Ssh.gateway(node) and Socket.domain_name != host_domain_name
    end

    def Ssh.pop_comm_dir(comm_dir,file_hash)
      FileUtils.rm_r comm_dir, :force=>true
      file_hash.each do |fname,fdata|
        fpath = "#{comm_dir}/#{fname}"
        #for now, only gz is binary
        binary = fname.ends_with?(".gz") ? true : false
        #read data from cache, put it in a tmp_file
        Ssh.tmp_file(fdata,binary,fpath)
      end
      return true if file_hash.keys.length>0
    end

    def Ssh.set_key_permissions(key_path)
      #makes sure permissions are set as appropriate for ssh key
      raise "could not find ssh key at #{key_path}" unless File.exists?(key_path)
      File.chmod(0600,key_path) unless File.stat(key_path).mode.to_s(8)[3..5] == "600"
      return true
    end

    def Ssh.scp(node,from_path,to_path)
      name,key,port,user = Ssh.host(node).ie{|h| ['name','key','port','user'].map{|k| h[k]}}
      key_path = "#{Base.root}/#{key}"
      Ssh.set_key_permissions(key_path)
      opts = {:port=>(port || 22),:keys=>key_path}
      if Ssh.needs_gateway?(node)
        gname,gkey,gport,guser = Ssh.gateway(node).ie{|h| ['name','key','port','user'].map{|k| h[k]}}
        gkey_path = "#{Base.root}/#{gkey}"
        gopts = {:port=>(gport || 22),:keys=>gkey_path}
        return Net::SSH::Gateway.sync(gname,guser,name,user,from_path,to_path,gopts,opts)
      else
        Net::SCP.start(name,user,opts) do |scp|
          scp.upload!(from_path,to_path,:recursive=>true)
        end
      end
      return true
    end

    def Ssh.run(node,command,user,file_hash={})
      key,default_user = Ssh.host(node).ie{|h| ['key','user'].map{|k| h[k]}}
      key_path = "#{Base.root}/#{key}"
      Ssh.set_key_permissions(key_path)
      file_hash ||= {}
      #make sure the dir for this command is clear
      comm_md5 = [user,node,command,file_hash.keys.to_s].join.to_md5
      comm_dir = "#{Ssh.tmp_file_dir}#{comm_md5}"
      #populate comm dir with any files
      Ssh.pop_comm_dir(comm_dir,file_hash)
      #move any files up to the node
      rem_dir = nil
      #make sure user starts in rem_dir
      rem_dir = "#{comm_md5}/"
      #make sure the rem_dir is gone
      Ssh.fire!(node,"rm -rf #{rem_dir}")
      if File.exists?(comm_dir)
        Ssh.scp(node,comm_dir,rem_dir)
        FileUtils.rm_r comm_dir, :force=>true
      else
        #create folder
        mkdir_command = "mkdir #{rem_dir}"
        Ssh.fire!(node,mkdir_command)
      end
      #create cmd_file in rem_folder
      cmd_file = "#{comm_md5}.sh"
      cmd_path = "#{rem_dir}#{cmd_file}"
      Ssh.write(node,command,cmd_path)
      full_cmd = "(cd #{rem_dir} && sh #{cmd_file})"
      #fire_cmd runs sh on cmd_path, optionally with sudo su
      fire_cmd = if user != default_user
                   %{sudo su #{user} -c "#{full_cmd}"}
                 else
                   full_cmd
                 end
      result = Ssh.fire!(node,fire_cmd)
      #remove the directory after you're done
      FileUtils.rm_r rem_dir, :force=>true
      Ssh.fire!(node,rm_cmd)
      result
    end

    def Ssh.fire!(node,cmd)
      name,key,port,user = Ssh.host(node).ie{|h| ['name','key','port','user'].map{|k| h[k]}}
      key_path = "#{Base.root}/#{key}"
      Ssh.set_key_permissions(key_path)
      opts = {:port=>(port || 22),:keys=>key_path}
      if Ssh.needs_gateway?(node)
        gname,gkey,gport,guser = Ssh.gateway(node).ie{|h| ['name','key','port','user'].map{|k| h[k]}}
        gkey_path = "#{Base.root}/#{gkey}"
        gopts = {:port=>(gport || 22),:keys=>gkey_path}
        Net::SSH::Gateway.run(gname,guser,name,user,cmd,gopts,opts)
      else
        Net::SSH.start(name,user,opts) do |ssh|
          ssh.run(cmd)
        end
      end
    end

    def Ssh.read(node,path)
      Ssh.fire!(node,"cat #{path}")
    end

    def Ssh.write(node,fdata,to_path,binary=false)
      from_path = Ssh.tmp_file(fdata,binary)
      Ssh.scp(node,from_path,to_path)
      FileUtils.rm from_path
      return true
    end

    def Ssh.tmp_file(fdata,binary=false,fpath=nil)
      #creates a file under tmp/files with an md5 from the data
      tmp_file_path = fpath || "#{Ssh.tmp_file_dir}#{(fdata + Time.now.utc.to_f.to_s).to_md5}"
      write_mode = binary ? "wb" : "w"
      #make sure folder is created
      tmp_file_dir = tmp_file_path.split("/")[0..-2].join("/")
      FileUtils.mkdir_p(tmp_file_dir)
      #write data to path
      File.open(tmp_file_path,write_mode) {|f| f.print(fdata)}
      return tmp_file_path
    end

    def Ssh.run_by_stage_path(stage_path)
      s = Stage.where(:path=>stage_path).first
      u = s.job.runner.user
      params = s.params
      node, command = [params['node'],params['cmd']]
      node ||= Ssh.default_node
      gdrive_slot = Gdrive.slot_worker_by_path(s.path)
      file_hash = {}
      s.source_dsts(gdrive_slot).each do |sdst|
                                      file_name = sdst.path.split("/").last
                                      file_hash[file_name] = sdst.read(u.name)
                                    end
      Gdrive.unslot_worker_by_path(s.path)
      user = s.params['user']
      if user and !Ssh.sudoers(node).include?(u.name)
        raise "#{u.name} does not have su permissions for this node"
      elsif user.nil? and Ssh.su_all_users(node)
        user = u.name
      end
      out_tsv = Ssh.run(node,command,user,file_hash)
      #use Gridfs to cache result
      out_url = "gridfs://#{s.path}/out"
      Dataset.write_by_url(out_url,out_tsv,Gdrive.owner_name)
    end
  end
end
