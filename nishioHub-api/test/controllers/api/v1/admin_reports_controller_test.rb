require 'test_helper'
class Api::V1::AdminReportsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  ROOT='/api/v1/admin/reports'
  setup do
    @old_adapter=ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter=:test
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS)
    @admin=create_user(role:create_role('admin'),email:'reports-admin@example.test')
    @other=create_user(role:create_role('super_admin'),email:'reports-super@example.test')
    @mentee=create_mentee
    @headers=auth_headers(@admin)
  end
  teardown do
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter=@old_adapter
  end
  test 'authorization and all report datasets are live and read-only' do
    get ROOT
    assert_response :unauthorized
    get ROOT,headers:auth_headers(@mentee)
    assert_response :forbidden
    [@admin,@other].each do |actor|
      (['overview','custom']+AnalyticsReport::DATASETS.keys).each do |tab|
        get ROOT,headers:auth_headers(actor),params:{tab:tab}
        assert_response :ok
        assert_equal 'private, no-store',response.headers['Cache-Control']
        assert_equal 5,response.parsed_body['metrics'].size
      end
    end
    assert_equal 0,ReportRun.count
    @admin.role.update!(permissions:['dashboard.read'])
    get ROOT,headers:@headers,params:{tab:'users'}
    assert_response :forbidden
    get ROOT,headers:@headers
    assert_response :ok
    assert_not response.parsed_body.dig('capabilities','manage')
    post "#{ROOT}/custom",headers:@headers,params:{report:{name:'Denied',kind:'programs',columns:['title'],filters:{period:'30'}}},as: :json
    assert_response :forbidden
  end
  test 'local cutoffs exclusive roles and current enrollment cohort completion are accurate' do
    travel_to Time.iso8601('2026-11-11T09:00:00Z') do
      User.update_all(created_at:Time.iso8601('2026-10-01T00:00:00Z'))
      @mentee.update_columns(created_at:Time.iso8601('2026-11-10T21:30:00Z'))
      @mentee.additional_roles << @admin.role
      program=PlatformProgram.create!(title:'Data Analytics',created_by:@admin)
      program.program_memberships.create!(user:@mentee,progress:100)
      program.program_memberships.create!(user:@other,progress:50)
      get ROOT,headers:@headers,params:{period:'custom',from:'2026-11-11',to:'2026-11-11'}
      assert_response :ok
      data=response.parsed_body
      assert_equal 'Africa/Kampala',data.dig('period','timezone')
      assert_equal User.count,data['roles'].sum{|r|r['count']}
      assert_equal User.count,data['user_growth'].last['value']
      assert_equal 50.0,data.dig('completion','rate')
      assert_equal 2,data.dig('completion','enrolled')
      assert_equal 75.0,data['top_programs'].first['progress']
      get ROOT,headers:@headers,params:{tab:'programs',q:'no match'}
      assert_response :ok
      assert_equal 0,response.parsed_body.dig('table','meta','total')
    end
  end
  test 'invalid dates and pagination are rejected' do
    [{period:'invalid'},{period:'custom',from:'bad',to:'bad'},{period:'custom',from:'2020-01-01',to:'2026-11-11'},{page:'1junk'},{per_page:500},{tab:'invented'}].each do |params|
      get ROOT,headers:@headers,params:params
      assert_response :unprocessable_entity
    end
  end
  test 'saved custom reports validate columns isolate owners detect stale writes and export safely' do
    post "#{ROOT}/custom",headers:@headers,params:{report:{name:'User list',kind:'users',columns:['name','email'],filters:{period:'30'}}},as: :json
    assert_response :ok
    report=response.parsed_body
    @mentee.update!(full_name:'=SUM(A1)')
    get "#{ROOT}/custom/#{report['id']}",headers:@headers
    assert_response :ok
    assert_equal %w[name email],response.parsed_body['columns'].map{|c|c['key']}
    get "#{ROOT}/custom/#{report['id']}/export",headers:@headers
    assert_response :ok
    assert_includes response.body,"'=SUM(A1)"
    get "#{ROOT}/custom/#{report['id']}",headers:auth_headers(@other)
    assert_response :not_found
    patch "#{ROOT}/custom/#{report['id']}",headers:@headers,params:{report:{name:'Changed',lock_version:report['lock_version']}},as: :json
    assert_response :ok
    patch "#{ROOT}/custom/#{report['id']}",headers:@headers,params:{report:{name:'Stale',lock_version:report['lock_version']}},as: :json
    assert_response :conflict
    post "#{ROOT}/custom",headers:@headers,params:{report:{name:'Invalid',kind:'programs',columns:['title; DROP TABLE users'],filters:{period:'30'}}},as: :json
    assert_response :unprocessable_entity
    @admin.role.update!(permissions:['dashboard.read','dashboard.manage'])
    get "#{ROOT}/custom/#{report['id']}/export",headers:@headers
    assert_response :forbidden
  end
  test 'schedule runs generate private CSV artifacts and pause on permission revocation' do
    post "#{ROOT}/schedules",headers:@headers,params:{schedule:{name:'Weekly summary',kind:'overview',columns:[],filters:{period:'30'},frequency:'weekly',hour:8,minute:0,weekday:1,month_day:1,active:true}},as: :json
    assert_response :ok
    schedule=ReportSchedule.find(response.parsed_body['id'])
    assert schedule.next_run_at>Time.current
    post "#{ROOT}/schedules/#{schedule.id}/run",headers:@headers
    assert_response :ok
    run=response.parsed_body
    assert_equal 'complete',run['status'],run['error']
    get "#{ROOT}/runs/#{run['id']}/file",headers:@headers
    assert_response :ok
    assert_includes response.body,'metric,value'
    get "#{ROOT}/runs/#{run['id']}/file",headers:auth_headers(@other)
    assert_response :not_found
    schedule.update_columns(next_run_at:1.minute.ago)
    assert_difference('ReportRun.count',1){2.times{ReportRunner.run_due!(schedule.reload)}}
    schedule.update_columns(next_run_at:1.minute.ago)
    @admin.role.update!(permissions:['dashboard.read'])
    assert_no_difference('ReportRun.count'){ReportRunner.run_due!(schedule.reload)}
    assert_not schedule.reload.active
  end
  test 'monthly next occurrence uses schedule timezone and invalid time cannot save' do
    schedule=ReportSchedule.new(user:@admin,name:'Month end',kind:'overview',columns:[],filters:{period:'30'},timezone:'Africa/Kampala',frequency:'monthly',hour:8,minute:30,month_day:28,weekday:1)
    assert_equal Time.iso8601('2026-12-28T05:30:00Z'),schedule.next_after(Time.iso8601('2026-11-28T06:00:00Z'))
    post "#{ROOT}/schedules",headers:@headers,params:{schedule:{name:'Invalid',kind:'overview',columns:[],filters:{period:'30'},frequency:'daily',hour:25}},as: :json
    assert_response :unprocessable_entity
  end
  test 'learning and event rows use recorded access and attendance' do
    program=PlatformProgram.create!(title:'Analytics')
    resource=PlatformResource.create!(title:'Data guide',url:'https://example.com/guide',resource_type:'link',platform_program:program)
    PlatformResourceAccess.create!(platform_resource:resource,user:@mentee,kind:'link')
    event=Event.create!(title:'Analytics event',description:'Explore analytics',category:'talk',event_type:'webinar',status:'published',format:'online',location:'Online',meeting_url:'https://example.com/room',organizer:@admin,platform_program:program,starts_at:1.hour.ago,ends_at:1.hour.from_now)
    event.event_registrations.create!(user:@mentee,attended_at:Time.current)
    get ROOT,headers:@headers,params:{tab:'learning',program_id:program.id}
    assert_response :ok
    assert_equal 1,response.parsed_body.dig('table','items',0,'accesses')
    assert_equal 1,response.parsed_body.dig('table','items',0,'learners')
    get ROOT,headers:@headers,params:{tab:'events',program_id:program.id}
    assert_response :ok
    assert_equal 100.0,response.parsed_body.dig('table','items',0,'attendance_rate')
    get "#{ROOT}/export",headers:@headers,params:{kind:'learning',program_id:program.id}
    assert_response :ok
    assert_includes response.body,'Data guide'
  end

  test 'user CSV and scheduled artifacts respect export permission separately from read access' do
    @admin.role.update!(permissions:['dashboard.read','dashboard.manage','users.read'])
    get ROOT,headers:@headers,params:{tab:'users'}
    assert_response :ok
    assert_not response.parsed_body.dig('capabilities','user_export')
    get "#{ROOT}/export",headers:@headers,params:{kind:'users'}
    assert_response :forbidden
    post "#{ROOT}/schedules",headers:@headers,params:{schedule:{name:'Users',kind:'users',columns:['name'],filters:{period:'30'},frequency:'daily',hour:8,minute:0,weekday:1,month_day:1,active:true}},as: :json
    assert_response :forbidden
    @admin.role.update!(permissions:['dashboard.read','dashboard.manage','users.read','users.export'])
    post "#{ROOT}/schedules",headers:@headers,params:{schedule:{name:'Users',kind:'users',columns:['name'],filters:{period:'30'},frequency:'daily',hour:8,minute:0,weekday:1,month_day:1,active:true}},as: :json
    assert_response :ok
    post "#{ROOT}/schedules/#{response.parsed_body['id']}/run",headers:@headers
    assert_response :ok
    run_id=response.parsed_body['id']
    assert_equal 'complete',response.parsed_body['status']
    @admin.role.update!(permissions:['dashboard.read','dashboard.manage','users.read'])
    get "#{ROOT}/runs/#{run_id}/file",headers:@headers
    assert_response :forbidden
  end
  test 'goal category history uses cutoff records including goals archived afterwards' do
    goal=nil
    travel_to Time.iso8601('2026-10-01T08:00:00Z') do
      goal=@mentee.mentee_goals.create!(title:'Recorded data skills',progress:20,category:'learning')
    end
    travel_to(Time.iso8601('2026-10-15T08:00:00Z')) { goal.update!(progress:65) }
    travel_to(Time.iso8601('2026-11-01T08:00:00Z')) { goal.update!(progress:100,archived_at:Time.current) }
    get ROOT,headers:@headers,params:{period:'custom',from:'2026-10-01',to:'2026-10-20'}
    assert_response :ok
    category=response.parsed_body['goal_categories'].find{|g|g['category']=='learning'}
    assert_equal 65.0,category['progress']
    assert_equal 1,category['recorded_goals']
  end

end
