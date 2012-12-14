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
gem "mobilize-ssh", "~>1.0"
```

or do

  $ gem install mobilize-ssh

for a ruby-wide install.

<a name='section_Install_Dirs_and_Files'></a>
### Dirs and Files

### Rakefile

Inside the Rakefile in your project's root dir, make sure you have:

``` ruby
require 'mobilize-base/rakes'
require 'mobilize-ssh/rakes'
```

This defines rake tasks essential to run the environment.

### Config Dir

run 

  $ rake mobilize_ssh:setup

This will copy over a sample ssh.yml to your config dir.

<a name='section_Configure'></a>
Configure
------------

<a name='section_Configure_Ssh'></a>
### Configure Ssh

The Ssh configuration consists of:
* tmp_file_dir, which is where files will be stored before being scp'd
over to the nodes. They will be deleted afterwards, unless the job
fails in mid-copy. By default this is tmp/file/.
* nodes, identified by aliases, such as `test_node`. This alias is what you should
pass into the "node" param over in the ssh.run task.

Each node has a host, and optionally has a gateway. If you don't need a
gateway, remove that row from the configuration file.

Each host and gateway has a series of ssh params:
* name - the ip address or name of the host
* key - the relative path of the ssh key file. Default is
"config/mobilize/ssh_private.key"
* port - the port to connect on
* user - the user you are connecting as

Sample ssh.yml:

``` yml

development:
  tmp_file_dir: "tmp/file/"
  nodes:
    dev_node:
      host: {name: dev-host.com, key: "config/mobilize/ssh_private.key", port: 22, user: host_user}
      gateway: {name: dev-gateway.com, key: "config/mobilize/ssh_private.key", port: 22, user: gateway_user}
test:
  tmp_file_dir: "tmp/file/"
  nodes:
    test_node:
      host: {name: test-host.com, key: "config/mobilize/ssh_private.key", port: 22, user: host_user}
      gateway: {name: test-gateway.com, key: "config/mobilize/ssh_private.key", port: 22, user: gateway_user}
production:
  tmp_file_dir: "tmp/file/"
  nodes:
    prod_node:
      host: {name: prod-host.com, key: "config/mobilize/ssh_private.key", port: 22, user: host_user}
      gateway: {name: prod-gateway.com, key: "config/mobilize/ssh_private.key", port: 22, user: gateway_user}
```

<a name='section_Start'></a>
Start
-----

<a name='section_Start_Create_Job'></a>
### Create Job

* For mobilize-ssh, the following task is available:
  * ssh.run `node: <node_alias>, cmd: <command>, su_user: su_user, sources:[*<gsheet_full_paths>]`, which reads
all gsheets, copies them to a temporary folder on the selected node, and
runs the command inside that folder. 
  * su_user and sources are optional; node and cmd are required. su_user
will cause the command to be prefixed with sudo su <su_user> -c.
  * The test uses `ssh.run node:"test_node", cmd:"ruby code.rb", su_user: "root", sources:["Runner_mobilize(test)/code.rb","Runner_mobilize(test)/code.sh"]`

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

* Code: `git clone git://github.com/ngmoco/mobilize-ssh.git`
* Home: <https://github.com/ngmoco/mobilize-ssh>
* Bugs: <https://github.com/ngmoco/mobilize-ssh/issues>
* Gems: <http://rubygems.org/gems/mobilize-ssh>

<a name='section_Author'></a>
Author
------

Cassio Paes-Leme :: cpaesleme@ngmoco.com :: @cpaesleme

[mobilize-base]: https://github.com/ngmoco/mobilize-base
