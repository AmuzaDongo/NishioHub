require 'test_helper'
require_relative '../support/integration_test_helpers'
class IntegrationProbeTest < ActiveSupport::TestCase
  include IntegrationTestHelpers
  test 'every catalog provider uses fixed HTTPS endpoints and verifies a meaningful success payload' do
    payloads={'pesapal'=>{'token'=>'temporary'},'mtn_momo'=>{'access_token'=>'temporary'},'sms_uganda'=>{'UserData'=>{}},'sendgrid'=>{'scopes'=>[]},'google_analytics'=>{},'google_drive'=>{'user'=>{}},'youtube'=>{'items'=>[]},'openai'=>{'data'=>[]},'zoom'=>{'id'=>'user'},'microsoft365'=>{'id'=>'user'},'slack'=>{'ok'=>true},'sentry'=>[]}
    IntegrationCatalog::PROVIDERS.each do |provider|
      c=provider[:fields].to_h{|f|[f[:key],f[:key]=='username' ? 'account' : 'private-test-value']}
      captured=nil;probe=IntegrationProbe.new
      with_provider_stub(probe,:request,->(url,method,headers,payload){captured={url:url,method:method,headers:headers,payload:payload};[200,payloads.fetch(provider[:key])]}) do
        result=probe.call(provider[:key],c,'live')
        assert result[:success],provider[:key]
      end
      assert_equal 'https',URI(captured[:url]).scheme
      assert_not_includes captured[:url],'private-test-value'
      assert_includes [:get,:post],captured[:method]
      assert_not probe.valid_payload?(provider[:key],nil)
    end
  end
  test 'errors redirects rate limits and provider HTTP 200 application errors do not verify access' do
    probe=IntegrationProbe.new
    [[401,{},false],[302,{},false],[429,{},false],[200,{'ok'=>false},false],[200,{'ok'=>true},true]].each do |code,payload,success|
      with_provider_stub(probe,:request,[code,payload]) do
        assert_equal success,probe.call('slack',{'access_token'=>'private'},'live')[:success]
      end
    end
    with_provider_stub(probe,:request,->(*_args){raise Net::ReadTimeout}) do
      result=probe.call('slack',{'access_token'=>'private'},'live')
      assert_not result[:success]
      assert_includes result[:message],'timed out'
      assert_not_includes result[:message],'private'
    end
  end
end
