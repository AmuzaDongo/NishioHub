require 'test_helper'
require 'csv'
class Api::V1::AdminAchievementDetailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin=create_user(role:create_role('admin'),email:'achievement-detail-admin@example.test')
    @learner=create_mentee(email:'achievement-detail-learner@example.test',full_name:'Aisha Details')
    @program=PlatformProgram.create!(title:'Details program',status:'active')
    @definition=AchievementDefinition.create!(title:'Recognized learner',kind:'certificate',criteria:'Verified project delivery')
    @award=@definition.achievement_awards.create!(user:@learner,issuer:@admin,issuer_name:@admin.full_name,platform_program:@program,awarded_at:Time.current,criteria_snapshot:@definition.criteria,**@definition.attributes.symbolize_keys.slice(:title,:description,:kind,:icon,:color))
    @key="award-#{@award.identifier}"
  end
  def path(suffix='details',key=@key) = "/api/v1/admin/achievements/#{key}/#{suffix}"
  def read(suffix='details',key=@key,actor=@admin,**params)
    get path(suffix,key),headers:auth_headers(actor),params:params
  end
  def finish_course
    @learner.learning_enrollments.create!(course_key:'programming',completed_lesson_ids:LearningCatalog.find('programming')['lessons'].map{|l|l['id']})
  end
  test 'admin super admin member and read-only permissions apply to details and all mutations' do
    get path;assert_response :unauthorized
    read('details',@key,@learner);assert_response :forbidden
    super_admin=create_user(role:create_role('Super Admin'),email:'achievement-detail-super@example.test');read('details',@key,super_admin);assert_response :ok
    @admin.role.update!(permissions:['dashboard.read']);read;assert_response :ok;assert_equal false,response.parsed_body.dig('capabilities','manage')
    post path('notes'),params:{note:{body:'Denied'}},headers:auth_headers(@admin),as: :json;assert_response :forbidden
    patch path,params:{achievement:{title:'Denied',lock_version:0}},headers:auth_headers(@admin),as: :json;assert_response :forbidden
    post path('criteria'),params:{criterion:{title:'Denied'}},headers:auth_headers(@admin),as: :json;assert_response :forbidden
    post path('goals'),params:{goal_id:1},headers:auth_headers(@admin),as: :json;assert_response :forbidden
    read('details','invalid');assert_response :not_found
  end
  test 'manual details report unknown evidence honestly and correction is explicit revision protected and audited' do
    read;assert_response :ok;b=response.parsed_body
    assert_nil b['cohort'];assert_nil b['joined_at'];assert_nil b.dig('metrics','final_score');assert_nil b.dig('metrics','overall_progress');assert_nil b.dig('metrics','modules');assert_equal 'Verified project delivery',b['criteria_description']
    @definition.update!(criteria:'New future criteria');read;assert_equal 'Verified project delivery',response.parsed_body['criteria_description']
    patch path,params:{achievement:{title:'Corrected award',cohort_label:'Cohort 3',final_score:98,lock_version:@award.lock_version}},headers:auth_headers(@admin),as: :json;assert_response :no_content
    assert_equal 'Corrected award',@award.reload.title;assert_equal 98,@award.final_score
    patch path,params:{achievement:{title:'Stale',lock_version:0}},headers:auth_headers(@admin),as: :json;assert_response :conflict
    patch path,params:{achievement:{final_score:101,lock_version:@award.lock_version}},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    read('sections/activity');assert_response :ok;assert response.parsed_body['items'].any?{|a|a['title']=='achievement.corrected'}
  end
  test 'automatic course criteria and certificate use real lesson records and cannot be manually overwritten' do
    enrollment=finish_course;key="course-#{enrollment.id}"
    read('details',key);assert_response :ok;b=response.parsed_body
    assert_equal 4,b['criteria'].size;assert_equal({'completed'=>4,'total'=>4},b.dig('metrics','modules'));assert_nil b.dig('metrics','assessments');assert_nil b.dig('metrics','project');assert_nil b.dig('metrics','final_score');assert_equal 100,b.dig('metrics','overall_progress');assert b['certificate']
    patch path('details',key),params:{achievement:{title:'No override',lock_version:0}},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    read('details/certificate',key);assert_response :ok;assert_equal 'image/svg+xml',response.media_type;assert_includes response.headers['Cache-Control'],'no-store'
    read('sections/activity',key);assert_response :ok;assert_equal 4,response.parsed_body['items'].count{|a|a['title']=='Lesson completed'}
  end
  test 'criteria CRUD is scoped validated revision protected and does not change award status' do
    post path('criteria'),params:{criterion:{title:'Assessments',category:'assessments',completed_units:3,target_units:4}},headers:auth_headers(@admin),as: :json;assert_response :no_content
    item=@award.achievement_criteria.first
    read;assert_equal 75,response.parsed_body.dig('metrics','overall_progress');assert_equal({'completed'=>3,'total'=>4},response.parsed_body.dig('metrics','assessments'));assert_nil @award.reload.revoked_at
    patch path("criteria/#{item.id}"),params:{criterion:{completed_units:4,lock_version:item.lock_version}},headers:auth_headers(@admin),as: :json;assert_response :no_content;assert item.reload.completed_at
    patch path("criteria/#{item.id}"),params:{criterion:{completed_units:2,lock_version:0}},headers:auth_headers(@admin),as: :json;assert_response :conflict
    patch path("criteria/#{item.id}"),params:{criterion:{completed_units:5,lock_version:item.lock_version}},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    other=finish_course;delete path("criteria/#{item.id}","course-#{other.id}"),params:{lock_version:item.lock_version},headers:auth_headers(@admin);assert_response :unprocessable_entity
    delete path("criteria/#{item.id}"),params:{lock_version:item.lock_version},headers:auth_headers(@admin);assert_response :no_content
    @award.reload.update!(revoked_at:Time.current,revocation_reason:'Recorded error')
    post path('criteria'),params:{criterion:{title:'Cannot edit revoked',category:'other',completed_units:1,target_units:1}},headers:auth_headers(@admin),as: :json;assert_response :conflict
  end
  test 'notes CRUD search pagination and audit are achievement scoped' do
    post path('notes'),params:{note:{body:'Staff verification note'}},headers:auth_headers(@admin),as: :json;assert_response :no_content
    note=AchievementNote.last
    other=finish_course
    patch path("notes/#{note.id}","course-#{other.id}"),params:{note:{body:'Wrong award',lock_version:0}},headers:auth_headers(@admin),as: :json;assert_response :not_found
    patch path("notes/#{note.id}"),params:{note:{body:'Verification complete',lock_version:0}},headers:auth_headers(@admin),as: :json;assert_response :no_content
    delete path("notes/#{note.id}"),params:{lock_version:0},headers:auth_headers(@admin);assert_response :conflict
    read('sections/notes',@key,@admin,q:'verification');assert_equal 1,response.parsed_body.dig('meta','total')
    delete path("notes/#{note.id}"),params:{lock_version:note.reload.lock_version},headers:auth_headers(@admin);assert_response :no_content
    assert_not note.reload.is_active
    read('sections/notes');assert_equal 0,response.parsed_body.dig('meta','total')
    22.times{|i|AchievementNote.create!(achievement_key:@key,author:@admin,author_name:@admin.full_name,body:"Note #{i}")}
    read('sections/notes',@key,@admin,page:2);assert_equal 2,response.parsed_body['items'].size
    read('sections/activity',"course-#{other.id}");assert_not response.parsed_body['items'].any?{|a|a['title']=='achievement.note_saved'}
  end
  test 'related goals must belong to the learner and links do not alter goal progress' do
    mine=@learner.mentee_goals.create!(title:'Related learning goal',progress:60)
    other=create_mentee(email:'other-detail-goal@example.test').mentee_goals.create!(title:'Private other goal')
    read('eligible_goals');assert_response :ok;assert_equal [mine.id],response.parsed_body['items'].map{|g|g['id']}
    post path('goals'),params:{goal_id:other.id},headers:auth_headers(@admin),as: :json;assert_response :not_found
    post path('goals'),params:{goal_id:mine.id},headers:auth_headers(@admin),as: :json;assert_response :no_content
    link=AchievementGoalLink.last
    read('sections/goals');assert_equal mine.goal_key,response.parsed_body['items'][0]['goal_key'];assert_equal 60,mine.reload.progress
    post path('goals'),params:{goal_id:mine.id},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    # Reassignment must not expose another learner's goal through an old link.
    mine.update!(user_id:other.user_id);read('sections/goals');assert_empty response.parsed_body['items']
    mine.update!(user_id:@learner.id)
    delete path("goals/#{link.id}"),params:{lock_version:link.lock_version},headers:auth_headers(@admin);assert_response :no_content
  end
  test 'missing course certificate issuance is idempotent and incomplete or revoked records cannot download' do
    enrollment=finish_course;enrollment.learning_certificate.destroy!;key="course-#{enrollment.id}"
    read('details',key);assert_equal true,response.parsed_body['can_issue_certificate']
    2.times do
      post path('details/certificate',key),headers:auth_headers(@admin);assert_response :no_content
    end
    assert_equal 1,LearningCertificate.where(learning_enrollment:enrollment).count
    enrollment.update!(completed_lesson_ids:[])
    read('details/certificate',key);assert_response :not_found
    @award.reload.update!(revoked_at:Time.current,revocation_reason:'Invalid')
    read('details/certificate');assert_response :not_found
  end
  test 'record exports are spreadsheet safe and automatic badge program and session details retain their source metrics' do
    @award.update!(title:'=FORMULA')
    read('record');assert_response :ok;assert_includes CSV.parse(response.body),['title',"'=FORMULA"]
    @learner.mentee_goals.create!(title:'Badge goal',progress:100)
    read('details',"badge-goal-setter-#{@learner.id}");assert_response :ok;assert_equal 100,response.parsed_body.dig('metrics','overall_progress');assert_nil response.parsed_body.dig('metrics','modules')
    membership=ProgramMembership.create!(platform_program:@program,user:@learner,progress:100)
    read('details',"program-#{membership.id}");assert_response :ok;assert response.parsed_body['joined_at']
    mentor=create_mentor(email:'detail-session-mentor@example.test');booking=create_booking(service:create_service(mentor:mentor),mentee:@learner,mentor:mentor,status:'completed')
    read('details',"session-#{booking.id}");assert_response :ok
    read('sections/notes',@key,@admin,page:0);assert_response :unprocessable_entity
  end
end
