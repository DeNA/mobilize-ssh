require 'test_helper'

describe "Mobilize" do

  def before
    puts 'nothing before'
  end

  # enqueues 4 workers on Resque
  it "runs integration test" do

    puts "restart workers"
    Mobilize::Jobtracker.restart_workers!

    gdrive_slot = Mobilize::Gdrive.owner_email
    puts "create user 'mobilize'"
    user_name = gdrive_slot.split("@").first
    u = Mobilize::User.where(:name=>user_name).first
    r = u.runner

    puts "add test code"
    rb_code_sheet = Mobilize::Gsheet.find_or_create_by_path("#{r.path.split("/")[0..-2].join("/")}/code.rb",gdrive_slot)
    rb_code_tsv = File.open("#{Mobilize::Base.root}/test/code.rb").read
    rb_code_sheet.write(rb_code_tsv)

    sh_code_sheet = Mobilize::Gsheet.find_or_create_by_path("#{r.path.split("/")[0..-2].join("/")}/code.sh",gdrive_slot)
    sh_code_tsv = File.open("#{Mobilize::Base.root}/test/code.sh").read
    sh_code_sheet.write(sh_code_tsv)

    jobs_sheet = r.gsheet(gdrive_slot)

    ssh_job_rows = ::YAML.load_file("#{Mobilize::Base.root}/test/ssh_job_rows.yml")
    jobs_sheet.add_or_update_rows(ssh_job_rows)

    puts "job row added, force enqueued runner, wait 90s"
    r.enqueue!
    sleep 90

    puts "update job status and activity"
    r.update_gsheet(gdrive_slot)

    puts "jobtracker posted data to test sheet"
    ssh_target_sheet = Mobilize::Gsheet.find_by_path("#{r.path.split("/")[0..-2].join("/")}/test_ssh.out",gdrive_slot)

    assert ssh_target_sheet.to_tsv.length > 100
  end

end
