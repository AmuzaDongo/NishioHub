require 'test_helper'
class Api::V1::PublicProgramsControllerTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS)
    @admin=create_user(role:create_role('admin'),email:'program-discovery-admin@example.test')
    @program=PlatformProgram.create!(title:'Young Learners',description:'Build confidence and digital skills.',status:'active',audience_stages:%w[primary secondary],themes:%w[digital_skills academic_support],featured:true,target_audience:'School learners',objectives:['Build practical skills'])
    @other=PlatformProgram.create!(title:'Leadership Program',status:'active',audience_stages:['professionals'],themes:['leadership'])
    @draft=PlatformProgram.create!(title:'Private Draft',status:'draft',audience_stages:['primary'])
    @archived=PlatformProgram.create!(title:'Archived Program',status:'archived')
  end
  test 'public listing supports stage theme search featured and stable pagination while keeping drafts private' do
    get '/api/v1/platform/programs'
    assert_response :ok
    assert_equal [@program.id,@other.id],response.parsed_body['items'].map{|p|p['id']}
    assert_not_includes response.body,'enrolled'
    assert_not_includes response.body,@admin.email
    [{stage:'primary'},{theme:'digital_skills'},{q:'School learners'},{featured:true}].each do |filters|
      get '/api/v1/platform/programs',params:filters
      assert_response :ok
      assert_equal [@program.id],response.parsed_body['items'].map{|p|p['id']}
    end
    get '/api/v1/platform/programs',params:{q:'%'}
    assert_empty response.parsed_body['items']
    get '/api/v1/platform/programs',params:{stage:'primary',theme:'leadership'}
    assert_empty response.parsed_body['items']
    7.times{|i|PlatformProgram.create!(title:"Public Program #{i}",status:'active')}
    get '/api/v1/platform/programs',params:{per_page:4,page:2}
    assert_equal 4,response.parsed_body['items'].size
    assert_equal 9,response.parsed_body.dig('meta','total')
    [{stage:'bad'},{theme:'bad'},{featured:'bad'},{page:'1abc'},{per_page:100}].each do |filters|
      get '/api/v1/platform/programs',params:filters
      assert_response :unprocessable_entity
    end
  end
  test 'public details whitelist fields and hide inactive programs including from admins' do
    get "/api/v1/platform/programs/#{@program.id}"
    assert_response :ok
    assert_equal ['Build practical skills'],response.parsed_body['objectives']
    assert_equal %w[primary secondary],response.parsed_body['audience_stages']
    assert_not_includes response.body,'created_by'
    [@draft,@archived].each do |program|
      get "/api/v1/platform/programs/#{program.id}",headers:auth_headers(@admin)
      assert_response :not_found
    end
  end
  test 'admins can edit tags and feature status with permission version and field validation' do
    patch "/api/v1/admin/programs/#{@program.id}",headers:auth_headers(@admin),params:{program:{audience_stages:['career'],themes:['innovation'],featured:false,lock_version:@program.lock_version}},as: :json
    assert_response :ok
    assert_equal ['career'],response.parsed_body['audience_stages']
    assert_not response.parsed_body['featured']
    [{audience_stages:['unknown']},{themes:['innovation','innovation']},{audience_stages:'primary'},{themes:nil},{featured:'invalid'}].each do |invalid|
      patch "/api/v1/admin/programs/#{@program.id}",headers:auth_headers(@admin),params:{program:invalid.merge(lock_version:@program.reload.lock_version)},as: :json
      assert_response :unprocessable_entity
    end
    patch "/api/v1/admin/programs/#{@program.id}",headers:auth_headers(create_mentee),params:{program:{featured:true,lock_version:@program.reload.lock_version}},as: :json
    assert_response :forbidden
    @admin.role.update!(permissions:['dashboard.read'])
    patch "/api/v1/admin/programs/#{@program.id}",headers:auth_headers(@admin),params:{program:{featured:true,lock_version:@program.lock_version}},as: :json
    assert_response :forbidden
  end
  test 'program inquiries preserve server-owned program references notify staff and deduplicate retries without enrolling' do
    payload={name:'Jane Coordinator',email:'JANE@example.test',message:'Please share eligibility and enrollment information.',submission_key:SecureRandom.uuid,program_details:{id:@draft.id,title:'Forged'}}
    assert_no_difference('ProgramMembership.count') do
      assert_difference('PublicInquiry.count') do
        post "/api/v1/platform/programs/#{@program.id}/inquiries",params:{inquiry:payload},as: :json
        assert_response :created
      end
    end
    inquiry=PublicInquiry.last
    assert_equal({'id'=>@program.id,'title'=>@program.title},inquiry.program_details)
    assert_equal 'jane@example.test',inquiry.email
    assert_equal inquiry.reference,response.parsed_body['reference']
    assert Notification.exists?(user:@admin,title:'New Program Inquiry')
    assert_no_difference('PublicInquiry.count') do
      post "/api/v1/platform/programs/#{@program.id}/inquiries",params:{inquiry:payload},as: :json
      assert_response :ok
      post "/api/v1/platform/programs/#{@other.id}/inquiries",params:{inquiry:payload},as: :json
      assert_response :conflict
      post "/api/v1/platform/programs/#{@draft.id}/inquiries",params:{inquiry:payload.merge(submission_key:SecureRandom.uuid)},as: :json
      assert_response :not_found
      post "/api/v1/platform/programs/#{@program.id}/inquiries",params:{inquiry:payload.merge(email:'bad',submission_key:SecureRandom.uuid)},as: :json
      assert_response :unprocessable_entity
    end
    get '/api/v1/admin/inquiries',headers:auth_headers(@admin)
    assert_equal @program.id,response.parsed_body['items'].first.dig('program_details','id')
  end
end
