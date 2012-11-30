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
  * [Default Folders and Files](#section_Install_Folders_and_Files)
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

<a name='section_Install_Folders_and_Files'></a>
### Folders and Files

### Rakefile

Inside the Rakefile in your project's root folder, make sure you have:

``` ruby
require 'mobilize-base/tasks'
require 'mobilize-ssh/tasks'
```

This defines tasks essential to run the environment.

### Config Folder

run 

  $ rake mobilize_ssh:setup

This will copy over a sample ssh.yml to your config folder.

You should also copy over at least one ssh private key into the config
folder, which will be referenced in the ssh config as used to log onto
the different servers.

<a name='section_Configure'></a>
Configure
------------

<a name='section_Configure_Ssh'></a>
### Configure Ssh

The Ssh configuration for a development environment consists of nodes,
identified by aliases, such as `test_host`. This alias is what you should
pass into the "node" param over in the Mobilize Jobspec.

Each node has a host, and optionally has a gateway. If you don't need a
gateway, remove that row from the configuration file.

Each host and gateway has a series of ssh params:
* name - the ip address or name of the host
* key - the name of the ssh key file in your config folder
* port - the port to connect on
* user - the user you are connecting as

Sample ssh.yml:

``` yml

development:
  nodes:
    dev_host:
      host: {name: dev-host.com, key: your_key.ssh, port: 22, user: host_user}
      gateway: {name: dev-gateway.com, key: your_key.ssh, port: 22, user: gateway_user}
test:
  nodes:
    test_host:
      host: {name: test-host.com, key: mobilize.ssh, port: 22, user: host_user}
      gateway: {name: test-gateway.com, key: your_key.ssh, port: 22, user: gateway_user}
production:
  nodes:
    prod_host:
      host: {name: prod-host.com, key: mobilize.ssh, port: 22, user: host_user}
      gateway: {name: prod-gateway.com, key: your_key.ssh, port: 22, user: gateway_user}

```

<a name='section_Start'></a>
Start
-----

<a name='section_Start_Run_Test'></a>
### Run Test

To run tests, you will need to 

1) clone the repository 

From the project folder, run

2) $ rake mobilize_base:setup; rake mobilize_ssh:setup

and populate the "test" environment in the config files with the
necessary details, including values for "test_host" under the test
environment.

You should also copy the ssh private key you wish to use into the config folder.

3) $ rake test

This will create a test Jobspec with a sample ssh job.

The purpose of the test will be to deploy two code files, have the first
execute the second, which is a "tail /var/log/syslog" command, and write the resulting output to a google sheet.

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
