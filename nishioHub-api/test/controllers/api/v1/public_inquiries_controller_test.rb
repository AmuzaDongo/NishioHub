require 'test_helper'
class Api::V1::PublicInquiriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS)
    @admin=create_user(role:create_role('admin'),email:'contact-admin@example.test')
    @learner=create_mentee
    @payload={name:'School Coordinator',email:'COORDINATOR@example.test',subject:'School partnership request',category:'partnership',message:'We would like to discuss a mentorship program for our school.'}
  end
  test 'anonymous request persists yields reference and alerts authorized staff without sending email' do
    before_emails=ActionMailer::Base.deliveries.size
    assert_difference('PublicInquiry.count',1) do
      post '/api/v1/platform/inquiries',params:{inquiry:@payload.merge(reviewed:true)},as: :json
      assert_response :created
    end
    inquiry=PublicInquiry.last
    assert_equal inquiry.reference,response.parsed_body['reference']
    assert_equal 'coordinator@example.test',inquiry.email
    assert_not inquiry.reviewed
    assert_not_equal '127.0.0.1',inquiry.ip_digest
    assert_equal before_emails,ActionMailer::Base.deliveries.size
    assert Notification.exists?(user:@admin,source_key:"public-inquiry-#{inquiry.id}")
    assert_not_includes response.body,@payload[:message]
  end
  test 'validation and atomic IP throttle prevent invalid or excessive submissions' do
    post '/api/v1/platform/inquiries',params:{inquiry:@payload.merge(email:'bad',message:'short')},as: :json
    assert_response :unprocessable_entity
    assert_equal 0,PublicInquiry.count
    5.times do
      post '/api/v1/platform/inquiries',params:{inquiry:@payload},as: :json
      assert_response :created
    end
    assert_no_difference('PublicInquiry.count') do
      post '/api/v1/platform/inquiries',params:{inquiry:@payload},as: :json
      assert_response :too_many_requests
    end
  end
  test 'request inbox and review require administrative system permission' do
    post '/api/v1/platform/inquiries',params:{inquiry:@payload},as: :json
    inquiry=PublicInquiry.last
    get '/api/v1/admin/inquiries'
    assert_response :unauthorized
    get '/api/v1/admin/inquiries',headers:auth_headers(@learner)
    assert_response :forbidden
    get '/api/v1/admin/inquiries',headers:auth_headers(@admin)
    assert_response :ok
    assert_equal inquiry.id,response.parsed_body['items'].first['id']
    assert_not_includes response.body,'ip_digest'
    patch "/api/v1/admin/inquiries/#{inquiry.id}",headers:auth_headers(@admin),params:{reviewed:true},as: :json
    assert_response :no_content
    assert inquiry.reload.reviewed
    @admin.role.update!(permissions:['dashboard.read'])
    get '/api/v1/admin/inquiries',headers:auth_headers(@admin)
    assert_response :forbidden
  end
end
