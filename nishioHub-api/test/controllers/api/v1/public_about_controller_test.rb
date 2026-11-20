require 'test_helper'

class Api::V1::PublicAboutControllerTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS)
    @admin=create_user(role:create_role('admin'),email:'about-admin@example.test')
  end

  test 'public impact uses real active accounts and publicly published records without exposing identities' do
    learner=create_mentee(email:'private-learner@example.test')
    learner.additional_roles<<create_role('organization')
    create_user(role:create_role('mentee'),email:'inactive-learner@example.test').update!(is_active:false)
    mentor=create_mentor(email:'private-mentor@example.test')
    create_mentor(email:'unverified-about@example.test').mentor_profile.update!(is_verified:false)
    create_mentor(email:'hidden-about@example.test').mentor_profile.update!(is_published:false)
    create_mentor(email:'inactive-about@example.test').update!(is_active:false)
    create_user(role:create_role('school'),email:'school-about@example.test')
    PlatformResource.create!(title:'Public Learning Guide',url:'https://example.test/guide',published:true,visibility:'platform')
    PlatformResource.create!(title:'Staff Guide',url:'https://example.test/staff',published:true,visibility:'staff')
    PlatformResource.create!(title:'Draft Guide',url:'https://example.test/draft',published:false,visibility:'platform')
    PlatformResource.create!(title:'Archived Guide',url:'https://example.test/archive',published:false,archived:true)
    event=Event.create!(title:'Public Workshop',description:'Public event',organizer:@admin,status:'published',category:'workshop',starts_at:2.days.from_now,ends_at:2.days.from_now+1.hour,location:'Kampala')
    Event.create!(title:'Draft Event',description:'A draft event',organizer:@admin,status:'draft',category:'workshop',starts_at:2.days.from_now,ends_at:2.days.from_now+1.hour,location:'Kampala')
    get '/api/v1/platform/about'
    assert_response :ok
    assert_equal({'learners'=>1,'mentors'=>1,'resources'=>1,'events'=>0,'organizations'=>2},response.parsed_body['impact'])
    assert_empty response.parsed_body['team']
    assert_nil response.parsed_body['story_video_url']
    assert_not_includes response.body,learner.email
    assert_not_includes response.body,mentor.email
    assert_not_includes response.body,'phone_number'
    assert_equal 'no-store',response.headers['Cache-Control']
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS.merge('public_events_enabled'=>true))
    get '/api/v1/platform/about'
    assert_equal 1,response.parsed_body.dig('impact','events')
    event.update!(deleted_at:Time.current)
    get '/api/v1/platform/about'
    assert_equal 0,response.parsed_body.dig('impact','events')
  end

  test 'only explicitly published approved team fields and configured video are public' do
    visible={name:'Published Team Member',title:'Education Lead',bio:'Supporting learner opportunities.',photo_url:'https://example.test/team.jpg',published:true}
    hidden=visible.merge(name:'Unpublished Internal Draft',published:false)
    settings=SystemSetting.current
    patch '/api/v1/admin/system_settings',headers:auth_headers(@admin),params:{lock_version:settings.lock_version,settings:{about_team:[visible,hidden],about_story_video_url:'https://example.test/story.mp4'}},as: :json
    assert_response :ok
    get '/api/v1/platform/about'
    assert_response :ok
    assert_equal [visible.except(:published).stringify_keys],response.parsed_body['team']
    assert_equal 'https://example.test/story.mp4',response.parsed_body['story_video_url']
    assert_not_includes response.body,hidden[:name]
    assert_not_includes response.body,'published'
    assert_not_includes response.body,@admin.email
    assert SystemSettingAudit.where(actor:@admin,action:'settings.updated').exists?
    stale=settings.lock_version
    patch '/api/v1/admin/system_settings',headers:auth_headers(@admin),params:{lock_version:stale,settings:{about_team:[]}},as: :json
    assert_response :conflict
  end

  test 'about content editing rejects unsafe URLs unapproved fields malformed members and unauthorized roles' do
    member={name:'Team Member',title:'Education Lead',bio:'',photo_url:'',published:false}
    [{about_story_video_url:'javascript:alert(1)'},{about_story_video_url:'https://example.test/page.html'},{about_team:[member.merge(photo_url:'data:image/png;base64,123') ]},{about_team:[member.merge(email:'private@example.test')]},{about_team:[member.merge(published:'true')]},{about_team:[member.merge(name:'')]},{about_team:'bad'},{about_team:Array.new(21){member}}].each do |invalid|
      settings=SystemSetting.current
      patch '/api/v1/admin/system_settings',headers:auth_headers(@admin),params:{lock_version:settings.lock_version,settings:invalid},as: :json
      assert_response :unprocessable_entity
      assert_empty settings.reload.config['about_team']
    end
    patch '/api/v1/admin/system_settings',params:{settings:{about_team:[]}},as: :json
    assert_response :unauthorized
    %w[mentor mentee organization].each do |role|
      user=create_user(role:create_role(role),email:"about-#{role}@example.test")
      patch '/api/v1/admin/system_settings',headers:auth_headers(user),params:{settings:{about_team:[]}},as: :json
      assert_response :forbidden
    end
    @admin.role.update!(permissions:['dashboard.read'])
    get '/api/v1/admin/system_settings',headers:auth_headers(@admin)
    assert_response :forbidden
    super_admin=create_user(role:create_role('super_admin'),email:'about-super@example.test')
    settings=SystemSetting.current
    patch '/api/v1/admin/system_settings',headers:auth_headers(super_admin),params:{lock_version:settings.lock_version,settings:{about_team:[member.merge(published:true)]}},as: :json
    assert_response :ok
  end
end
