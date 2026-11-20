require 'test_helper'
require 'csv'
class Api::V1::AdminAchievementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin=create_user(role:create_role('admin'),email:'achievement-admin@example.test')
    @learner=create_mentee(email:'achievement-learner@example.test',full_name:'Aisha Award Learner')
    @program=PlatformProgram.create!(title:'Data Science Recognition',status:'active')
  end
  def list(**params)
    get '/api/v1/admin/achievements',params:params,headers:auth_headers(@admin)
  end
  def create_definition(**extra)
    post '/api/v1/admin/achievements',params:{definition:{title:'Data Explorer',description:'Applied data skills',criteria:'Finish a practical project',kind:'skill_badge',icon:'star',color:'gold'}.merge(extra)},headers:auth_headers(@admin),as: :json
  end
  def issue(definition,**extra)
    post "/api/v1/admin/achievements/definitions/#{definition.id}/award",params:{user_ids:[@learner.id],program_id:@program.id}.merge(extra),headers:auth_headers(@admin),as: :json
  end
  test 'admin super admin member and read-only authorization' do
    get '/api/v1/admin/achievements';assert_response :unauthorized
    get '/api/v1/admin/achievements',headers:auth_headers(@learner);assert_response :forbidden
    super_admin=create_user(role:create_role('Super Admin'),email:'achievement-super@example.test')
    get '/api/v1/admin/achievements',headers:auth_headers(super_admin);assert_response :ok
    @admin.role.update!(permissions:['dashboard.read']);list;assert_response :ok;assert_equal false,response.parsed_body.dig('capabilities','manage')
    create_definition;assert_response :forbidden
    definition=AchievementDefinition.create!(title:'Read only guard',kind:'other')
    issue(definition);assert_response :forbidden
    patch "/api/v1/admin/achievements/definitions/#{definition.id}",params:{definition:{title:'Denied',lock_version:0}},headers:auth_headers(@admin),as: :json;assert_response :forbidden
    post '/api/v1/admin/achievements/award-00000000-0000-0000-0000-000000000000/revoke',params:{reason:'Denied',lock_version:0},headers:auth_headers(@admin),as: :json;assert_response :forbidden
  end
  test 'empty metrics and real automatic records are read only and match learner awards' do
    list;assert_response :ok;b=response.parsed_body;assert_equal 0,b.dig('stats','total');assert_equal 8,b.dig('stats','badges');assert_nil b['trend_change'];assert b['trend'].all?{|v|v['count']==0}
    assert_no_difference 'LearningCertificate.count' do
      list(tab:'certificates');assert_response :ok
    end
    @learner.learning_enrollments.create!(course_key:'programming',completed_lesson_ids:LearningCatalog.find('programming')['lessons'].map{|l|l['id']})
    @learner.mentee_goals.create!(title:'Complete basics',progress:100)
    list;assert_response :ok;b=response.parsed_body;assert_equal 4,b.dig('stats','total');assert_equal 1,b.dig('stats','learners');assert_equal 1,b.dig('stats','certificates');assert_equal 4,b['distribution'].sum{|v|v['count']};assert_equal 2,b['top_badges'].sum{|v|v['count']}
    list(tab:'certificates');assert_equal ['certificate'],response.parsed_body['items'].map{|v|v['kind']}
  end
  test 'definition creation edits revisions and archive preserve award snapshots' do
    create_definition;assert_response :created;definition=AchievementDefinition.last
    issue(definition);assert_response :no_content;award=AchievementAward.last
    patch "/api/v1/admin/achievements/definitions/#{definition.id}",params:{definition:{title:'Renamed badge',lock_version:0}},headers:auth_headers(@admin),as: :json;assert_response :no_content
    assert_equal 'Data Explorer',award.reload.title
    patch "/api/v1/admin/achievements/definitions/#{definition.id}",params:{definition:{title:'Stale',lock_version:0}},headers:auth_headers(@admin),as: :json;assert_response :conflict
    patch "/api/v1/admin/achievements/definitions/#{definition.id}",params:{definition:{is_active:false,lock_version:definition.reload.lock_version}},headers:auth_headers(@admin),as: :json;assert_response :no_content
    issue(definition);assert_response :not_found
    list;assert_equal 1,response.parsed_body.dig('stats','total')
    list(tab:'badges',include_archived:'true',q:'Renamed');assert_response :ok;assert_equal false,response.parsed_body['items'][0]['active'];assert_equal 1,response.parsed_body['items'][0]['awarded']
  end
  test 'batch issuance rejects duplicates inactive recipients invalid dates and programs atomically' do
    create_definition;d=AchievementDefinition.last
    issue(d,awarded_on:'2026-02-30');assert_response :unprocessable_entity
    issue(d,awarded_on:'2099-01-01');assert_response :unprocessable_entity
    other=create_mentee(email:'inactive-award@example.test');other.update!(is_active:false)
    issue(d,user_ids:[@learner.id,other.id]);assert_response :unprocessable_entity;assert_equal 0,AchievementAward.count
    issue(d);assert_response :no_content
    issue(d);assert_response :conflict;assert_equal 1,AchievementAward.count
    issue(d,user_ids:[@learner.id,@learner.id]);assert_response :unprocessable_entity
    issue(d,program_id:'1 OR 1=1');assert_response :unprocessable_entity
    create_definition(kind:'invalid');assert_response :unprocessable_entity
  end
  test 'create and issue is atomic notifications and learner badges share the saved award' do
    post '/api/v1/admin/achievements',params:{definition:{title:'Community Innovator',kind:'skill_badge',icon:'rocket',color:'pink'},user_ids:[@learner.id],program_id:@program.id},headers:auth_headers(@admin),as: :json;assert_response :created
    award=AchievementAward.last
    assert Notification.exists?(user:@learner,source_key:"achievement-awarded-#{award.id}")
    get '/api/v1/me/achievements',headers:auth_headers(@learner);assert_response :ok;assert_equal 1,response.parsed_body.dig('summary','badges');assert_equal 'Community Innovator',response.parsed_body['badges'].last['name']
    post '/api/v1/admin/achievements',params:{definition:{title:'Rollback',kind:'other'},user_ids:[99999999]},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity;assert_not AchievementDefinition.exists?(title:'Rollback')
  end
  test 'revocation requires revision and reason hides personal award retains admin history and permits reissue' do
    create_definition;d=AchievementDefinition.last;issue(d);award=AchievementAward.last
    path="/api/v1/admin/achievements/award-#{award.identifier}/revoke"
    post path,params:{reason:'',lock_version:0},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    post path,params:{reason:'Incorrect recipient',lock_version:9},headers:auth_headers(@admin),as: :json;assert_response :conflict
    post path,params:{reason:'Incorrect recipient',lock_version:0},headers:auth_headers(@admin),as: :json;assert_response :no_content
    list;assert_equal 0,response.parsed_body.dig('stats','total')
    list(status:'revoked');assert_equal 'Incorrect recipient',response.parsed_body['items'][0]['revocation_reason']
    get '/api/v1/me/achievements',headers:auth_headers(@learner);assert_equal 0,response.parsed_body.dig('summary','badges')
    issue(d);assert_response :no_content;assert_equal 2,AchievementAward.count
  end
  test 'certificate downloads are owner scoped escaped and revoked certificates cannot download' do
    create_definition(kind:'certificate',title:'<Course & Certificate>');issue(AchievementDefinition.last);a=AchievementAward.last
    path="/api/v1/admin/achievements/award-#{a.identifier}/certificate"
    get path,headers:auth_headers(@admin);assert_response :ok;assert_includes response.body,'&lt;Course &amp; Certificate&gt;';assert_equal 'image/svg+xml',response.media_type
    other=create_mentee(email:'other-award@example.test')
    get "/api/v1/me/achievements/certificates/award-#{a.identifier}",headers:auth_headers(other);assert_response :not_found
    get "/api/v1/me/achievements/certificates/award-#{a.identifier}",headers:auth_headers(@learner);assert_response :ok
    a.update!(revoked_at:Time.current,revocation_reason:'Issued by mistake')
    get path,headers:auth_headers(@admin);assert_response :not_found
    get "/api/v1/me/achievements/certificates/award-#{a.identifier}",headers:auth_headers(@learner);assert_response :not_found
  end
  test 'filters pagination people distribution and exports use scoped real awards and safe cells' do
    create_definition(title:'=FORMULA');d=AchievementDefinition.last;issue(d)
    6.times{|i|defn=AchievementDefinition.create!(title:"Recognition #{i}",kind:'special_recognition');issue(defn)}
    list(q:'Aisha',page:2);assert_response :ok;assert_equal 7,response.parsed_body.dig('meta','total');assert_equal 2,response.parsed_body['items'].size
    list(tab:'users');assert_response :ok;assert_equal 7,response.parsed_body['items'][0]['count']
    list(program_id:@program.id,kind:'skill_badge');assert_equal 1,response.parsed_body.dig('stats','total');assert_equal @program.title,response.parsed_body['top_programs'][0]['title']
    get '/api/v1/admin/achievements/export',params:{kind:'skill_badge'},headers:auth_headers(@admin);assert_response :ok;assert_equal "'=FORMULA",CSV.parse(response.body,headers:true)[0]['achievement']
    get '/api/v1/admin/achievements/report',headers:auth_headers(@admin);assert_response :ok;assert_includes response.body,'special_recognition,6'
    list(kind:'bad');assert_response :unprocessable_entity
    list(per_page:100000);assert_response :unprocessable_entity
    list(sort:'drop table');assert_response :unprocessable_entity
  end
  test 'all automatic badge criteria agree with learner records and program completion stays connected' do
    %w[programming robotics innovation].each{|key|@learner.learning_enrollments.create!(course_key:key,completed_lesson_ids:LearningCatalog.find(key)['lessons'].map{|l|l['id']})}
    @learner.mentee_goals.create!(title:'Finished goal',progress:100)
    mentor=create_mentor(email:'badge-rule-mentor@example.test');service=create_service(mentor:mentor)
    10.times{create_booking(service:service,mentor:mentor,mentee:@learner,status:'completed')}
    event=Event.create!(organizer:@admin,title:'Confirmed attendance',description:'Learning together',category:'workshop',starts_at:2.days.ago,ends_at:1.day.ago,location:'Online')
    event.event_registrations.create!(user:@learner,attended_at:Time.current)
    membership=ProgramMembership.create!(platform_program:@program,user:@learner,progress:100)
    list(kind:'skill_badge',per_page:50);assert_response :ok
    expected=MenteeAchievements.new(@learner).badges.select{|b|b[:earned]}.map{|b|"builtin-#{b[:id]}"}.sort
    assert_equal 8,expected.length;assert_equal expected,response.parsed_body['items'].map{|r|r['definition_key']}.sort
    row=response.parsed_body['items'].first
    post "/api/v1/admin/achievements/#{row['id']}/revoke",params:{reason:'Cannot override automatic criteria',lock_version:0},headers:auth_headers(@admin),as: :json;assert_response :not_found
    list(kind:'program_completion');assert_equal 1,response.parsed_body.dig('stats','total');assert_equal @program.id,response.parsed_body['items'][0].dig('program','id')
    membership.update!(progress:90);list(kind:'program_completion');assert_equal 0,response.parsed_body.dig('stats','total')
    enrollment=@learner.learning_enrollments.find_by!(course_key:'programming');enrollment.update!(completed_lesson_ids:[])
    list(kind:'certificate');assert_equal 2,response.parsed_body.dig('stats','total')
  end
  test 'automatic calendar badges and reporting buckets use the platform timezone' do
    times=[Time.utc(2026,11,30,20),Time.utc(2026,11,30,22),Time.utc(2026,11,30,23)]
    %w[programming robotics innovation].each_with_index do |key,i|
      travel_to(times[i]){@learner.learning_enrollments.create!(course_key:key,completed_lesson_ids:LearningCatalog.find(key)['lessons'].map{|l|l['id']})}
    end
    travel_to Time.utc(2026,12,1,0) do
      assert_not MenteeAchievements.new(@learner).badges.find{|b|b[:id]=='active-learner'}[:earned]
      list(kind:'skill_badge',per_page:50);assert_response :ok
      assert_not response.parsed_body['items'].any?{|r|r['definition_key']=='builtin-active-learner'}
      list(kind:'certificate');assert_response :ok
      assert_equal 1,response.parsed_body['trend'].find{|r|r['month']=='2026-11-01'}['count']
      assert_equal 2,response.parsed_body['trend'].last['count']
    end
  end
  test 'primary and additional mentee roles are valid award recipients while unrelated roles are rejected' do
    create_definition;d=AchievementDefinition.last
    mentor=create_mentor(email:'multi-role-award@example.test');mentor.additional_roles<<create_role('mentee')
    issue(d,user_ids:[mentor.id]);assert_response :no_content
    unrelated=create_user(role:create_role('organization'),email:'organization-award@example.test')
    issue(d,user_ids:[unrelated.id]);assert_response :unprocessable_entity
    @admin.role.update!(permissions:[]);list;assert_response :forbidden
  end

end
