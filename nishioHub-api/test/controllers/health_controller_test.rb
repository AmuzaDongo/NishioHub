require 'test_helper'
class HealthControllerTest < ActionDispatch::IntegrationTest
  test 'readiness verifies database access without authentication or private data' do
    get '/up'
    assert_response :ok
    assert_equal '',response.body
    assert_equal 'no-store',response.headers['Cache-Control']
  end
end
