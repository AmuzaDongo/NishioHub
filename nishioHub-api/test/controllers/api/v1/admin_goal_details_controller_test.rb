require 'test_helper'
require 'tempfile'
require 'csv'
class Api::V1::AdminGoalDetailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin=create_user(role:create_role('admin'),email:'details-admin@example.test')
    @mentee=create_mentee(email:'details-mentee@example.test')
    @mentor=create_mentor(email:'details-mentor@example.test')
    @program=PlatformProgram.create!(title:'Details program',status:'active')
    @goal=@mentee.mentee_goals.create!(title:'Complete fundamentals',progress:40,platform_program:@program,target_date:'2027-03-20')
  end
  def path(suffix='details',goal=@goal) = "/api/v1/admin/goals/#{goal.goal_key}/#{suffix}"
  def read(suffix='details',actor=@admin,goal=@goal,**params)
    get path(suffix,goal),headers:auth_headers(actor),params:params
  end
  def upload(name='notes.txt',content='Private goal notes',type='text/plain')
    file=Tempfile.new(['goal-detail',File.extname(name)]);file.binmode;file.write(content);file.rewind
    Rack::Test::UploadedFile.new(file.path,type,original_filename:name)
  end
  test 'details work for all scopes and administrator roles while learner and read-only writes are denied' do
    [@goal,@mentor.mentor_goals.create!(title:'Guide learners'),ProgramGoal.create!(title:'Program launch',platform_program:@program)].each do |goal|
      read('details',@admin,goal);assert_response :ok;assert_equal goal.goal_key,response.parsed_body['id'];assert_equal 'medium',response.parsed_body['priority']
    end
    super_admin=create_user(role:create_role('Super Admin'),email:'details-super@example.test')
    read('details',super_admin);assert_response :ok
    read('details',@mentee);assert_response :forbidden
    get path;assert_response :unauthorized
    @admin.role.update!(permissions:['dashboard.read']);read;assert_response :ok;assert_equal false,response.parsed_body.dig('capabilities','manage')
    post path('updates'),params:{update:{body:'Denied'}},headers:auth_headers(@admin),as: :json;assert_response :forbidden
    post path('duplicate'),params:{goal:{lock_version:@goal.lock_version}},headers:auth_headers(@admin),as: :json;assert_response :forbidden
    delete path('attachments/1'),headers:auth_headers(@admin);assert_response :forbidden
  end
  test 'completion timestamp follows actual completion reopening and legacy metadata edits' do
    travel_to Time.utc(2026,11,11,12) do
      @goal.update!(priority:'high',progress:100);assert_equal Time.current,@goal.completed_at
      read;assert_equal 'high',response.parsed_body['priority'];assert_equal Time.current.iso8601,response.parsed_body.dig('summary','completed_at')
      @goal.update!(progress:60);assert_nil @goal.completed_at
      @goal.update_columns(progress:100,completed:true,completed_at:nil)
      @goal.reload.update!(title:'Legacy title');assert_nil @goal.completed_at
      read;assert_nil response.parsed_body.dig('summary','days_taken')
      @goal.priority='critical';assert_not @goal.valid?
    end
  end
  test 'summary and paginated tasks reflect saved independent progress without synthetic history' do
    22.times{|i|@goal.goal_milestones.create!(title:"Module #{i}",completed:i<5)}
    read;assert_response :ok;b=response.parsed_body['summary'];assert_equal 22,b['total_tasks'];assert_equal 5,b['completed_tasks'];assert_equal 22.7,b['task_completion_rate'];assert_nil b['progress_change'];assert_equal 1,b['trend'].length;assert_equal 40,@goal.reload.progress
    read('sections/tasks',@admin,@goal,page:2);assert_response :ok;assert_equal 2,response.parsed_body['items'].size
    read('sections/tasks',@admin,@goal,q:'Module 21');assert_equal 1,response.parsed_body.dig('meta','total')
    read('sections/invalid');assert_response :unprocessable_entity
  end
  test 'notes are scoped revision protected and progress history is immutable' do
    post path('updates'),params:{update:{body:'Module reviewed'}},headers:auth_headers(@admin),as: :json;assert_response :no_content
    note=@goal.goal_updates.first
    patch path("updates/#{note.id}"),params:{update:{body:'Reviewed again',lock_version:note.lock_version}},headers:auth_headers(@admin),as: :json;assert_response :no_content
    patch path("updates/#{note.id}"),params:{update:{body:'Stale',lock_version:0}},headers:auth_headers(@admin),as: :json;assert_response :conflict
    other=@mentor.mentor_goals.create!(title:'Other scope')
    patch path("updates/#{note.id}",other),params:{update:{body:'Wrong goal',lock_version:note.reload.lock_version}},headers:auth_headers(@admin),as: :json;assert_response :not_found
    read('sections/updates',@admin,@goal,q:'Reviewed');assert_response :ok;assert_equal 'note',response.parsed_body['items'][0]['kind'];assert_equal 1,response.parsed_body.dig('meta','total')
    delete path("updates/#{note.id}"),params:{lock_version:note.lock_version},headers:auth_headers(@admin);assert_response :no_content
    read('sections/updates');assert_equal ['progress'],response.parsed_body['items'].map{|i|i['kind']};assert_equal 1,@goal.goal_progress_events.count
    read('sections/activity');assert_response :ok;assert response.parsed_body['items'].any?{|i|i['title']=='goal.update_removed'}
  end
  test 'private files links and removal enforce scope authentication and upload validation' do
    post path('attachments'),params:{attachment:{title:'Private notes',file:upload}},headers:auth_headers(@admin);assert_response :no_content
    item=@goal.goal_attachments.first
    read("attachments/#{item.id}/file");assert_response :ok;assert_equal 'Private goal notes',response.body;assert_includes response.headers['Cache-Control'],'no-store'
    read("attachments/#{item.id}/file",@mentee);assert_response :forbidden
    other=@mentor.mentor_goals.create!(title:'Other files');read("attachments/#{item.id}/file",@admin,other);assert_response :not_found
    post path('attachments'),params:{attachment:{title:'Guide',url:'https://example.org/guide'}},headers:auth_headers(@admin),as: :json;assert_response :no_content
    ['javascript:alert(1)','https://user:password@example.org'].each do |url|
      post path('attachments'),params:{attachment:{title:'Bad link',url:url}},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    end
    post path('attachments'),params:{attachment:{title:'Fake office',file:upload('fake.docx','not a document')}},headers:auth_headers(@admin);assert_response :unprocessable_entity
    post path('attachments'),params:{attachment:{title:'Binary text',file:upload('bad.txt',"bad\x00data")}},headers:auth_headers(@admin);assert_response :unprocessable_entity
    read('sections/attachments');assert_equal 2,response.parsed_body.dig('meta','total');assert_nil response.parsed_body['items'].find{|i|i['id']==item.id}['url']
    delete path("attachments/#{item.id}"),params:{lock_version:item.lock_version},headers:auth_headers(@admin);assert_response :no_content
    read("attachments/#{item.id}/file");assert_response :not_found;assert item.reload.file.attached?
  end
  test 'cover is private revision protected and removable' do
    png=Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
    patch path('cover'),params:{file:upload('cover.png',png,'image/png'),lock_version:@goal.lock_version},headers:auth_headers(@admin);assert_response :no_content
    read('cover');assert_response :ok;assert_equal png.b,response.body.b
    patch path('cover'),params:{remove_cover:true,lock_version:0},headers:auth_headers(@admin),as: :json;assert_response :conflict
    patch path('cover'),params:{remove_cover:true,lock_version:@goal.reload.lock_version},headers:auth_headers(@admin),as: :json;assert_response :no_content
    read('cover');assert_response :not_found
  end
  test 'duplication is atomic resets completion and tasks and shifts dates without copying updates' do
    @goal.update!(progress:100,priority:'high')
    @goal.goal_milestones.create!(title:'Module one',completed:true,target_date:'2027-03-10')
    @goal.goal_updates.create!(body:'Original only',author:@admin,author_name:@admin.full_name)
    @goal.goal_attachments.create!(title:'Guide',url:'https://example.org/guide',author:@admin,author_name:@admin.full_name)
    post path('duplicate'),params:{goal:{title:'New goal',target_date:'2027-04-20',lock_version:@goal.lock_version}},headers:auth_headers(@admin),as: :json;assert_response :created
    copy=AdminGoalManagement.find!(response.parsed_body['id']);assert_equal 0,copy.progress;assert_nil copy.completed_at;assert_equal 'high',copy.priority;assert_equal Date.new(2027,4,10),copy.goal_milestones.first.target_date;assert_not copy.goal_milestones.first.completed;assert_equal 0,copy.goal_updates.count;assert_equal 1,copy.goal_attachments.count;assert_equal 1,copy.goal_progress_events.count
    assert_no_difference 'MenteeGoal.count' do
      post path('duplicate'),params:{goal:{title:'',lock_version:@goal.reload.lock_version}},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    end
    @mentee.update!(is_active:false)
    post path('duplicate'),params:{goal:{title:'Inactive assignee',lock_version:@goal.reload.lock_version}},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
  end
  test 'report is spreadsheet safe scoped activity excludes other goals and archived details are hidden' do
    @goal.update!(title:'=FORMULA')
    other=@mentor.mentor_goals.create!(title:'Unrelated')
    Administration.audit!(@admin,'unrelated.action',other,{})
    read('report');assert_response :ok;assert_includes CSV.parse(response.body),['title',"'=FORMULA"]
    read('sections/activity');assert_not response.parsed_body['items'].any?{|i|i['title']=='unrelated.action'}
    @goal.update!(archived_at:Time.current)
    read;assert_response :not_found
    post path('updates'),params:{update:{body:'After archival'}},headers:auth_headers(@admin),as: :json;assert_response :not_found
  end
  test 'recorded baseline and duration use actual history and platform calendar dates' do
    g=nil
    travel_to(Time.utc(2026,9,30,22)){g=@mentee.mentee_goals.create!(title:'Calendar dates',progress:25)}
    travel_to Time.utc(2026,11,11,12) do
      g.update!(progress:100)
      read('details',@admin,g);assert_response :ok
      assert_equal 41,response.parsed_body.dig('summary','days_taken')
      assert_equal 75,response.parsed_body.dig('summary','progress_change')
      assert_equal [25,100],response.parsed_body.dig('summary','trend').map{|h|h['progress']}
    end
  end
  test 'mentor and program duplication preserve scope and private files have independent records' do
    source=@goal.goal_attachments.new(title:'Original file',author:@admin,author_name:@admin.full_name)
    source.file.attach(io:StringIO.new('Private result'),filename:'result.txt',content_type:'text/plain');source.save!
    goals=[@goal,@mentor.mentor_goals.create!(title:'Mentor original',progress:100),ProgramGoal.create!(title:'Program original',platform_program:@program,progress:100)]
    goals.each do |g|
      post path('duplicate',g),params:{goal:{title:'Duplicated record',lock_version:g.reload.lock_version}},headers:auth_headers(@admin),as: :json
      assert_response :created;copy=AdminGoalManagement.find!(response.parsed_body['id'])
      assert_equal g.class,copy.class;assert_equal 0,copy.progress;assert_nil copy.completed_at
      if g==@goal
        copied=copy.goal_attachments.first;assert_not_equal source.id,copied.id;assert_equal 'Private result',copied.file.download
        source.reload.update!(is_active:false);read("attachments/#{copied.id}/file",@admin,copy);assert_response :ok
      end
    end
  end

end
