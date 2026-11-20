require 'test_helper'
class Api::V1::MentorApplicationFormTest < ActionDispatch::IntegrationTest
  setup do
    @user=create_mentee(email:'application-v2@example.test')
    @admin=create_user(role:create_role('admin'),email:'application-v2-reviewer@example.test')
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS)
  end
  def draft
    get '/api/v1/me/mentor-application',headers:auth_headers(@user);assert_response :ok
    @application=MentorApplication.find(response.parsed_body['id'])
  end
  def fields
    {full_name:'Application Contact Name',contact_email:'contact-v2@example.test',phone_number:'+256700123456',location:'Kampala',gender:'prefer_not_to_say',date_of_birth:'1995-06-15',highest_qualification:'bachelors',headline:'Technology Educator',organization:'Learning Centre',experience_range:'6-10',expertise_tags:['Education','Technology'],target_learners:['primary','university'],background:Array.new(110,'learning').join(' '),conduct_accepted:true,safeguarding_accepted:true,terms_accepted:true,references_text:'School coordinator, permission to contact granted.'}
  end
  def save(values=fields)
    patch '/api/v1/me/mentor-application',params:{application:values,lock_version:@application.reload.lock_version},headers:auth_headers(@user),as: :json
  end
  def attach_requirements
    MentorApplication::DOCUMENTS.each{|kind|@application.reload.public_send(kind).attach(io:StringIO.new("%PDF-1.4\nEvidence\n%%EOF"),filename:'evidence.pdf',content_type:'application/pdf')}
    @application.reload.profile_photo.attach(io:File.open(Rails.root.join('test/fixtures/files/branding.png')),filename:'photo.png',content_type:'image/png')
    @application.reload
  end
  def submit
    post '/api/v1/me/mentor-application/submit',params:{lock_version:@application.reload.lock_version,policy_version:MentorApplication::POLICY_VERSION},headers:auth_headers(@user),as: :json
  end
  test 'new drafts prefill account contact and save every reference field without changing login credentials' do
    draft
    assert_equal 2,response.parsed_body['form_version'];assert_equal @user.full_name,response.parsed_body['full_name'];assert_equal @user.email,response.parsed_body['contact_email']
    assert_nil response.parsed_body['profile_photo']
    save;assert_response :ok
    fields.each do |key,value|
      next if key==:date_of_birth
      assert_equal value,response.parsed_body[key.to_s],key.to_s
    end
    assert_equal '1995-06-15',response.parsed_body['date_of_birth'];assert_equal 'Education, Technology',response.parsed_body['expertise'];assert_equal 6,response.parsed_body['years_of_experience']
    assert_equal 'application-v2@example.test',@user.reload.email
    assert_equal 'Mentee User',@user.full_name
    assert_not @user.has_role?('mentor')
  end
  test 'submit validates the photo bio learner groups terms and documents before review and approval copies only the portrait' do
    draft;save;assert_response :ok
    submit;assert_response :unprocessable_entity;assert_includes response.body,'Profile photo is required'
    @user.avatar.attach(io:File.open(Rails.root.join('test/fixtures/files/branding.png')),filename:'account-photo.png',content_type:'image/png')
    attach_requirements
    save(fields.merge(terms_accepted:false));assert_response :ok;submit;assert_response :unprocessable_entity;assert_includes response.body,'Terms of Service'
    save(fields.merge(background:'Too short'));assert_response :ok;submit;assert_response :unprocessable_entity;assert_includes response.body,'100–300 words'
    save;assert_response :ok;submit;assert_response :ok
    get "/api/v1/admin/mentor-applications/#{@application.id}",headers:auth_headers(@admin);assert_response :ok
    assert_equal 'Kampala',response.parsed_body['location'];assert_equal ['primary','university'],response.parsed_body['target_learners'];assert response.parsed_body['terms_accepted']
    post "/api/v1/admin/mentor-applications/#{@application.id}/review",params:{lock_version:@application.reload.lock_version,decision:'approved'},headers:auth_headers(@admin),as: :json;assert_response :ok
    profile=@user.reload.mentor_profile
    assert profile.is_verified?;assert_not profile.is_published?
    assert_equal @application.profile_photo.blob_id,profile.avatar.blob_id
    assert_equal ['Education','Technology'],profile.skills.order(:name).pluck(:name)
    get '/api/v1/me/mentor_profile',headers:auth_headers(@user);assert_response :ok;assert_includes response.parsed_body['avatar_url'],'photo.png';assert_not_includes response.parsed_body['avatar_url'],'account-photo.png'
    assert_equal 'account-photo.png',@user.avatar.filename.to_s
    assert_equal @user.id,@application.user_id
    assert_not_equal @application.identity_document.blob_id,profile.avatar.blob_id
  end
  test 'invalid snapshot dates email telephone arrays ranges and qualifications are rejected and cannot downgrade the form' do
    draft
    [{date_of_birth:'2026-02-30'},{date_of_birth:1.year.from_now.to_date.iso8601},{contact_email:'wrong'},{phone_number:'123'},{gender:'invalid'},{highest_qualification:'invalid'},{experience_range:'invalid'},{expertise_tags:['a','a']},{target_learners:['not-supported']},{target_learners:'primary'}].each do |invalid|
      save(fields.merge(invalid));assert_response :unprocessable_entity,invalid.inspect
    end
    save(fields.merge(form_version:1,status:'approved',user_id:@admin.id));assert_response :ok
    assert_equal 2,@application.reload.form_version;assert_equal 'draft',@application.status;assert_equal @user.id,@application.user_id
    save({years_of_experience:80});assert_response :unprocessable_entity
  end
  test 'legacy submissions remain reviewable and saving new fields upgrades an old draft' do
    legacy=MentorApplication.create!(user:@user,headline:'Legacy educator',background:'Legacy background',expertise:'Education',motivation:'Support learners',references_text:'School coordinator',conduct_accepted:true,safeguarding_accepted:true)
    @application=legacy
    MentorApplication::DOCUMENTS.each{|kind|legacy.reload.public_send(kind).attach(io:StringIO.new("%PDF-1.4\nEvidence\n%%EOF"),filename:'old.pdf',content_type:'application/pdf')}
    submit;assert_response :ok;assert_equal 1,legacy.reload.form_version
    post "/api/v1/admin/mentor-applications/#{legacy.id}/review",params:{lock_version:legacy.reload.lock_version,decision:'changes_requested',note:'Please update your details.'},headers:auth_headers(@admin),as: :json;assert_response :ok
    save;assert_response :ok;assert_equal 2,legacy.reload.form_version
    submit;assert_response :unprocessable_entity;assert_includes response.body,'Profile photo is required'
  end
end
