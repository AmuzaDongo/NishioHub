require 'test_helper'

class Api::V1::EventHostingRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS)
    @admin=create_user(role:create_role('admin'),email:'hosting-admin@example.test')
    @super_admin=create_user(role:create_role('super_admin'),email:'hosting-super@example.test')
    @learner=create_mentee
    @mentor=create_user(role:create_role('mentor'),email:'hosting-mentor@example.test')
    @payload={name:'GreenTech Uganda',email:'EVENTS@example.test',phone_number:'0772 345 678',event_type:'workshop',title:'Digital Skills Workshop',description:'A practical digital skills workshop for learners and teachers.',preferred_date:2.weeks.from_now.to_date.iso8601,location:'Kampala',additional_information:'Please provide projector access.',terms_accepted:true,submission_key:SecureRandom.uuid}
  end

  test 'authenticated mentor submission stores structured details alerts staff and does not publish an event' do
    assert_no_difference('Event.count') do
      assert_difference('PublicInquiry.count',1) { submit(@payload.merge(reviewed:true,category:'general',policy_version:'fake')) }
    end
    assert_response :created
    inquiry=PublicInquiry.last
    assert_equal 'event_hosting',inquiry.category
    assert_equal 'events@example.test',inquiry.email
    assert_equal '+256772345678',inquiry.event_details['phone_number']
    assert_equal '2026-11-15',inquiry.event_details['policy_version']
    assert_equal @payload[:preferred_date],inquiry.event_details['preferred_date']
    assert_equal @mentor.id,inquiry.event_details['submitted_by_id']
    assert_not inquiry.reviewed
    assert_equal inquiry.reference,response.parsed_body['reference']
    [@admin,@super_admin].each{|user|assert Notification.exists?(user:user,title:'New Event Hosting Request',href:'/admin/inquiries')}
    assert_not_includes response.body,@payload[:email]
  end

  test 'only authenticated eligible roles can submit including additional school or organization roles' do
    assert_no_difference(['PublicInquiry.count','Notification.count']) do
      submit(@payload,nil)
      assert_response :unauthorized
      [@learner,@admin,@super_admin].each do |user|
        submit(@payload,user)
        assert_response :forbidden
      end
      post '/api/v1/platform/event-hosting-requests',params:{event_request:@payload},headers:{'Authorization'=>'Bearer invalid'},as: :json
      assert_response :unauthorized
    end
    %w[school organization].each do |role|
      user=create_user(role:create_role(role),email:"hosting-#{role}@example.test")
      submit(@payload.merge(submission_key:SecureRandom.uuid,submitted_by_id:@admin.id),user)
      assert_response :created
      assert_equal user.id,PublicInquiry.last.event_details['submitted_by_id']
    end
    @learner.additional_roles<<create_role('organization')
    submit(@payload.merge(submission_key:SecureRandom.uuid),@learner)
    assert_response :created
  end

  test 'inactive accounts and revoked hosting roles cannot submit' do
    headers=auth_headers(@mentor)
    @mentor.update!(is_active:false)
    assert_no_difference('PublicInquiry.count') do
      post '/api/v1/platform/event-hosting-requests',params:{event_request:@payload},headers:headers,as: :json
      assert_response :unauthorized
    end
    @mentor.update!(is_active:true,role:@learner.role)
    assert_no_difference('PublicInquiry.count') do
      submit(@payload)
      assert_response :forbidden
    end
  end

  test 'another account cannot reuse a submission key and contact form cannot bypass hosting authorization' do
    submit(@payload)
    owner_reference=response.parsed_body['reference']
    organization=create_user(role:create_role('organization'),email:'hosting-other@example.test')
    assert_no_difference('PublicInquiry.count') do
      submit(@payload,organization)
      assert_response :conflict
      assert_not_includes response.body,owner_reference
      post '/api/v1/platform/inquiries',params:{inquiry:{name:'Bypass',email:'bypass@example.test',subject:'Event bypass',message:'Attempt to request an event through the contact form.',category:'event_hosting',submission_key:SecureRandom.uuid}},as: :json
      assert_response :unprocessable_entity
    end
  end

  test 'retries return the same reference without duplicate requests notifications or consuming throttle allowance' do
    submit(@payload);reference=response.parsed_body['reference']
    6.times do
      assert_no_difference(['PublicInquiry.count','Notification.count']) { submit(@payload) }
      assert_response :ok
      assert_equal reference,response.parsed_body['reference']
    end
    submit(@payload.merge(title:'A different event'))
    assert_response :conflict
    assert_equal 1,PublicInquiry.count
  end

  test 'event type phone date consent length and request key are validated on the server' do
    [{event_type:'unknown'},{phone_number:'+25677'},{preferred_date:'2020-01-01'},{preferred_date:'2026-02-30'},{terms_accepted:false},{description:'short'},{description:'x'*501},{location:''},{additional_information:'x'*301},{submission_key:'not-a-uuid'},{email:'invalid'}].each do |invalid|
      assert_no_difference('PublicInquiry.count') { submit(@payload.merge(invalid)) }
      assert_response :unprocessable_entity,invalid.inspect
    end
    post '/api/v1/platform/event-hosting-requests',params:{event_request:'not an object'},headers:auth_headers(@mentor),as: :json
    assert_response :unprocessable_entity
  end

  test 'contact and event requests share the same atomic rate limit' do
    5.times { submit(@payload.merge(submission_key:SecureRandom.uuid));assert_response :created }
    assert_no_difference('PublicInquiry.count') { submit(@payload.merge(submission_key:SecureRandom.uuid)) }
    assert_response :too_many_requests
    post '/api/v1/platform/inquiries',params:{inquiry:{name:'School',email:'school@example.test',subject:'Partnership',message:'Please contact us about a school partnership.',category:'partnership'}},as: :json
    assert_response :too_many_requests
  end

  test 'admin and super admin can view requests but must use event decision actions' do
    submit(@payload);inquiry=PublicInquiry.last
    [@admin,@super_admin].each do |user|
      get '/api/v1/admin/inquiries',headers:auth_headers(user)
      assert_response :ok
      assert_equal inquiry.event_details,response.parsed_body['items'].first['event_details']
      assert_not_includes response.body,'submission_key'
      assert_not_includes response.body,'ip_digest'
      patch "/api/v1/admin/inquiries/#{inquiry.id}",headers:auth_headers(user),params:{reviewed:true},as: :json
      assert_response :unprocessable_entity
      assert_not inquiry.reload.reviewed
    end
    get '/api/v1/admin/inquiries',headers:auth_headers(@learner)
    assert_response :forbidden
    get '/api/v1/admin/inquiries'
    assert_response :unauthorized
    @admin.role.update!(permissions:['dashboard.read'])
    get '/api/v1/admin/inquiries',headers:auth_headers(@admin)
    assert_response :forbidden
  end

  private

  def submit(payload,user=@mentor)
    post '/api/v1/platform/event-hosting-requests',params:{event_request:payload},headers:user ? auth_headers(user) : {},as: :json
  end
end
