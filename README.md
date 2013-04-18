Mobilize-Ssh
============

Mobilize-Ssh adds the power of ssh to [mobilize-base][mobilize-base].
* move files, execute scripts, and output logs and datasets, all through
Google Spreadsheets.

Table Of Contents
-----------------
* [Overview](#section_Overview)
* [Install](#section_Install)
  * [Mobilize-Ssh](#section_Install_Mobilize-Ssh)
  * [Install Dirs and Files](#section_Install_Dirs_and_Files)
* [Configure](#section_Configure)
  * [Ssh](#section_Configure_Ssh)
  * [Git](#section_Configure_Git)
* [Start](#section_Start)
  * [Create Job](#section_Start_Create_Job)
  * [Run Test](#section_Start_Run_Test)
* [Meta](#section_Meta)
* [Author](#section_Author)

<a name='section_Overview'></a>
Overview
-----------

* Mobilize-ssh adds script deployment to mobilize-base.

<a name='section_Install'></a>
Install
------------

Make sure you go through all the steps in the [mobilize-base][mobilize-base]
install section first.

<a name='section_Install_Mobilize-Ssh'></a>
### Mobilize-Ssh

add this to your Gemfile:

``` ruby
gem "mobilize-ssh"
```

or do

  $ gem install mobilize-ssh

for a ruby-wide install.

<a name='section_Install_Dirs_and_Files'></a>
### Dirs and Files

### Rakefile

Inside the Rakefile in your project's root dir, make sure you have:

``` ruby
require 'mobilize-base/tasks'
require 'mobilize-ssh/tasks'
```

This defines rake tasks essential to run the environment.

### Config Dir

run 

  $ rake mobilize_ssh:setup

This will copy over a sample ssh.yml to your config dir.

It will also add mobilize-ssh to the extensions in jobtracker.yml.

<a name='section_Configure'></a>
Configure
------------

<a name='section_Configure_Ssh'></a>
### Configure Ssh

The Ssh configuration consists of:
* nodes, identified by aliases, such as `test_node`. This alias is what you should
pass into the "node" param over in the ssh.run task.
  * if no node is specified, commands will default to the first node listed.

Each node has: 
* a host;
* a gateway (optional); If you don't need a gateway, remove that row from the configuration file.
* sudoers; these are user names that are allowed to pass user params
to the run call. This requires passwordless sudo for the host user.
* su_all_users true/false option, which ensures that commands are executed by the
user on the Runner. It prefixes all commands with sudo su <user> before executing the
command. This is strongly recommended if possible as it ensures users do
not overstep their permissions. This requires passwordless sudo for the
host user and accounts on the host machine for each user.

Each host and gateway has a series of ssh params:
* name - the ip address or name of the host
* key - the relative path of the ssh key file. Default is
"config/mobilize/ssh_private.key"
* port - the port to connect on
* user - the user you are connecting as

Sample ssh.yml:

``` yml
---
development:
  nodes:
    dev_node:
      sudoers: 
      - sudo_user
      su_all_users: true
      host: 
        name: dev-host.com 
        key: config/mobilize/ssh_private.key
        port: 22
        user: host_user
      gateway: 
        name: dev-gateway.com 
        key: config/mobilize/ssh_private.key 
        port: 22 
        user: gateway_user
test:
  nodes:
    test_node:
      sudoers: 
      - sudo_user
      su_all_users: true
      host: 
        name: test-host.com 
        key: config/mobilize/ssh_private.key 
        port: 22 
        user: host_user
      gateway: 
        name: test-gateway.com 
        key: config/mobilize/ssh_private.key 
        port: 22 
        user: gateway_user
production:
  nodes:
    prod_node:
      sudoers: 
      - sudo_user
      su_all_users: true
      host:
        name: prod-host.com 
        key: config/mobilize/ssh_private.key 
        port: 22 
        user: host_user
      gateway: 
        name: prod-gateway.com 
        key: config/mobilize/ssh_private.key 
        port: 22 
        user: gateway_user
```

<a name='section_Configure_Git'></a>
### Configure Git

Git configuration is not required but recommended, as it allows you to
pull files directly from public or private Git repositories.

The Git configuration consists of:
* domains, identified by aliases, such as `private` and `public`.
  * domains are passed into the source parameters in the git.run task.
  * if no domain is specified, commands will default to the first domain listed.

Each domain has: 
* a host;
* a user, which is the user used for the git clone command.
* a set of repo keys (optional) which correspond to "deploy keys" on
github.  Each repo must have its own ssh key, and the public key must be
stored in the repo.
  * if your repo doesn't need an ssh key to work, this is not necessary
to add.


Sample git.yml:

``` yml
---
development:
  domains:
    private:
      host: github.private.com
      user: git
      repo_keys:
        "repo_path_1": 'local/path/to/key1'
        "repo_path_2": 'local/path/to/key1'
    public:
      host: github.com
      user: git
test:
  domains:
    public:
      host: github.com
      user: git
    private:
      host: github.private.com
      user: git
      repo_keys:
        "repo_path_1": 'local/path/to/key1'
        "repo_path_2": 'local/path/to/key1'
production:
  domains:
    private:
      host: github.private.com
      user: git
      repo_keys:
        "repo_path_1": 'local/path/to/key1'
        "repo_path_2": 'local/path/to/key1'
    public:
      host: github.com
      user: git
```


<a name='section_Start'></a>
Start
-----

<a name='section_Start_Create_Job'></a>
### Create Job

* For mobilize-ssh, the following task is available:
  * ssh.run `node: <node_alias>, cmd: <command>, user: user, sources:[*<source_paths>], params:[{<key,value pairs>}]`, which reads sources, copies them to a temporary folder on the selected node, and runs the command inside that folder. 
  * user, sources, node, and params are optional; cmd is required. 
  * specifying user will cause the command to be prefixed with sudo su <user> -c. 
    * non-google sources will also be read as the specified user.
  * git sources can be specified with syntax `git://<domain>/<repo_owner>/<repo_name>/<file_path>`. 
    * Accessing private repos requires that you add the Mobilize public key to the repository as a deploy key.
      * there is no user-level access control for git repositories at this time.
    * domain defaults to the first one listed, if not included.
  * params are also optional for all of the below. They replace tokens in sources and the command.
    * params are passed as a YML or JSON, as in:
      * `ssh.run source:<source_path>, params:{'date':'2013-03-01', 'unit':'widgets'}`
        * this example replaces all the keys, preceded by '@' in all source hqls with the value.
          * The preceding '@' is used to keep from replacing instances
            of "date" and "unit" in the command/source file; you should have `@date` and `@unit` in your actual HQL 
            if you'd like to replace those tokens.
  * not specifying node will cause the command to be run on the default node.
  * ssh sources can be specified with syntax
`ssh://<node><file_full_path>`. If node is omitted, default node will be used.
  * `<node><file_full_path>` and `<file_full_path>` can be used in the context of ssh.run, but if the path has only 1 slash, or none, it will try to find a google sheet or file instead.
  * The test uses `ssh.run node:"test_node", cmd:"ruby code.rb", user: "root", sources:["code.rb","code.sh"]`

<a name='section_Start_Run_Test'></a>
### Run Test

To run tests, you will need to 

1) go through the [mobilize-base][mobilize-base] test first

2) clone the mobilize-ssh repository 

From the project folder, run

3) $ rake mobilize_ssh:setup

Copy over the config files from the mobilize-base project into the
config dir, and populate the values in the ssh.yml file, esp. the
test_node item.

You should also copy the ssh private key you wish to use into your
desired path (by default: config/mobilize/ssh_private.key), and make sure it is referenced in ssh.yml

3) $ rake test

This will populate your test Runner from mobilize-base with a sample ssh job.

The purpose of the test will be to deploy two code files, have the first
execute the second, which is a "tail /var/log/syslog" command, and write the resulting output to a gsheet.

<a name='section_Meta'></a>
Meta
----

* Code: `git clone git://github.com/dena/mobilize-ssh.git`
* Home: <https://github.com/dena/mobilize-ssh>
* Bugs: <https://github.com/dena/mobilize-ssh/issues>
* Gems: <http://rubygems.org/gems/mobilize-ssh>

<a name='section_Author'></a>
Author
------

Cassio Paes-Leme :: cpaesleme@dena.com :: @cpaesleme

[mobilize-base]: https://github.com/dena/mobilize-base
