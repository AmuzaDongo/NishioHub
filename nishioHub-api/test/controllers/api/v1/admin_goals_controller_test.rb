require 'test_helper'
require 'csv'
class Api::V1::AdminGoalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin=create_user(role:create_role('admin'),email:'goals-admin@example.test')
    @mentee=create_mentee(email:'goals-mentee@example.test',full_name:'Aisha Goal Learner')
    @mentor=create_mentor(email:'goals-mentor@example.test',full_name:'Grace Goal Mentor')
    @program=PlatformProgram.create!(title:'Data Science Goals',status:'active')
  end
  def attrs(**extra)
    {kind:'mentee',title:'Complete Data Science Basics',description:'Complete all modules.',user_id:@mentee.id,platform_program_id:@program.id,progress:40,target_date:'2027-03-20',category:'learning',tracking_status:'on_track'}.merge(extra)
  end
  def write_goal(values=attrs,id:nil)
    if id
      patch "/api/v1/admin/goals/#{id}",params:{goal:values},headers:auth_headers(@admin),as: :json
    else
      post '/api/v1/admin/goals',params:{goal:values},headers:auth_headers(@admin),as: :json
    end
  end
  def list(**filters)
    get '/api/v1/admin/goals',params:filters,headers:auth_headers(@admin)
  end
  test 'admin super admin and read only permissions protect all mutations' do
    get '/api/v1/admin/goals';assert_response :unauthorized
    get '/api/v1/admin/goals',headers:auth_headers(@mentee);assert_response :forbidden
    super_admin=create_user(role:create_role('Super Admin'),email:'goals-super@example.test')
    get '/api/v1/admin/goals',headers:auth_headers(super_admin);assert_response :ok
    @admin.role.update!(permissions:['dashboard.read']);list;assert_response :ok;assert_equal false,response.parsed_body.dig('capabilities','manage')
    write_goal;assert_response :forbidden
    goal=@mentee.mentee_goals.create!(title:'Read only goal')
    delete "/api/v1/admin/goals/#{goal.goal_key}",params:{lock_version:goal.lock_version},headers:auth_headers(@admin);assert_response :forbidden
    post "/api/v1/admin/goals/#{goal.goal_key}/milestones",params:{milestone:{title:'Attempt'}},headers:auth_headers(@admin),as: :json;assert_response :forbidden
    @admin.role.update!(permissions:[]);list;assert_response :forbidden
  end
  test 'all goal types use their shared personal records and revisions protect edits' do
    write_goal;assert_response :created;key=response.parsed_body['id'];goal=@mentee.mentee_goals.first;assert_equal goal.goal_key,key
    assert_equal 'on_track',response.parsed_body['status'];assert_equal 1,goal.goal_progress_events.count
    write_goal attrs(progress:75,lock_version:goal.lock_version,note:'Completed core modules'),id:key;assert_response :ok
    assert_equal 75,goal.reload.progress;assert_equal 'Completed core modules',goal.goal_progress_events.last.note;assert_equal @admin.full_name,goal.goal_progress_events.last.actor_name
    write_goal attrs(progress:90,lock_version:0),id:key;assert_response :conflict;assert_equal 75,goal.reload.progress
    write_goal attrs(kind:'mentor',user_id:@mentor.id,title:'Guide next generation',category:'career');assert_response :created
    assert_equal 40,@mentor.mentor_goals.last.progress
    write_goal attrs(kind:'program',user_id:nil,title:'Complete program launch',progress:100,category:'project');assert_response :created
    assert ProgramGoal.last.completed
    list;assert_response :ok;body=response.parsed_body;assert_equal 3,body.dig('stats','total');assert_equal 3,body['items'].size;assert_equal 3,body['categories'].sum{|v|v['count']};assert_equal 3,body['distribution'].sum{|v|v['count']}
    get '/api/v1/me/mentee_goals',headers:auth_headers(@mentee);assert_equal 75,response.parsed_body['goals'][0]['progress']
    patch "/api/v1/me/mentee_goals/#{goal.id}",params:{goal:{progress:100}},headers:auth_headers(@mentee),as: :json;assert_response :ok;assert goal.reload.completed
    get "/api/v1/admin/goals/#{key}",headers:auth_headers(@admin);assert_equal 100,response.parsed_body['progress']
  end
  test 'invalid dates types program identifiers role assignments and progress are rejected' do
    [attrs(progress:-1),attrs(progress:101),attrs(progress:1.5),attrs(target_date:'2027-02-30'),attrs(target_date:'tomorrow'),attrs(category:'invalid'),attrs(tracking_status:'invalid'),attrs(kind:'invalid'),attrs(user_id:@mentor.id),attrs(platform_program_id:'1 OR 1=1')].each{|values|write_goal(values);assert_response :unprocessable_entity}
    @mentor.update!(is_active:false);write_goal attrs(kind:'mentor',user_id:@mentor.id);assert_response :unprocessable_entity
    write_goal attrs(kind:'program',platform_program_id:nil);assert_response :unprocessable_entity
    list(sort:'DROP TABLE goals');assert_response :unprocessable_entity
    list(status:'invalid');assert_response :unprocessable_entity
    list(per_page:10000);assert_response :unprocessable_entity
  end
  test 'status is mutually exclusive completed wins and overdue uses platform local date' do
    travel_to Time.utc(2026,11,10,22,30) do
      # It is already November 11 in Kampala.
      @mentee.mentee_goals.create!(title:'Overdue goal',progress:80,target_date:'2026-11-10',tracking_status:'on_track')
      @mentor.mentor_goals.create!(title:'Completed goal',progress:100,target_date:'2026-11-01')
      ProgramGoal.create!(platform_program:@program,title:'In progress goal',progress:20,target_date:'2026-11-11')
      list;assert_response :ok;b=response.parsed_body
      assert_equal 1,b.dig('stats','at_risk');assert_equal 1,b.dig('stats','completed');assert_equal 1,b.dig('stats','in_progress');assert_equal 0,b.dig('stats','on_track')
      list(status:'at_risk');assert_equal ['Overdue goal'],response.parsed_body['items'].map{|v|v['title']}
    end
  end
  test 'filters sorting pagination and mentee mentor progress aggregates are scoped' do
    6.times{|i|@mentee.mentee_goals.create!(title:"Goal #{i}",progress:i*10,platform_program:@program,category:'learning')}
    @mentor.mentor_goals.create!(title:'Mentor Career',progress:80,category:'career')
    ProgramGoal.create!(platform_program:@program,title:'Program Project',progress:100,category:'project')
    list(q:'Aisha',sort:'progress',direction:'desc',per_page:5,page:2);assert_response :ok;assert_equal 6,response.parsed_body.dig('meta','total');assert_equal 1,response.parsed_body['items'].size
    list(program_id:@program.id,category:'project');assert_equal ['Program Project'],response.parsed_body['items'].map{|v|v['title']}
    list(tab:'programs');assert_equal 1,response.parsed_body.dig('meta','total')
    list(tab:'mentees');assert_response :ok;assert_equal 'people',response.parsed_body['mode'];assert_equal 6,response.parsed_body['people'][0]['goals'];assert_equal 25.0,response.parsed_body['people'][0]['progress']
    list(tab:'mentors');assert_equal @mentor.id,response.parsed_body['people'][0]['id'];assert_equal 80.0,response.parsed_body['people'][0]['progress']
  end
  test 'trend uses recorded snapshots without manufacturing missing history' do
    goal=nil
    travel_to(Time.utc(2026,7,5,12)){goal=@mentee.mentee_goals.create!(title:'Historical Goal',progress:20)}
    travel_to(Time.utc(2026,8,10,12)){goal.update!(progress:60)}
    travel_to Time.utc(2026,11,10,12) do
      goal.update!(progress:100);list(months:6);assert_response :ok;trend=response.parsed_body['trend']
      assert_nil trend[0]['progress'];assert_equal 20.0,trend[1]['progress'];assert_equal 60.0,trend[2]['progress'];assert_equal 100.0,trend.last['progress'];assert_equal 1,trend.last['recorded_goals']
    end
  end
  test 'milestones are scoped revision protected and do not rewrite manual goal progress' do
    goal=@mentee.mentee_goals.create!(title:'Milestones',progress:40);other=@mentor.mentor_goals.create!(title:'Other')
    post "/api/v1/admin/goals/#{goal.goal_key}/milestones",params:{milestone:{title:'Build a model',target_date:'2027-02-20'}},headers:auth_headers(@admin),as: :json;assert_response :no_content
    item=goal.goal_milestones.first
    patch "/api/v1/admin/goals/#{other.goal_key}/milestones/#{item.id}",params:{milestone:{completed:true,lock_version:0}},headers:auth_headers(@admin),as: :json;assert_response :not_found
    patch "/api/v1/admin/goals/#{goal.goal_key}/milestones/#{item.id}",params:{milestone:{completed:true,lock_version:0}},headers:auth_headers(@admin),as: :json;assert_response :no_content;assert item.reload.completed;assert_equal 40,goal.reload.progress
    delete "/api/v1/admin/goals/#{goal.goal_key}/milestones/#{item.id}",params:{lock_version:0},headers:auth_headers(@admin);assert_response :conflict
    delete "/api/v1/admin/goals/#{goal.goal_key}/milestones/#{item.id}",params:{lock_version:item.lock_version},headers:auth_headers(@admin);assert_response :no_content
  end
  test 'archival hides goals from learner reports but retains history and exports are spreadsheet safe' do
    goal=@mentee.mentee_goals.create!(title:'=Spreadsheet Formula',progress:60)
    get '/api/v1/admin/goals/export',headers:auth_headers(@admin),params:{goal_ids:[goal.goal_key]};assert_response :ok;assert_equal "'=Spreadsheet Formula",CSV.parse(response.body,headers:true)[0]['title']
    get '/api/v1/admin/goals/report',headers:auth_headers(@admin);assert_response :ok;assert_includes response.body,'overall_progress'
    delete "/api/v1/admin/goals/#{goal.goal_key}",params:{lock_version:goal.lock_version},headers:auth_headers(@admin);assert_response :no_content;assert goal.reload.archived_at;assert_equal 1,goal.goal_progress_events.count
    list;assert_equal 0,response.parsed_body.dig('stats','total')
    get '/api/v1/me/mentee_goals',headers:auth_headers(@mentee);assert_empty response.parsed_body['goals'];assert_empty response.parsed_body['history']
    get "/api/v1/admin/goals/#{goal.goal_key}",headers:auth_headers(@admin);assert_response :not_found
  end
  test 'legacy mentor completion stays synchronized and explicit progress notes are retained' do
    goal=@mentor.mentor_goals.create!(title:'Mentor legacy completion',completed:true)
    assert_equal 100,goal.progress
    patch "/api/v1/me/mentorship/goals/#{goal.id}",params:{goal:{completed:false}},headers:auth_headers(@mentor),as: :json
    assert_response :ok;assert_equal 0,goal.reload.progress;assert_not goal.completed
    before=goal.goal_progress_events.count
    write_goal({progress:0,note:'Mentor preparing the next sessions',lock_version:goal.lock_version},id:goal.goal_key)
    assert_response :ok;assert_equal before+1,goal.goal_progress_events.count;assert_equal 'Mentor preparing the next sessions',goal.goal_progress_events.last.note
    assert_no_difference 'GoalProgressEvent.count' do
      write_goal({title:'Renamed mentoring goal',lock_version:goal.reload.lock_version},id:goal.goal_key)
      assert_response :ok
    end
    assert AdministrationAudit.exists?(target_type:'MentorGoal',target_id:goal.id,action:'goal.updated')
  end

  test 'trend comparison uses the recorded baseline immediately before the displayed window' do
    goal=nil
    travel_to(Time.utc(2026,5,15,12)){goal=@mentee.mentee_goals.create!(title:'Baseline goal',progress:10)}
    travel_to Time.utc(2026,11,10,12) do
      goal.update!(progress:40)
      list(months:6)
      assert_response :ok
      assert_equal '2026-06-01',response.parsed_body['trend'].first['month']
      assert_equal 300.0,response.parsed_body['trend_change']
    end
  end

end
