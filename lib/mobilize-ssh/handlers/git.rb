module Mobilize
  module Git
    def Git.config
      Base.config('git')
    end

    def Git.host(domain)
      Git.config['domains'][domain]['host']
    end

    def Git.domains
      Git.config['domains'].keys
    end

    def Git.default_domain
      Git.domains.first
    end

    # converts a source path or target path to a dst in the context of handler and stage
    def Git.path_to_dst(path,stage_path,gdrive_slot)
      red_path = path.split("://").last
      #a git repo has 2-4 path nodes
      if [2,3,4].include?(red_path.split("/").length)
        user_name = Ssh.user_name_by_stage_path(stage_path)
        git_url = Git.url_by_path(red_path,user_name)
        return Dataset.find_or_create_by_url(git_url)
      end
      #otherwise, use Ssh
      return Ssh.path_to_dst(red_path,stage_path,gdrive_slot)
    end

    #return path to tar.gz of git repo
    def Git.pack(domain,repo,revision="HEAD")
      repo_dir = Git.pull(domain,repo,revision)
      repo_name = repo.split("/").last
      tar_gz_path = "#{repo_dir}/../#{repo_name}.tar.gz"
      pack_cmd = "cd #{repo_dir} && git archive #{revision} --format=tar.gz > #{tar_gz_path}"
      pack_cmd.bash(true)
      FileUtils.rm_r(repo_dir,:force=>true)
      return tar_gz_path
    end
   
    #confirm that git repo exists
    def Git.exists?(domain,repo)
      domain_properties = Git.config['domains'][domain]
      user,host,key = ['user','host','key'].map{|k| domain_properties[k]}
      #put together command
      git_prefix = key ? "ssh-add #{Base.root}/#{key};" : ""
      #add keys, clone repo, go to specific revision, execute command
      full_cmd = "#{git_prefix}git ls-remote #{user}@#{host}:#{repo}.git"
      run_file = Tempfile.new("cmd.sh")
      run_file.print(full_cmd)
      run_file.close
      run_cmd = "ssh-agent bash #{run_file.path}"
      #run the command, it will return an exception if there are issues
      run_cmd.bash(true)
      return true
    end

    def Git.pull(domain,repo,revision="HEAD",run_dir=Dir.mktmpdir)
      domain_properties = Git.config['domains'][domain]
      user,host,key = ['user','host','key'].map{|k| domain_properties[k]}
      #create folder for repo and command
      run_file_path = run_dir + "/cmd.sh"
      #put together command
      git_prefix = key ? "ssh-add #{Base.root}/#{key};" : ""
      git_suffix = (revision=="HEAD" ? " --depth=1" : "; git checkout -q #{revision}")
      #add keys, clone repo, go to specific revision, execute command
      full_cmd = "cd #{run_dir};#{git_prefix}git clone -q #{user}@#{host}:#{repo}.git#{git_suffix}"
      #put command in file, run ssh-agent bash on it
      File.open(run_file_path,"w") {|f| f.print(full_cmd)}
      run_cmd = "ssh-agent bash #{run_file_path}"
      #run the command, it will return an exception if there are issues
      run_cmd.bash(true)
      repo_name = repo.split("/").last
      repo_dir = "#{run_dir}/#{repo_name}"
      return repo_dir
    end

    def Git.url_by_path(path,user_name)
      path_nodes = path.split("/")
      domain = path_nodes.first.to_s
      if Git.domains.include?(domain)
        #strip out anything after the dot, like .git
        repo = path_nodes[1..2].join("/").split(".").first
        revision = path_nodes[3] || "HEAD"
      else
        domain = Git.default_domain
        #strip out anything after the dot, like .git
        repo = path_nodes[0..1].join("/").split(".").first
        revision = path_nodes[2] || "HEAD"
      end
      url = "git://#{domain}/#{repo}/#{revision}"
      begin
        cmd = "ls"
        response = Git.run(domain,repo,cmd)
        if response['exit_code'] != 0
          raise "Unable to find #{url} with error: #{response['stderr']}"
        else
          return "ssh://#{node}#{path}"
        end
      rescue => exc
        raise Exception, "Unable to find #{url} with error: #{exc.to_s}", exc.backtrace
      end
    end

    def Git.read_by_dataset_path(dst_path,user_name,*args)
      #expects node as first part of path
      node,path = dst_path.split("/").ie{|pa| [pa.first,pa[1..-1].join("/")]}
      #slash in front of path
      response = Git.run(node,"cat /#{path}",user_name)
      if response['exit_code'] == 0
        return response['stdout']
      else
        raise "Unable to read git://#{dst_path} with error: #{response['stderr']}"
      end
    end
    
    def Git.user_name_by_stage_path(stage_path,node=nil)
      s = Stage.where(:path=>stage_path).first
      u = s.job.runner.user
      user_name = s.params['user']
      node = s.params['node']
      node = Git.default_node unless Git.nodes.include?(node)
      if user_name and !Git.sudoers(node).include?(u.name)
        raise "#{u.name} does not have su permissions for this node"
      elsif user_name.nil? and Git.su_all_users(node)
        user_name = u.name
      end
      return user_name
    end

    def Git.file_hash_by_stage_path(stage_path,gdrive_slot)
      file_hash = {}
      s = Stage.where(:path=>stage_path).first
      u = s.job.runner.user
      user_name = Git.user_name_by_stage_path(stage_path)
      s.sources(gdrive_slot).each do |sdst|
                       split_path = sdst.path.split("/")
                       #if path is to stage output, name with stage name
                       file_name = if (split_path.last == "out" and (1..5).to_a.map{|n| "stage#{n.to_s}"}.include?(split_path[-2].to_s))
                                     #<jobname>/stage1/out
                                     "#{split_path[-2]}.out"
                                   elsif (1..5).to_a.map{|n| "stage#{n.to_s}"}.include?(split_path.last[-6..-1])
                                     #runner<jobname>stage1
                                   "#{split_path.last[-6..-1]}.out"
                                   else
                                     split_path.last
                                   end
                       if ["gsheet","gfile"].include?(sdst.handler)
                         #google drive sources are always read as the user
                         #with the apportioned slot
                         file_hash[file_name] = sdst.read(u.name,gdrive_slot)
                       else
                         #other sources should be read by su-user
                         file_hash[file_name] = sdst.read(user_name)
                       end
                     end
      return file_hash
    end

    def Git.run_by_stage_path(stage_path)
      gdrive_slot = Gdrive.slot_worker_by_path(stage_path)
      #return blank response if there are no slots available
      return nil unless gdrive_slot
      s = Stage.where(:path=>stage_path).first
      params = s.params
      node, command = [params['node'],params['cmd']]
      node ||= Git.default_node
      user_name = Git.user_name_by_stage_path(stage_path)
      file_hash = Git.file_hash_by_stage_path(stage_path,gdrive_slot)
      Gdrive.unslot_worker_by_path(stage_path)
      result = Git.run(node,command,user_name,file_hash)
      #use Gridfs to cache result
      response = {}
      response['out_url'] = Dataset.write_by_url("gridfs://#{s.path}/out",result['stdout'].to_s,Gdrive.owner_name)
      response['err_url'] = Dataset.write_by_url("gridfs://#{s.path}/err",result['stderr'].to_s,Gdrive.owner_name) if result['stderr'].to_s.length>0
      response['signal'] = result['exit_code']
      response
    end
  end
end
