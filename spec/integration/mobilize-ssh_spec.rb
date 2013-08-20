require 'spec_helper'
describe Mobilize::Ssh do
  before(:all) do
    restart_test_redis
    drop_test_db
    puts "restart workers"
    Mobilize::Jobtracker.restart_workers!
  end

  let(:u) { owner_user }
  let(:r) { u.runner }
  let(:user_name) { u.name }
  let(:gdrive_slot) { u.email }

  it "build test runner" do
    build_test_runner(user_name)
    worker_length = Mobilize::Jobtracker.workers.length
    expect(worker_length).to eq(Mobilize::Resque.config['max_workers'].to_i)
  end

  it "add test code" do
    ["code.rb","code.sh","code2.sh"].each do |fixture_name|
      target_url = "gsheet://#{r.title}/#{fixture_name}"
      expect(write_fixture(fixture_name, target_url, 'replace')).to be_true
    end
  end

  it "add/update jobs" do
    u.jobs.each{|j| j.stages.each{|s| s.delete}; j.delete}
    jobs_fixture_name = "integration_jobs"
    jobs_target_url = "gsheet://#{r.title}/jobs"
    expect(write_fixture(jobs_fixture_name, jobs_target_url, 'update')).to be_true
  end

  it "job rows added, force enqueue runner, wait for stages" do
    #wait for stages to complete
    expected_fixture_name = "integration_expected"
    Mobilize::Jobtracker.stop!
    r.enqueue!
    expect(confirm_expected_jobs(expected_fixture_name)).to be_true
    r.update_gsheet(gdrive_slot)
  end

  it "check output" do
    ['ssh1.out','ssh2.out','ssh4.out'].each do |out_name|
      url = "gsheet://#{r.title}/#{out_name}"
      expect(output(url).length).to be >= 100
    end

    #shorter
    url = "gsheet://#{r.title}/ssh3.out"
    expect(output(url).length).to be >= 3
  end
end
