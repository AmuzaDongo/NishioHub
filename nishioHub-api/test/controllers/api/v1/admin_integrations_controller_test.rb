require 'test_helper'
require_relative '../../../support/integration_test_helpers'
class Api::V1::AdminIntegrationsControllerTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelpers
  ROOT='/api/v1/admin/integrations'
  setup do
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS)
    @admin=create_user(role:create_role('admin'),email:'integration-admin@example.test')
    @super=create_user(role:create_role('super_admin'),email:'integration-super@example.test')
    @learner=create_mentee
    @headers=auth_headers(@admin)
  end
  def save_provider(key='openai',credentials={api_key:'sk-test-private-key'},version=nil,environment='live')
    patch "#{ROOT}/#{key}",headers:@headers,params:{integration:{credentials:credentials,lock_version:version,environment:environment}},as: :json
  end
  def body = response.parsed_body
  def check_provider(key='openai',version=PlatformIntegration.find_by!(provider_key:key).lock_version,result:{success:true,http_status:200,message:'Provider API access verified.'})
    with_provider_stub(IntegrationProbe,:call,result) do
      post "#{ROOT}/#{key}/check",headers:@headers,params:{lock_version:version},as: :json
    end
  end
  test 'catalog is read only available by default and administrator permissions apply' do
    get ROOT
    assert_response :unauthorized
    get ROOT,headers:auth_headers(@learner)
    assert_response :forbidden
    [@admin,@super].each do |user|
      assert_no_difference('PlatformIntegration.count') do
        get ROOT,headers:auth_headers(user)
        assert_response :ok
        assert_equal 12,body['items'].size
        assert_equal 12,body.dig('stats','available')
        assert_equal 0,body.dig('stats','active')
        assert_equal 12,body['categories'].sum{|category|category['count']}
        assert_equal 'private, no-store',response.headers['Cache-Control']
      end
    end
    @admin.role.update!(permissions:['dashboard.read'])
    get ROOT,headers:@headers
    assert_response :ok
    assert_not body.dig('capabilities','manage')
    save_provider
    assert_response :forbidden
    get "#{ROOT}/logs",headers:@headers
    assert_response :ok
    @admin.role.update!(permissions:['system.manage'])
    get ROOT,headers:@headers
    assert_response :forbidden
  end
  test 'credential encryption roundtrip responses logs and audit never expose values' do
    save_provider
    assert_response :ok
    assert_equal 'attention',body['status']
    assert_equal ['api_key'],body['credential_fields']
    row=PlatformIntegration.find_by!(provider_key:'openai')
    assert_not_includes row.encrypted_credentials,'sk-test-private-key'
    assert_equal 'sk-test-private-key',row.credentials['api_key']
    assert_not_includes response.body,'sk-test-private-key'
    assert_not_includes IntegrationLog.all.to_json,'sk-test-private-key'
    assert_not_includes AdministrationAudit.all.to_json,'sk-test-private-key'
    save_provider('openai',{api_key:''},row.lock_version)
    assert_response :ok
    assert_equal 'sk-test-private-key',row.reload.credentials['api_key']
    save_provider('openai',{api_key:'rotated-key'},row.lock_version)
    assert_response :ok
    assert_equal 'rotated-key',row.reload.credentials['api_key']
    assert_equal false,row.verified?
  end
  test 'validations reject unknown providers fields environments missing credentials and stale updates' do
    save_provider('unknown')
    assert_response :not_found
    save_provider('openai',{access_token:'wrong-field'})
    assert_response :unprocessable_entity
    save_provider('pesapal',{consumer_key:'only-one'})
    assert_response :unprocessable_entity
    save_provider('openai',{api_key:"bad\nheader"})
    assert_response :unprocessable_entity
    save_provider('openai',{api_key:'key'},nil,'sandbox')
    assert_response :unprocessable_entity
    save_provider
    assert_response :ok
    save_provider('openai',{api_key:'stale-first-connection'},nil)
    assert_response :conflict
    save_provider('openai',{api_key:'changed'},100)
    assert_response :conflict
    assert_equal 'sk-test-private-key',PlatformIntegration.find_by!(provider_key:'openai').credentials['api_key']
  end
  test 'checks activate pause resume disconnect and invalidate stale checks' do
    save_provider
    check_provider
    assert_response :ok
    assert_equal 'active',body['status']
    assert_equal 'sk-test-private-key',PlatformIntegration.ready_credentials('openai')['api_key']
    version=body['lock_version']
    post "#{ROOT}/openai/check",headers:@headers,params:{lock_version:version},as: :json
    assert_response :too_many_requests
    post "#{ROOT}/openai/status",headers:@headers,params:{action_name:'pause',lock_version:version},as: :json
    assert_response :ok
    assert_equal 'paused',body['status']
    assert_raises(Administration::Rejected){PlatformIntegration.ready_credentials('openai')}
    check_provider
    assert_response :unprocessable_entity
    post "#{ROOT}/openai/status",headers:@headers,params:{action_name:'resume',lock_version:body['lock_version']||PlatformIntegration.first.lock_version},as: :json
    assert_response :ok
    assert_equal 'attention',body['status']
    row=PlatformIntegration.first
    delete "#{ROOT}/openai",headers:@headers,params:{lock_version:row.lock_version}
    assert_response :ok
    assert_equal 'available',body['status']
    assert_nil row.reload.encrypted_credentials
    assert_nil row.last_checked_at
    assert IntegrationLog.exists?(provider_key:'openai',action:'disconnected')
  end
  test 'provider failure is reported accurately and filter counts remain global' do
    save_provider
    check_provider(result:{success:false,http_status:401,message:'Provider could not verify these credentials or required permissions.'})
    assert_response :ok
    assert_equal 'attention',body['status']
    assert_equal 401,body['last_http_status']
    assert IntegrationLog.exists?(outcome:'error',action:'checked')
    get ROOT,headers:@headers,params:{q:'OpenAI',category:'other'}
    assert_response :ok
    assert_equal ['openai'],body['items'].map{|item|item['key']}
    assert_equal 12,body.dig('stats','total')
    get "#{ROOT}/logs",headers:@headers,params:{provider:'openai',outcome:'error'}
    assert_response :ok
    assert_equal 1,body.dig('meta','total')
    assert_equal 'checked',body['items'].first['action']
    get ROOT,headers:@headers,params:{category:'invalid'}
    assert_response :unprocessable_entity
    get "#{ROOT}/logs",headers:@headers,params:{page:'1junk'}
    assert_response :unprocessable_entity
  end
  test 'credential changes and revoked permission during a probe cannot activate a connection' do
    save_provider
    replacement=->(*_args){PlatformIntegration.first.update!(verified:false,encrypted_credentials:nil);{success:true,http_status:200,message:'Provider API access verified.'}}
    with_provider_stub(IntegrationProbe,:call,replacement) do
      post "#{ROOT}/openai/check",headers:@headers,params:{lock_version:PlatformIntegration.first.lock_version},as: :json
    end
    assert_response :conflict
    assert_not PlatformIntegration.first.verified?
    save_provider('openai',{api_key:'restored'},PlatformIntegration.first.lock_version)
    replacement=->(*_args){@admin.role.update!(permissions:['dashboard.read']);{success:true,http_status:200,message:'Provider API access verified.'}}
    with_provider_stub(IntegrationProbe,:call,replacement) do
      post "#{ROOT}/openai/check",headers:@headers,params:{lock_version:PlatformIntegration.first.lock_version},as: :json
    end
    assert_response :forbidden
    assert_not PlatformIntegration.first.verified?
  end
  test 'deactivation while checking prevents an integration from becoming active' do
    save_provider
    replacement=->(*_args){@admin.update!(is_active:false);{success:true,http_status:200,message:'Provider API access verified.'}}
    with_provider_stub(IntegrationProbe,:call,replacement) do
      post "#{ROOT}/openai/check",headers:@headers,params:{lock_version:PlatformIntegration.first.lock_version},as: :json
    end
    assert_response :forbidden
    assert_not PlatformIntegration.first.verified?
  end

end
