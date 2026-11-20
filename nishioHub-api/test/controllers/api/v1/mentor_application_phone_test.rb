require 'test_helper'
class Api::V1::MentorApplicationPhoneTest < ActionDispatch::IntegrationTest
  setup do
    @user=create_mentee(email:'application-phone@example.test')
  end
  test 'a locally stored account number can open and save the application without changing account data' do
    @user.update!(phone_number:'0772345678')
    get '/api/v1/me/mentor-application',headers:auth_headers(@user)
    assert_response :ok
    assert_equal '+256772345678',response.parsed_body['phone_number']
    revision=response.parsed_body['lock_version']
    patch '/api/v1/me/mentor-application',params:{application:{headline:'Technology Educator',phone_number:'0772 345 678'},lock_version:revision},headers:auth_headers(@user),as: :json
    assert_response :ok
    assert_equal '+256772345678',response.parsed_body['phone_number']
    assert_equal '0772345678',@user.reload.phone_number
  end
  test 'bad legacy account numbers leave the editable field empty instead of rejecting the application page' do
    @user.update!(phone_number:'not-a-phone')
    get '/api/v1/me/mentor-application',headers:auth_headers(@user)
    assert_response :ok;assert_equal '',response.parsed_body['phone_number']
    patch '/api/v1/me/mentor-application',params:{application:{phone_number:'+254 712 345 678'},lock_version:response.parsed_body['lock_version']},headers:auth_headers(@user),as: :json
    assert_response :ok;assert_equal '+254712345678',response.parsed_body['phone_number']
  end
  test 'invalid application contact numbers still fail with an actionable error' do
    get '/api/v1/me/mentor-application',headers:auth_headers(@user)
    patch '/api/v1/me/mentor-application',params:{application:{phone_number:'123'},lock_version:response.parsed_body['lock_version']},headers:auth_headers(@user),as: :json
    assert_response :unprocessable_entity
    assert_includes response.body,'country code'
  end
end
