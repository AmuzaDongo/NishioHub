require 'test_helper'

class Api::V1::PartnershipRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS)
    @admin=create_user(role:create_role('admin'),email:'partnership-admin@example.test')
    @payload={organization_name:'GreenTech Uganda',name:'Jane Namutebi',contact_role:'Programs Manager',email:'JANE@example.test',phone_number:'0772 345 678',focus:'schools',message:'We would like to partner on mentorship and practical digital skills for our learners.',terms_accepted:true,request_kind:'partnership',submission_key:SecureRandom.uuid}
  end

  test 'public structured partnership persists normalized contacts and notifies staff with retry protection' do
    assert_difference('PublicInquiry.count') { submit; assert_response :created }
    inquiry=PublicInquiry.last
    assert_equal '+256772345678',inquiry.partnership_details['phone_number']
    assert_equal 'jane@example.test',inquiry.email
    assert_equal 'GreenTech Uganda',inquiry.partnership_details['organization_name']
    assert_equal '2026-11-17',inquiry.partnership_details['policy_version']
    assert_not inquiry.reviewed
    assert_equal inquiry.reference,response.parsed_body['reference']
    assert Notification.exists?(user:@admin,title:'New Partnership Request')
    assert_no_difference('PublicInquiry.count') { submit; assert_response :ok }
    assert_no_difference('PublicInquiry.count') { submit(message:'A different proposal cannot reuse the same submission key.'); assert_response :conflict }
    get '/api/v1/admin/inquiries',headers:auth_headers(@admin)
    assert_response :ok
    assert_equal 'Programs Manager',response.parsed_body['items'].first.dig('partnership_details','contact_role')
    assert_not_includes response.body,'ip_digest'
    patch "/api/v1/admin/inquiries/#{inquiry.id}",params:{reviewed:true},headers:auth_headers(@admin),as: :json
    assert_response :no_content
    assert inquiry.reload.reviewed
  end

  test 'invalid contact consent focus payload and length never create a request' do
    [{phone_number:'+25677'},{terms_accepted:false},{focus:'unknown'},{organization_name:'x'},{contact_role:''},{message:'x'*501},{submission_key:'bad'},{email:'bad'},{request_kind:'confirmed'}].each do |invalid|
      assert_no_difference('PublicInquiry.count') { submit(**invalid); assert_response :unprocessable_entity }
    end
    post '/api/v1/platform/partnership-requests',params:{partnership_request:'bad'},as: :json
    assert_response :unprocessable_entity
  end

  test 'meeting requests require a future timezone qualified time and do not create calendar bookings' do
    [nil,'invalid',1.day.ago.iso8601,'2030-01-01T10:00:00'].each do |time|
      assert_no_difference('PublicInquiry.count') { submit(request_kind:'meeting',preferred_at:time); assert_response :unprocessable_entity }
    end
    preferred=2.days.from_now.iso8601
    submit(request_kind:'meeting',preferred_at:preferred)
    assert_response :created
    inquiry=PublicInquiry.last
    assert_equal 'pending',inquiry.status
    assert_equal preferred,inquiry.partnership_details['preferred_at']
    assert_nil inquiry.event_id
    travel 3.days do
      patch "/api/v1/admin/inquiries/#{inquiry.id}",params:{reviewed:true},headers:auth_headers(@admin),as: :json
      assert_response :no_content
    end
  end

  test 'partnership requests share the contact throttle and inbox remains private for other roles' do
    5.times { submit(submission_key:SecureRandom.uuid); assert_response :created }
    assert_no_difference('PublicInquiry.count') { submit(submission_key:SecureRandom.uuid); assert_response :too_many_requests }
    get '/api/v1/admin/inquiries'
    assert_response :unauthorized
    %w[mentee mentor organization].each do |role|
      user=create_user(role:create_role(role),email:"partner-#{role}@example.test")
      get '/api/v1/admin/inquiries',headers:auth_headers(user)
      assert_response :forbidden
    end
    super_admin=create_user(role:create_role('super_admin'),email:'partner-super@example.test')
    get '/api/v1/admin/inquiries',headers:auth_headers(super_admin)
    assert_response :ok
  end

  private
  def submit(**changes)
    post '/api/v1/platform/partnership-requests',params:{partnership_request:@payload.merge(changes)},as: :json
  end
end
