require 'net/http'
require 'base64'
require 'json'
class IntegrationProbe
  class InvalidResponse < StandardError;end
  def self.call(key,credentials,environment='live')
    new.call(key,credentials,environment)
  end
  def call(key,c,environment)
    url,method,headers,payload=case key
    when 'pesapal'
      host=environment=='sandbox' ? 'https://cybqa.pesapal.com/pesapalv3' : 'https://pay.pesapal.com/v3'
      ["#{host}/api/Auth/RequestToken",:post,{},c.slice('consumer_key','consumer_secret')]
    when 'mtn_momo'
      host=environment=='sandbox' ? 'https://sandbox.momodeveloper.mtn.com' : 'https://proxy.momoapi.mtn.com'
      ["#{host}/collection/token/",:post,{'Authorization'=>"Basic #{Base64.strict_encode64("#{c['api_user']}:#{c['api_key']}")}",'Ocp-Apim-Subscription-Key'=>c['subscription_key']},nil]
    when 'sms_uganda'
      host=environment=='sandbox' ? 'api.sandbox.africastalking.com' : 'api.africastalking.com'
      ["https://#{host}/version1/user?#{URI.encode_www_form(username:c['username'])}",:get,{'apiKey'=>c['api_key']},nil]
    else
      endpoints={'sendgrid'=>'https://api.sendgrid.com/v3/scopes','google_analytics'=>'https://analyticsadmin.googleapis.com/v1beta/accountSummaries?pageSize=1',
        'google_drive'=>'https://www.googleapis.com/drive/v3/about?fields=user','youtube'=>'https://www.googleapis.com/youtube/v3/channels?part=id&mine=true&maxResults=1',
        'openai'=>'https://api.openai.com/v1/models','zoom'=>'https://api.zoom.us/v2/users/me','microsoft365'=>'https://graph.microsoft.com/v1.0/me?$select=id',
        'slack'=>'https://slack.com/api/auth.test','sentry'=>'https://sentry.io/api/0/organizations/?per_page=1'}
      [endpoints.fetch(key),key=='slack' ? :post : :get,{'Authorization'=>"Bearer #{c['api_key']||c['access_token']}"},nil]
    end
    code,data=request(url,method,headers,payload)
    valid=code.between?(200,299)&&valid_payload?(key,data)
    {success:valid,http_status:code,message:valid ? 'Provider API access verified.' : code==429 ? 'Provider rate limit reached. Retry later.' : code.between?(300,399) ? 'Provider redirected the check. Connection was not verified.' : 'Provider could not verify these credentials or required permissions.'}
  rescue Net::OpenTimeout,Net::ReadTimeout,Timeout::Error
    {success:false,http_status:nil,message:'Provider check timed out. Retry later.'}
  rescue SocketError,IOError,SystemCallError,OpenSSL::SSL::SSLError,Net::HTTPBadResponse,Net::ProtocolError,InvalidResponse,JSON::ParserError
    {success:false,http_status:nil,message:'Provider could not be reached securely or returned an invalid response.'}
  end
  def valid_payload?(key,data)
    case key
    when 'pesapal' then data.is_a?(Hash)&&data['token'].present?&&data['error'].blank?
    when 'mtn_momo' then data.is_a?(Hash)&&data['access_token'].present?
    when 'slack' then data.is_a?(Hash)&&data['ok']==true
    when 'openai' then data.is_a?(Hash)&&data['data'].is_a?(Array)
    when 'sendgrid' then data.is_a?(Hash)&&data['scopes'].is_a?(Array)
    when 'google_drive' then data.is_a?(Hash)&&data['user'].is_a?(Hash)
    when 'google_analytics' then data.is_a?(Hash)&&!data.key?('error')
    when 'youtube' then data.is_a?(Hash)&&data['items'].is_a?(Array)
    when 'sms_uganda' then data.is_a?(Hash)&&data['UserData'].is_a?(Hash)
    when 'zoom','microsoft365' then data.is_a?(Hash)&&data['id'].present?
    when 'sentry' then data.is_a?(Array)
    else false
    end
  end
  def request(url,method,headers,payload)
    uri=URI(url)
    http=Net::HTTP.new(uri.host,443,nil) # No proxy or redirect can redirect credentials to another host.
    http.use_ssl=true;http.open_timeout=4;http.read_timeout=6;http.write_timeout=4;http.max_retries=0
    request=(method==:post ? Net::HTTP::Post : Net::HTTP::Get).new(uri.request_uri)
    request['Accept']='application/json';headers.each{|k,v|request[k]=v}
    if payload
      request['Content-Type']='application/json';request.body=JSON.generate(payload)
    elsif method==:post
      request['Content-Type']='application/x-www-form-urlencoded';request.body=''
    end
    code=nil;body=+''
    Timeout.timeout(12) do
      http.start do |connection|
        connection.request(request) do |response|
          code=response.code.to_i
          response.read_body do |chunk|
            raise InvalidResponse if body.bytesize+chunk.bytesize>2.megabytes
            body<<chunk
          end
        end
      end
    end
    [code,JSON.parse(body)]
  end
end
