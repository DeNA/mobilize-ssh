require 'test_helper'

describe "Mobilize" do

  def before
    puts 'nothing before'
  end

  # enqueues 4 workers on Resque
  it "runs integration test" do

    puts "restart workers"
    Mobilize::Jobtracker.restart_workers!

    email = Mobilize::Gdrive.owner_email
    puts "create requestor 'mobilize'"
    requestor = Mobilize::Requestor.find_or_create_by_email(email)

    runner_title = requestor.runner_title

    puts "add test_source data"
    rb_code_sheet = Mobilize::Gsheet.find_or_create_by_name("#{runner_title}/code.rb",email)
    rb_code_tsv = File.open("#{Mobilize::Base.root}/test/code.rb").read
    rb_code_sheet.write(rb_code_tsv)

    sh_code_sheet = Mobilize::Gsheet.find_or_create_by_name("#{runner_title}/code.sh",email)
    sh_code_tsv = File.open("#{Mobilize::Base.root}/test/code.sh").read
    sh_code_sheet.write(sh_code_tsv)

    jobs_sheet = requestor.jobs_sheet(email)

    test_job_rows = ::YAML.load_file("#{Mobilize::Base.root}/test/ssh_job_rows.yml")
    jobs_sheet.add_or_update_rows(test_job_rows)

    puts "job row added, force enqueued requestor"
    requestor.enqueue!
    sleep 120

    puts "jobtracker posted data to test sheet"
    test_destination_sheet = Mobilize::Gsheet.find_or_create_by_name("#{runner_title}/test_destination",email)

    assert test_destination_sheet.to_tsv.length > 100
  end

end
