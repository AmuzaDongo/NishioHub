require 'test_helper'
class Api::V1::MentorApplicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @applicant=create_mentee(email:'onboarding-applicant@example.test')
    @other=create_mentee(email:'onboarding-other@example.test')
    @admin=create_user(role:create_role('admin'),email:'onboarding-admin@example.test')
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS)
  end
  def application(user=@applicant)
    MentorApplication.find_or_create_by!(user:user)
  end
  def complete(user=@applicant)
    item=application(user)
    item.update!(headline:'Technology Educator',background:'I teach computer skills.',expertise:'Programming and career guidance',years_of_experience:5,motivation:'Help young people discover opportunities.',references_text:'School coordinator, with permission to contact.',conduct_accepted:true,safeguarding_accepted:true)
    MentorApplication::DOCUMENTS.each{|key|item.reload.public_send(key).attach(io:StringIO.new("%PDF-1.4\nApplication evidence\n%%EOF"),filename:'evidence.pdf',content_type:'application/pdf')}
    item.reload
  end
  def submit(item,user=@applicant)
    post '/api/v1/me/mentor-application/submit',params:{lock_version:item.lock_version,policy_version:MentorApplication::POLICY_VERSION},headers:auth_headers(user),as: :json
  end
  def review(item,**attrs)
    post "/api/v1/admin/mentor-applications/#{item.id}/review",params:{lock_version:item.reload.lock_version,decision:'approved',note:''}.merge(attrs),headers:auth_headers(@admin),as: :json
  end
  test 'authentication own drafts validation revisions and forged status are enforced' do
    get '/api/v1/me/mentor-application';assert_response :unauthorized
    get '/api/v1/me/mentor-application',headers:auth_headers(@applicant);assert_response :ok
    id=response.parsed_body['id']
    assert_equal 'draft',response.parsed_body['status'];assert_includes response.headers['Cache-Control'],'no-store'
    get '/api/v1/me/mentor-application',params:{user_id:@applicant.id},headers:auth_headers(@other);assert_response :ok;assert_not_equal id,response.parsed_body['id']
    item=application
    patch '/api/v1/me/mentor-application',params:{application:{headline:'My headline',status:'approved',user_id:@other.id},lock_version:item.lock_version},headers:auth_headers(@applicant),as: :json
    assert_response :ok;assert_equal 'draft',item.reload.status;assert_equal @applicant.id,item.user_id
    patch '/api/v1/me/mentor-application',params:{application:{headline:'Overwrite'},lock_version:0},headers:auth_headers(@applicant),as: :json
    assert_response :conflict
    submit(item);assert_response :unprocessable_entity;assert_equal 'draft',item.reload.status
    patch '/api/v1/me/mentor-application',params:{application:{years_of_experience:-1},lock_version:item.lock_version},headers:auth_headers(@applicant),as: :json;assert_response :unprocessable_entity
  end
  test 'complete submission locks editing and documents are private with authenticated downloads only' do
    item=complete
    get '/api/v1/me/mentor-application',headers:auth_headers(@applicant);assert_not_includes response.body,'signed_id';assert_not_includes response.body,'rails/active_storage'
    get '/api/v1/me/mentor-application/documents/identity_document',headers:auth_headers(@other);assert_response :not_found
    get '/api/v1/me/mentor-application/documents/identity_document';assert_response :unauthorized
    get '/api/v1/me/mentor-application/documents/identity_document',headers:auth_headers(@applicant);assert_response :ok;assert_equal 'nosniff',response.headers['X-Content-Type-Options'];assert_includes response.headers['Content-Disposition'],'attachment';assert_includes response.body,'Application evidence'
    post '/api/v1/me/mentor-application/submit',params:{lock_version:item.lock_version,policy_version:'obsolete'},headers:auth_headers(@applicant),as: :json;assert_response :unprocessable_entity
    submit(item);assert_response :ok;assert_equal 'submitted',item.reload.status;assert item.consented_at;assert_nil @applicant.mentor_profile
    assert Notification.exists?(user:@admin,title:'Mentor Application Submitted')
    patch '/api/v1/me/mentor-application',params:{application:{headline:'Changed during review'},lock_version:item.lock_version},headers:auth_headers(@applicant),as: :json;assert_response :unprocessable_entity
    delete '/api/v1/me/mentor-application/documents/identity_document',params:{lock_version:item.lock_version},headers:auth_headers(@applicant);assert_response :unprocessable_entity
    submit(item);assert_response :unprocessable_entity
  end
  test 'approval verifies profile preserves existing roles audits and grants no administrative role' do
    item=complete;submit(item);assert_response :ok
    review(item);assert_response :ok
    assert_equal 'approved',item.reload.status
    @applicant.reload;assert @applicant.has_role?('mentee');assert @applicant.has_role?('mentor');assert_not @applicant.platform_admin?
    assert @applicant.mentor_profile.is_verified?;assert_equal 'Technology Educator',@applicant.mentor_profile.title
    assert_not @applicant.mentor_profile.is_published?;assert_not @applicant.mentor_profile.accepting_bookings?
    get '/api/v1/platform/home';assert_not_includes response.parsed_body['mentors'].map{|m|m['id']},@applicant.id
    get '/api/v1/mentors';assert_not_includes response.parsed_body['mentors'].map{|m|m['id']},@applicant.id
    get "/api/v1/mentors/#{@applicant.id}";assert_response :not_found
    patch '/api/v1/me/mentor_profile',params:{is_published:true},headers:auth_headers(@applicant),as: :json;assert_response :ok
    get "/api/v1/mentors/#{@applicant.id}";assert_response :ok
    get '/api/v1/platform/home';assert_includes response.parsed_body['mentors'].map{|m|m['id']},@applicant.id

    assert AdministrationAudit.exists?(action:'mentor_application.approved',target_id:item.id)
    assert Notification.exists?(user:@applicant,title:'Mentor Application Approved')
    review(item);assert_response :unprocessable_entity
  end
  test 'request changes requires feedback permits resubmission and rejection locks application' do
    item=complete;submit(item)
    review(item,decision:'changes_requested');assert_response :unprocessable_entity
    review(item,decision:'changes_requested',note:'Please clarify your experience.');assert_response :ok
    assert item.reload.editable?
    submit(item);assert_response :ok;assert_empty item.reload.review_note
    review(item,decision:'rejected',note:'Requirements were not met.');assert_response :ok
    assert_equal 'rejected',item.reload.status;assert_nil @applicant.mentor_profile
    submit(item);assert_response :unprocessable_entity
  end
  test 'review privileges self approval inactive applicants and stale decisions are protected' do
    item=complete;submit(item)
    get '/api/v1/admin/mentor-applications',headers:auth_headers(@other);assert_response :forbidden
    get "/api/v1/admin/mentor-applications/#{application(@other).id}",headers:auth_headers(@admin);assert_response :not_found
    @admin.role.update!(permissions:['users.read'])
    get '/api/v1/admin/mentor-applications',headers:auth_headers(@admin);assert_response :ok;assert_not response.parsed_body['can_review']
    review(item);assert_response :forbidden
    @admin.role.update!(permissions:['users.read','users.update'])
    review(item,lock_version:0);assert_response :conflict
    @applicant.update!(is_active:false);review(item);assert_response :unprocessable_entity
    own=complete(@admin);submit(own,@admin);assert_response :ok
    review(own);assert_response :forbidden
  end
  test 'upload rejects spoofed types unknown document kinds oversize files and stale revisions' do
    item=application
    fake=Rack::Test::UploadedFile.new(StringIO.new('not a PDF'),'application/pdf',original_filename:'fake.pdf')
    post '/api/v1/me/mentor-application/documents/identity_document',params:{file:fake,lock_version:item.lock_version},headers:auth_headers(@applicant);assert_response :unprocessable_entity
    real=Rack::Test::UploadedFile.new(file_fixture('branding.png'),'image/png')
    post '/api/v1/me/mentor-application/documents/password',params:{file:real,lock_version:item.lock_version},headers:auth_headers(@applicant);assert_response :unprocessable_entity
    large=Rack::Test::UploadedFile.new(StringIO.new('a'*(5.megabytes+1)),'application/pdf',original_filename:'large.pdf')
    post '/api/v1/me/mentor-application/documents/identity_document',params:{file:large,lock_version:item.lock_version},headers:auth_headers(@applicant);assert_response :unprocessable_entity
    item.update!(headline:'Revision changed')
    post '/api/v1/me/mentor-application/documents/identity_document',params:{file:real,lock_version:0},headers:auth_headers(@applicant);assert_response :conflict
  end
end
