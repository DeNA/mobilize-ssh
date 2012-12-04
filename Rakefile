require "bundler/gem_tasks"

require 'mobilize-base/rakes'
require 'mobilize-ssh/rakes'

#
# Tests
#
require 'rake/testtask'

Rake::TestTask.new do |test|
  test.verbose = true
  test.libs << "test"
  test.libs << "lib"
  test.test_files = FileList['test/**/*_test.rb']
end
task :default => :test
