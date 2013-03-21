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
    user = gdrive_slot.split("@").first
    u = Mobilize::User.where(:name=>user).first
    r = u.runner

    rb_code_sheet = Mobilize::Gsheet.find_by_path("#{r.path.split("/")[0..-2].join("/")}/code.rb",gdrive_slot)
    sh_code_sheet = Mobilize::Gsheet.find_by_path("#{r.path.split("/")[0..-2].join("/")}/code.sh",gdrive_slot)
    sh_code_sheet2 = Mobilize::Gsheet.find_by_path("#{r.path.split("/")[0..-2].join("/")}/code2.sh",gdrive_slot)
    [rb_code_sheet,sh_code_sheet].each {|s| s.delete if s}

    puts "add test code"
    rb_code_sheet = Mobilize::Gsheet.find_or_create_by_path("#{r.path.split("/")[0..-2].join("/")}/code.rb",gdrive_slot)
    rb_code_tsv = File.open("#{Mobilize::Base.root}/test/code.rb").read
    rb_code_sheet.write(rb_code_tsv,Mobilize::Gdrive.owner_name)

    sh_code_sheet = Mobilize::Gsheet.find_or_create_by_path("#{r.path.split("/")[0..-2].join("/")}/code.sh",gdrive_slot)
    sh_code_tsv = File.open("#{Mobilize::Base.root}/test/code.sh").read
    sh_code_sheet.write(sh_code_tsv,Mobilize::Gdrive.owner_name)

    sh_code_sheet2 = Mobilize::Gsheet.find_or_create_by_path("#{r.path.split("/")[0..-2].join("/")}/code2.sh",gdrive_slot)
    sh_code_tsv2 = File.open("#{Mobilize::Base.root}/test/code2.sh").read
    sh_code_sheet2.write(sh_code_tsv2,Mobilize::Gdrive.owner_name)

    jobs_sheet = r.gsheet(gdrive_slot)

    #delete target sheets if they exist
    ssh_target_sheet_1 = Mobilize::Gsheet.find_by_path("#{r.path.split("/")[0..-2].join("/")}/test_ssh_1.out",gdrive_slot)
    ssh_target_sheet_2 = Mobilize::Gsheet.find_by_path("#{r.path.split("/")[0..-2].join("/")}/test_ssh_2.out",gdrive_slot)
    ssh_target_sheet_3 = Mobilize::Gsheet.find_by_path("#{r.path.split("/")[0..-2].join("/")}/test_ssh_3.out",gdrive_slot)
    [ssh_target_sheet_1,ssh_target_sheet_2,ssh_target_sheet_3].each {|s| s.delete if s}

    ssh_job_rows = ::YAML.load_file("#{Mobilize::Base.root}/test/ssh_job_rows.yml")
    ssh_job_rows.map{|j| r.jobs(j['name'])}.each{|j| j.delete if j}
    jobs_sheet.add_or_update_rows(ssh_job_rows)

    puts "job row added, force enqueue runner, wait for stages"
    r.enqueue!
    wait_for_stages(900)

    puts "update job status and activity"
    r.update_gsheet(gdrive_slot)

    puts "jobtracker posted data to test sheet"
    ssh_target_sheet_1 = Mobilize::Gsheet.find_by_path("#{r.path.split("/")[0..-2].join("/")}/test_ssh_1.out",gdrive_slot)
    ssh_target_sheet_2 = Mobilize::Gsheet.find_by_path("#{r.path.split("/")[0..-2].join("/")}/test_ssh_2.out",gdrive_slot)
    ssh_target_sheet_3 = Mobilize::Gsheet.find_by_path("#{r.path.split("/")[0..-2].join("/")}/test_ssh_3.out",gdrive_slot)

    assert ssh_target_sheet_1.to_tsv.length > 100
    assert ssh_target_sheet_2.to_tsv.length > 100
    assert ssh_target_sheet_3.to_tsv.length > 3

  end

  def wait_for_stages(time_limit=600,stage_limit=120,wait_length=10)
    time = 0
    time_since_stage = 0
    #check for 10 min
    while time < time_limit and time_since_stage < stage_limit
      sleep wait_length
      job_classes = Mobilize::Resque.jobs.map{|j| j['class']}
      if job_classes.include?("Mobilize::Stage")
        time_since_stage = 0
        puts "saw stage at #{time.to_s} seconds"
      else
        time_since_stage += wait_length
        puts "#{time_since_stage.to_s} seconds since stage seen"
      end
      time += wait_length
      puts "total wait time #{time.to_s} seconds"
    end

    if time >= time_limit
      raise "Timed out before stage completion"
    end
  end

end
