require "bundler/gem_tasks"

require 'mobilize-base/tasks'
require 'mobilize-ssh/tasks'

#
# Tests
#
require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:integration_tests) do |spec|
  spec.pattern = FileList['spec/integration/*_spec.rb']
  spec.rspec_opts = ['--color', '--format documentation']
end

RSpec::Core::RakeTask.new(:unit_tests) do |spec|
  spec.pattern = FileList['spec/unit/*_spec.rb']
  spec.rspec_opts = ['--color', '--format documentation']
end

RSpec::Core::RakeTask.new(:test) do |spec|
  spec.pattern = FileList['spec/*/*_spec.rb']
  spec.rspec_opts = ['--color', '--format documentation']
end

task :default => [:test]
