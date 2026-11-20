require 'test_helper'
class Api::V1::PublicProgramDetailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS)
    @admin=create_user(role:create_role('admin'),email:'program-page-admin@example.test')
    @content={'benefits'=>['Build confidence'],'curriculum'=>[{'title'=>'Study Skills','description'=>'Explore useful study habits.','image_url'=>''}],
      'requirements'=>['School or guardian involvement where needed.'],'faqs'=>[{'question'=>'How do we join?','answer'=>'Send an inquiry to our team.'}],
      'schedule'=>[{'title'=>'Weekly Workshops','description'=>'Dates are confirmed with participating schools.'}],
      'duration_label'=>'12 weeks','cost_label'=>'Free','certificate_label'=>'Participation Certificate','intro_video_url'=>''}
    @program=PlatformProgram.create!(title:'Young Learners Mentorship',description:'Learning with caring mentors.',status:'active',audience_stages:['primary'],public_details:@content)
  end
  test 'public detail returns approved content and only assigned active verified published mentors without private information' do
    visible=create_mentor(email:'public-page-mentor@example.test',full_name:'Public Mentor')
    hidden=create_mentor(email:'hidden-page-mentor@example.test');hidden.mentor_profile.update!(is_published:false)
    unverified=create_mentor(email:'unverified-page-mentor@example.test');unverified.mentor_profile.update!(is_verified:false)
    inactive=create_mentor(email:'inactive-page-mentor@example.test');inactive.update!(is_active:false)
    removed=create_mentor(email:'removed-page-mentor@example.test')
    [visible,hidden,unverified,inactive].each{|user|ProgramMentorAssignment.create!(platform_program:@program,user:user)}
    ProgramMentorAssignment.create!(platform_program:@program,user:removed,is_active:false)
    get "/api/v1/platform/programs/#{@program.id}"
    assert_response :ok
    assert_equal @content,response.parsed_body['public_details']
    assert_equal [visible.id],response.parsed_body['mentors'].map{|m|m['id']}
    assert_equal %w[avatar id name title],response.parsed_body['mentors'].first.keys.sort
    assert_not_includes response.body,visible.email
    assert_not_includes response.body,'phone_number'
    assert_equal 'open',response.parsed_body.dig('availability','status')
    get '/api/v1/platform/programs'
    assert_not response.parsed_body['items'].first.key?('public_details')
    assert_not response.parsed_body['items'].first.key?('mentors')
    @program.update!(status:'draft')
    get "/api/v1/platform/programs/#{@program.id}"
    assert_response :not_found
  end
  test 'availability uses platform dates registration windows and actual capacity' do
    today=Time.current.in_time_zone('Africa/Kampala').to_date
    [{registration_starts_on:today+1},{registration_starts_on:nil,registration_ends_on:today-1},{registration_ends_on:nil,ends_on:today-1}].zip(%w[upcoming closed ended]).each do |attrs,status|
      @program.update!(attrs)
      get "/api/v1/platform/programs/#{@program.id}"
      assert_equal status,response.parsed_body.dig('availability','status')
    end
    @program.update!(ends_on:nil,capacity:1)
    member=create_mentee
    ProgramMembership.create!(platform_program:@program,user:member,is_active:true)
    get "/api/v1/platform/programs/#{@program.id}"
    assert_equal 'full',response.parsed_body.dig('availability','status')
    @program.program_memberships.update_all(is_active:false)
    get "/api/v1/platform/programs/#{@program.id}"
    assert_equal 'open',response.parsed_body.dig('availability','status')
  end
  test 'admin content changes are versioned validated and retain data through multipart banner edits' do
    patch "/api/v1/admin/programs/#{@program.id}",headers:auth_headers(@admin),params:{program:{lock_version:@program.lock_version,public_details:@content.merge('cost_label'=>'Contact for pricing')}},as: :json
    assert_response :ok
    assert_equal 'Contact for pricing',@program.reload.public_details['cost_label']
    [{curriculum:[{title:'Bad',description:'Bad',image_url:'javascript:alert(1)'}]}, {intro_video_url:'https://example.test/unsafe.html'},{unknown_field:'private'}, {faqs:'bad'},{benefits:['x'*121]},{curriculum:[{title:'Missing details'}]}].each do |invalid|
      assert_no_changes ->{@program.reload.public_details} do
        patch "/api/v1/admin/programs/#{@program.id}",headers:auth_headers(@admin),params:{program:{lock_version:@program.lock_version,public_details:@content.merge(invalid.stringify_keys)}},as: :json
        assert_response :unprocessable_entity
      end
    end
    upload=fixture_file_upload('branding.png','image/png')
    patch "/api/v1/admin/programs/#{@program.id}",headers:auth_headers(@admin),params:{program:{lock_version:@program.lock_version,banner:upload,public_details_json:@content.to_json}}
    assert_response :ok
    assert_equal @content,@program.reload.public_details
    assert @program.banner.attached?
    patch "/api/v1/admin/programs/#{@program.id}",headers:auth_headers(@admin),params:{program:{lock_version:@program.lock_version,public_details_json:'invalid'}}
    assert_response :unprocessable_entity
    patch "/api/v1/admin/programs/#{@program.id}",headers:auth_headers(create_mentee(email:'blocked-page-editor@example.test')),params:{program:{lock_version:@program.lock_version,public_details:{}}},as: :json
    assert_response :forbidden
  end
  test 'school inquiries preserve the request type without creating an enrollment or allowing forged reference data' do
    payload={name:'School Coordinator',email:'school-inquiry@example.test',message:'Please share school participation information.',interest_type:'school',submission_key:SecureRandom.uuid}
    assert_no_difference('ProgramMembership.count') do
      post "/api/v1/platform/programs/#{@program.id}/inquiries",params:{inquiry:payload},as: :json
      assert_response :created
    end
    inquiry=PublicInquiry.last
    assert_equal({'id'=>@program.id,'title'=>@program.title,'interest_type'=>'school'},inquiry.program_details)
    assert_no_difference('PublicInquiry.count') do
      post "/api/v1/platform/programs/#{@program.id}/inquiries",params:{inquiry:payload},as: :json
      assert_response :ok
      post "/api/v1/platform/programs/#{@program.id}/inquiries",params:{inquiry:payload.merge(interest_type:'individual')},as: :json
      assert_response :conflict
      post "/api/v1/platform/programs/#{@program.id}/inquiries",params:{inquiry:payload.merge(interest_type:'administrator',submission_key:SecureRandom.uuid)},as: :json
      assert_response :unprocessable_entity
    end
  end
end
