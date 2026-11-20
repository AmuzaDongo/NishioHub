require 'test_helper'
class Api::V1::PublicHomeControllerTest < ActionDispatch::IntegrationTest
  setup { SystemSetting.current.update!(values:SystemSetting::DEFAULTS) }
  test 'home features only active verified mentors including additional mentor roles and exposes public fields only' do
    verified=create_mentor(email:'public-featured@example.test')
    unverified=create_mentor(email:'unverified-public@example.test');unverified.mentor_profile.update!(is_verified:false)
    inactive=create_mentor(email:'inactive-public@example.test');inactive.update!(is_active:false)
    additional=create_mentor(email:'additional-public@example.test');additional.additional_roles<<additional.role;additional.update!(role:create_role('user'))
    get '/api/v1/platform/home'
    assert_response :ok
    assert_equal [verified.id,additional.id].sort,response.parsed_body['mentors'].map{|m|m['id']}.sort
    assert_equal %w[avatar id name skills title verified],response.parsed_body['mentors'].first.keys.sort
    assert_not_includes response.body,'public-featured@example.test'
    assert_not_includes response.body,'phone_number'
    assert_empty response.parsed_body['events']
  end
  test 'public catalogs hide draft and archived programs and expose course summaries without lessons or enrollments' do
    active=PlatformProgram.create!(title:'Visible Public Program',status:'active',description:'A public mentorship opportunity')
    PlatformProgram.create!(title:'Hidden Draft',status:'draft')
    PlatformProgram.create!(title:'Hidden Archived',status:'archived')
    get '/api/v1/platform/catalog',params:{kind:'programs'}
    assert_response :ok
    assert_equal [active.id],response.parsed_body['items'].map{|p|p['id']}
    assert_not_includes response.body,'member_count'
    get '/api/v1/platform/catalog',params:{kind:'programs',q:'%'}
    assert_equal 0,response.parsed_body.dig('meta','total')
    get '/api/v1/platform/catalog',params:{kind:'learning'}
    assert_response :ok
    assert_equal LearningCatalog.courses.size,response.parsed_body.dig('meta','total')
    assert response.parsed_body['items'].all?{|c|c['lessons'].is_a?(Integer)}
    assert_not_includes response.body,'completed_lesson_ids'
    get '/api/v1/platform/catalog',params:{kind:'users'}
    assert_response :unprocessable_entity
    get '/api/v1/platform/catalog',params:{kind:'programs',page:'1abc'}
    assert_response :unprocessable_entity
  end
  test 'public events honor publication switch and exclude deleted cancelled draft and past events' do
    actor=create_user(role:create_role('admin'),email:'public-events-admin@example.test')
    attributes={title:'Visible Webinar',description:'A public event',organizer:actor,category:'talk',status:'published',starts_at:2.days.from_now,ends_at:2.days.from_now+1.hour,location:'Online'}
    event=Event.create!(attributes)
    Event.create!(attributes.merge(title:'Draft',status:'draft'))
    get '/api/v1/platform/catalog',params:{kind:'events'}
    assert_response :ok
    assert_not response.parsed_body['enabled']
    assert_empty response.parsed_body['items']
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS.merge('public_events_enabled'=>true))
    get '/api/v1/platform/home'
    assert_equal [event.id],response.parsed_body['events'].map{|e|e['id']}
    get '/api/v1/platform/catalog',params:{kind:'events'}
    assert_equal [event.id],response.parsed_body['items'].map{|e|e['id']}
  end
end
