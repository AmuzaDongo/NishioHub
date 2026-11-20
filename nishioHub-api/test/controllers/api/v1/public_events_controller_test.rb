require 'test_helper'
class Api::V1::PublicEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS.merge('public_events_enabled'=>true))
    @admin=create_user(role:create_role('admin'),email:'discovery-admin@example.test')
    @learner=create_mentee(email:'discovery-learner@example.test')
  end
  def event(**attrs)
    item=Event.new({organizer:@admin,title:'Learning together',description:'An educational community event',category:'talk',event_type:'webinar',format:'online',status:'published',location:'Online',meeting_url:'https://example.com/private-room',starts_at:2.days.from_now,ends_at:2.days.from_now+1.hour}.merge(attrs))
    item.type_explicit=true;item.save!;item
  end
  def discovery(**params)
    get '/api/v1/platform/events/discover',params:params
    assert_response :ok
    response.parsed_body
  end
  test 'only published kept events are visible and the public switch applies to listing and details' do
    visible=event
    event(status:'draft');event(status:'cancelled');event(deleted_at:Time.current)
    assert_equal [visible.id],discovery['items'].map{|i|i['id']}
    SystemSetting.current.update!(values:SystemSetting.config.merge('public_events_enabled'=>false))
    assert_empty discovery['items']
    get "/api/v1/platform/events/discover/#{visible.id}";assert_response :not_found
  end
  test 'tabs filter actual schedules and explicit featured status without leaking future recordings' do
    upcoming=event(public_featured:true,public_recording_url:'https://example.com/recording')
    live=event(starts_at:1.hour.ago,ends_at:1.hour.from_now)
    event(starts_at:1.hour.ago,ends_at:1.hour.from_now,format:'on_site')
    past=event(starts_at:2.hours.ago,ends_at:1.hour.ago,public_recording_url:'https://example.com/recording')
    assert_equal [upcoming.id],discovery['items'].map{|i|i['id']}
    assert_nil discovery['items'][0]['recording_url']
    assert_equal [live.id],discovery(tab:'live')['items'].map{|i|i['id']}
    assert_equal [upcoming.id],discovery(tab:'featured')['items'].map{|i|i['id']}
    result=discovery(tab:'past')['items'];assert_equal [past.id],result.map{|i|i['id']};assert_equal 'https://example.com/recording',result[0]['recording_url']
  end
  test 'combined filters counts pagination escaped searches and platform date boundaries' do
    selected=event(event_type:'training',target_audiences:['primary'],format:'hybrid',location:'Kampala Library',starts_at:3.days.from_now,ends_at:3.days.from_now+1.hour)
    event(event_type:'training',target_audiences:['secondary'],format:'hybrid')
    open=event(event_type:'training',target_audiences:[],format:'hybrid')
    body=discovery(types:['workshop'],audiences:['primary'],mode:'hybrid')
    assert_equal [selected.id,open.id].sort,body['items'].map{|i|i['id']}.sort
    assert_equal 3,body['facets']['total']
    assert_equal [selected.id],discovery(q:'Kampala')['items'].map{|i|i['id']}
    assert_empty discovery(q:'%')['items']
    zone=ActiveSupport::TimeZone['Africa/Kampala'];date=4.days.from_now.in_time_zone(zone).to_date
    start=zone.local(date.year,date.month,date.day)
    exact=event(starts_at:start,ends_at:start+1.hour)
    event(starts_at:start-1.second,ends_at:start+1.hour)
    assert_equal [exact.id],discovery(date_range:'custom',from:date.iso8601,to:date.iso8601)['items'].map{|i|i['id']}
    5.times{event}
    assert_equal 6,discovery['items'].length
    assert_equal 10,discovery.dig('meta','total')
    assert_equal 4,discovery(page:2)['items'].length
    [{page:'1abc'},{types:'webinar'},{audiences:['unknown']},{mode:'invalid'},{date_range:'custom',from:'2026-02-30',to:'2026-03-01'},{date_range:'custom',from:'2026-01-01',to:'2028-01-01'}].each do |invalid|
      get '/api/v1/platform/events/discover',params:invalid;assert_response :unprocessable_entity
    end
  end
  test 'registration state and private meeting links are scoped and capacity cancellation work for all roles' do
    %w[mentee mentor admin Super\ Admin].each_with_index do |role,index|
      actor=create_user(role:create_role(role),email:"public-role-#{index}@example.test")
      item=event(capacity:1)
      post "/api/v1/events/#{item.id}/registration",headers:auth_headers(actor);assert_response :ok
      get "/api/v1/platform/events/discover/#{item.id}",params:{user_id:actor.id}
      assert_response :ok;assert_nil response.parsed_body['meeting_url'];assert_nil response.parsed_body['reminder_minutes'];assert_not response.parsed_body['registered'];assert_not response.parsed_body['can_register']
      get "/api/v1/platform/events/discover/#{item.id}",headers:auth_headers(actor)
      assert response.parsed_body['registered'];assert_equal item.meeting_url,response.parsed_body['meeting_url'];assert response.parsed_body['can_cancel']
      assert_not_includes response.body,actor.email
      patch "/api/v1/events/#{item.id}/registration",params:{registration:{reminder_minutes:60}},headers:auth_headers(actor),as: :json
      assert_response :ok
      get "/api/v1/platform/events/discover/#{item.id}",headers:auth_headers(actor)
      assert_equal 60,response.parsed_body['reminder_minutes']
      assert_includes response.headers['Cache-Control'],'no-store'
      get "/api/v1/events/#{item.id}/calendar",headers:auth_headers(actor)
      assert_response :ok
      assert_equal 'text/calendar',response.media_type
      assert_includes response.body,'TRIGGER:-PT60M'
      get "/api/v1/platform/events/discover/#{item.id}",headers:auth_headers(@learner)
      assert_nil response.parsed_body['reminder_minutes']
      delete "/api/v1/events/#{item.id}/registration",headers:auth_headers(actor);assert_response :no_content
      get "/api/v1/platform/events/discover/#{item.id}";assert response.parsed_body['can_register'];assert_nil response.parsed_body['meeting_url']
    end
    item=event
    SystemSetting.current.update!(values:SystemSetting.config.merge('event_registration_enabled'=>false))
    get "/api/v1/platform/events/discover/#{item.id}";assert_not response.parsed_body['can_register']
  end
  test 'admin metadata persists through create update and multipart clear with validation and permission enforcement' do
    payload={title:'Public webinar',description:'A learning event',event_type:'webinar',status:'published',format:'online',location:'Online',starts_at:2.days.from_now.iso8601,ends_at:(2.days.from_now+1.hour).iso8601,target_audiences:['primary'],public_featured:true,public_recording_url:'https://example.com/recording'}
    post '/api/v1/admin/events',params:{event:payload},headers:auth_headers(@admin),as: :json
    assert_response :created
    item=Event.find(response.parsed_body['id']);assert item.public_featured;assert_equal ['primary'],item.target_audiences
    patch "/api/v1/admin/events/#{item.id}",params:{event:payload.merge(target_audiences:[''],public_featured:false,public_recording_url:'',lock_version:item.lock_version)},headers:auth_headers(@admin)
    assert_response :ok;assert_empty item.reload.target_audiences;assert_not item.public_featured
    [{target_audiences:['alien']},{target_audiences:['primary','primary']},{public_recording_url:'javascript:alert(1)'},{public_recording_url:'https://user:pass@example.com/file'}].each do |bad|
      post '/api/v1/admin/events',params:{event:payload.merge(bad)},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    end
    post '/api/v1/admin/events',params:{event:payload},headers:auth_headers(@learner),as: :json;assert_response :forbidden
  end
end
