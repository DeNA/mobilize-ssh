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

    def Ssh.nodes
      Ssh.config['nodes'].keys
    end

    def Ssh.default_node
      Ssh.nodes.first
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

    # converts a source path or target path to a dst in the context of handler and stage
    def Ssh.path_to_dst(path,stage_path)
      has_handler = true if path.index("://")
      path = path.split("://").last
      #is user has a handler, their first path node is a node name,
      #or there are more than 2 path nodes, try to find Ssh file
      if has_handler or Ssh.nodes.include?(path.split("/").first) or path.split("/").length > 2
        user_name = Ssh.user_name_by_stage_path(stage_path)
        ssh_url = Ssh.url_by_path(path,user_name)
        return Dataset.find_or_create_by_url(ssh_url)
      end
      #otherwise, use Gsheet
      return Gsheet.path_to_dst(path,stage_path)
    end

    def Ssh.url_by_path(path,user_name)
      node = path.split("/").first.to_s
      if Ssh.nodes.include?(node)
        #cut node out of path
        path = "/" + path.split("/")[1..-1].join("/")
      else
        node = Ssh.default_node
        path = path.starts_with?("/") ? path : "/#{path}"
      end
      url = "ssh://#{node}#{path}"
      begin
        response = Ssh.run(node, "head -1 #{path}", user_name)
        if response['exit_code'] != 0
          raise "Unable to find #{url} with error: #{response['stderr']}"
        else
          return "ssh://#{node}#{path}"
        end
      rescue => exc
        raise Exception, "Unable to find #{url} with error: #{exc.to_s}", exc.backtrace
      end
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
      Ssh.fire!(node,"sudo rm -rf #{rem_dir}")
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
      if user != default_user
        #make sure user owns the folder and all files
        fire_cmd = %{sudo chown -R #{user} #{rem_dir}; sudo su #{user} -c "#{full_cmd}"}
        rm_cmd = %{sudo rm -rf #{rem_dir}}
      else
        fire_cmd = full_cmd
        rm_cmd = "rm -rf #{rem_dir}"
      end
      result = Ssh.fire!(node,fire_cmd)
      Ssh.fire!(node,rm_cmd)
      result
    end

    def Ssh.fire!(node,cmd)
      name,key,port,user = Ssh.host(node).ie{|h| ['name','key','port','user'].map{|k| h[k]}}
      key_path = "#{Base.root}/#{key}"
      Ssh.set_key_permissions(key_path)
      opts = {:port=>(port || 22),:keys=>key_path}
      response = if Ssh.needs_gateway?(node)
                   gname,gkey,gport,guser = Ssh.gateway(node).ie{|h| ['name','key','port','user'].map{|k| h[k]}}
                   gkey_path = "#{Base.root}/#{gkey}"
                   gopts = {:port=>(gport || 22),:keys=>gkey_path}
                   Net::SSH::Gateway.run(gname,guser,name,user,cmd,gopts,opts)
                 else
                   Net::SSH.start(name,user,opts) do |ssh|
                     ssh.run(cmd)
                   end
                 end
      response
    end

    def Ssh.read_by_dataset_path(dst_path,user_name,*args)
      #expects node as first part of path
      node,path = dst_path.split("/").ie{|pa| [pa.first,pa[1..-1].join("/")]}
      #slash in front of path
      response = Ssh.run(node,"cat /#{path}",user_name)
      if response['exit_code'] == 0
        return response['stdout']
      else
        raise "Unable to read ssh://#{dst_path} with error: #{response['stderr']}"
      end
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

    def Ssh.user_name_by_stage_path(stage_path)
      s = Stage.where(:path=>stage_path).first
      u = s.job.runner.user
      user_name = s.params['user']
      node = s.params['node'] || Ssh.default_node
      if user_name and !Ssh.sudoers(node).include?(u.name)
        raise "#{u.name} does not have su permissions for this node"
      elsif user_name.nil? and Ssh.su_all_users(node)
        user_name = u.name
      end
      return user_name
    end

    def Ssh.file_hash_by_stage_path(stage_path)
      file_hash = {}
      s = Stage.where(:path=>stage_path).first
      u = s.job.runner.user
      user_name = Ssh.user_name_by_stage_path(stage_path)
      s.sources.each do |sdst|
                       split_path = sdst.path.split("/")
                       #if path is to stage output, name with stage name
                       file_name = if split_path.last == "out" and
                                     (1..5).to_a.map{|n| "stage#{n.to_s}"}.include?(split_path[-2].to_s)
                                     "#{split_path[-2]}.out"
                                   else
                                     split_path.last
                                   end
                       if ["gsheet","gfile"].include?(sdst.handler)
                         #google drive sources are always read as the user
                         file_hash[file_name] = sdst.read(u.name)
                       else
                         #other sources should be read by su-user
                         file_hash[file_name] = sdst.read(user_name)
                       end
                     end
      return file_hash
    end

    def Ssh.run_by_stage_path(stage_path)
      s = Stage.where(:path=>stage_path).first
      params = s.params
      node, command = [params['node'],params['cmd']]
      node ||= Ssh.default_node
      user_name = Ssh.user_name_by_stage_path(stage_path)
      file_hash = Ssh.file_hash_by_stage_path(stage_path)
      result = Ssh.run(node,command,user_name,file_hash)
      #use Gridfs to cache result
      response = {}
      response['out_url'] = Dataset.write_by_url("gridfs://#{s.path}/out",result['stdout'].to_s,Gdrive.owner_name)
      response['err_url'] = Dataset.write_by_url("gridfs://#{s.path}/err",result['stderr'].to_s,Gdrive.owner_name) if result['stderr'].to_s.length>0
      response['signal'] = result['exit_code']
      response
    end
  end
end
