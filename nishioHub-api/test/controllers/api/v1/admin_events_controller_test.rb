require 'test_helper'
require 'csv'
class Api::V1::AdminEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin=create_user(role:create_role('admin'),email:'admin-events-test@example.com')
    @learner=create_mentee(email:'learner-events-test@example.com')
    @program=PlatformProgram.create!(title:'Event Program',status:'active')
  end
  def attrs(**changes)
    {title:'Technology Webinar',description:'Discover careers and learn with industry experts.',event_type:'webinar',status:'published',format:'online',location:'Online (Zoom)',meeting_url:'https://example.com/room',capacity:10,platform_program_id:@program.id,starts_at:2.days.from_now.change(usec:0).iso8601,ends_at:(2.days.from_now+2.hours).change(usec:0).iso8601}.merge(changes)
  end
  def create_event(**changes)
    item=Event.new(attrs(**changes).merge(organizer:@admin,category:'talk'));item.type_explicit=true;item.save!;item
  end
  def staff_get(path,**params)
    get path,params:params,headers:auth_headers(@admin)
  end
  test 'admin and super admin can read but members cannot and custom permissions are enforced on every mutation' do
    get '/api/v1/admin/events';assert_response :unauthorized
    get '/api/v1/admin/events',headers:auth_headers(@learner);assert_response :forbidden
    super_admin=create_user(role:create_role('Super Admin'),email:'super-events-test@example.com')
    get '/api/v1/admin/events',headers:auth_headers(super_admin);assert_response :ok
    @admin.role.update!(permissions:['dashboard.read'])
    staff_get '/api/v1/admin/events';assert_response :ok;assert_equal false,response.parsed_body.dig('capabilities','manage')
    post '/api/v1/admin/events',params:{event:attrs},headers:auth_headers(@admin),as: :json;assert_response :forbidden
    post '/api/v1/events',params:{event:attrs.merge(category:'talk')},headers:auth_headers(@admin),as: :json;assert_response :forbidden
    e=create_event(starts_at:1.hour.ago,ends_at:1.hour.from_now);r=e.event_registrations.create!(user:@learner)
    patch "/api/v1/events/#{e.id}/attendees/#{r.id}",params:{registration:{attended:true}},headers:auth_headers(@admin),as: :json;assert_response :forbidden
    post "/api/v1/admin/events/#{e.id}/status",params:{status:'cancelled',lock_version:e.lock_version},headers:auth_headers(@admin),as: :json;assert_response :forbidden
    @admin.role.update!(permissions:[]);staff_get '/api/v1/admin/events';assert_response :forbidden
  end
  test 'create edit banner revision conflict and validated event data' do
    post '/api/v1/admin/events',params:{event:attrs(status:'draft')},headers:auth_headers(@admin),as: :json
    assert_response :created;e=Event.find(response.parsed_body['id']);assert_equal 'webinar',e.event_type;assert_equal 'talk',e.category;assert_equal 'scheduled',response.parsed_body['display_status']
    patch "/api/v1/admin/events/#{e.id}",params:{event:attrs(title:'Updated Webinar',status:'draft',lock_version:e.lock_version)},headers:auth_headers(@admin),as: :json
    assert_response :ok;assert_equal 'Updated Webinar',e.reload.title
    patch "/api/v1/admin/events/#{e.id}",params:{event:attrs(status:'draft',lock_version:0)},headers:auth_headers(@admin),as: :json;assert_response :conflict
    post '/api/v1/admin/events',params:{event:attrs(starts_at:'2027-02-20T10:00')},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    post '/api/v1/admin/events',params:{event:attrs(starts_at:'2027-02-30T10:00:00+03:00')},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    post '/api/v1/admin/events',params:{event:attrs(ends_at:1.hour.from_now.iso8601)},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    post '/api/v1/admin/events',params:{event:attrs(platform_program_id:'1 OR 1=1')},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    post '/api/v1/admin/events',params:{event:attrs(event_type:'invalid')},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    fake=Rack::Test::UploadedFile.new(StringIO.new('not an image'),'image/png',original_filename:'fake.png')
    patch "/api/v1/admin/events/#{e.id}",params:{event:attrs(status:'draft',lock_version:e.lock_version,banner:fake)},headers:auth_headers(@admin);assert_response :unprocessable_entity
    assert AdministrationAudit.exists?(action:'event.created',target_id:e.id)
  end
  test 'draft visibility publishing cancellation and notifications preserve registrations' do
    e=create_event(status:'draft')
    get "/api/v1/events/#{e.id}",headers:auth_headers(@learner);assert_response :not_found
    get '/api/v1/events',headers:auth_headers(@learner);assert_not_includes response.parsed_body['events'].map{|v|v['id']},e.id
    post "/api/v1/admin/events/#{e.id}/status",params:{status:'published',lock_version:e.lock_version},headers:auth_headers(@admin),as: :json;assert_response :ok
    post "/api/v1/events/#{e.id}/registration",headers:auth_headers(@learner);assert_response :ok
    r=e.event_registrations.first
    post "/api/v1/admin/events/#{e.id}/status",params:{status:'cancelled',lock_version:e.reload.lock_version},headers:auth_headers(@admin),as: :json;assert_response :ok
    assert_equal 'registered',r.reload.status;assert Notification.exists?(user:@learner,title:'Event Cancelled')
    get "/api/v1/events/#{e.id}",headers:auth_headers(@learner);assert_response :ok;assert_nil response.parsed_body['meeting_url'];assert_equal 'cancelled',response.parsed_body['status']
    post "/api/v1/events/#{e.id}/registration",headers:auth_headers(@learner);assert_response :unprocessable_entity
    get "/api/v1/events/#{e.id}/calendar",headers:auth_headers(@learner);assert_response :unprocessable_entity
    get '/api/v1/events',headers:auth_headers(@learner);assert_equal 0,response.parsed_body.dig('summary','upcoming');assert_not_includes response.parsed_body['events'].map{|v|v['id']},e.id
    post "/api/v1/admin/events/#{e.id}/status",params:{status:'published',lock_version:e.reload.lock_version},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
  end
  test 'capacity idempotent attendees active users and registration attendance revisions' do
    e=create_event(capacity:1)
    2.times do
      post "/api/v1/admin/events/#{e.id}/attendees",params:{user_ids:[@learner.id]},headers:auth_headers(@admin),as: :json;assert_response :ok
    end
    assert_equal 1,e.event_registrations.count;r=e.event_registrations.first
    post "/api/v1/admin/events/#{e.id}/attendees",params:{user_ids:[@admin.id]},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    patch "/api/v1/admin/events/#{e.id}/attendees/#{r.id}",params:{registration:{attendance_status:'present',lock_version:r.lock_version}},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    travel_to 2.days.from_now+10.minutes do
      patch "/api/v1/admin/events/#{e.id}/attendees/#{r.id}",params:{registration:{attendance_status:'present',lock_version:r.lock_version}},headers:auth_headers(@admin),as: :json;assert_response :no_content;assert r.reload.attended_at;assert_equal 'present',r.attendance_status
      patch "/api/v1/admin/events/#{e.id}/attendees/#{r.id}",params:{registration:{attendance_status:'absent',lock_version:0}},headers:auth_headers(@admin),as: :json;assert_response :conflict
      patch "/api/v1/admin/events/#{e.id}/attendees/#{r.id}",params:{registration:{cancel:true,lock_version:r.lock_version}},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
      patch "/api/v1/admin/events/#{e.id}/attendees/#{r.id}",params:{registration:{attendance_status:'absent',lock_version:r.lock_version}},headers:auth_headers(@admin),as: :json;assert_response :no_content;assert_nil r.reload.attended_at;assert_equal 'absent',r.attendance_status
    end
    patch "/api/v1/admin/events/#{e.id}/attendees/#{r.id}",params:{registration:{cancel:true,lock_version:r.lock_version}},headers:auth_headers(@admin),as: :json;assert_response :no_content
    post "/api/v1/admin/events/#{e.id}/attendees",params:{user_ids:[@learner.id]},headers:auth_headers(@admin),as: :json;assert_response :ok;assert_equal 'unrecorded',r.reload.attendance_status
    patch "/api/v1/admin/events/#{e.id}",params:{event:attrs(capacity:0,lock_version:e.reload.lock_version)},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    staff_get "/api/v1/admin/events/#{e.id}/attendees";assert_response :ok;assert_equal @learner.id,response.parsed_body['items'][0]['user_id']
  end
  test 'attendance does not cross events and account selection excludes inactive users' do
    e=create_event;other=create_event(title:'Another event');r=other.event_registrations.create!(user:@learner)
    patch "/api/v1/admin/events/#{e.id}/attendees/#{r.id}",params:{registration:{cancel:true,lock_version:r.lock_version}},headers:auth_headers(@admin),as: :json;assert_response :not_found
    @learner.update!(is_active:false)
    post "/api/v1/admin/events/#{e.id}/attendees",params:{user_ids:[@learner.id]},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    staff_get '/api/v1/admin/events/people',q:@learner.full_name;assert_response :ok;assert_not_includes response.parsed_body.map{|v|v['id']},@learner.id
  end
  test 'reports filter search sort pagination calendar local dates and donut totals are real' do
    travel_to Time.utc(2026,11,10,12) do
      e=create_event(title:'Alpha',starts_at:'2026-11-15T22:30:00Z',ends_at:'2026-11-16T22:00:00Z')
      e.event_registrations.create!(user:@learner)
      draft=create_event(title:'Draft Launch',status:'draft',event_type:'launch')
      create_event(title:'Old',starts_at:2.days.ago,ends_at:1.day.ago)
      staff_get '/api/v1/admin/events',month:'2026-11',day:'2026-11-16',q:'Alpha',per_page:5
      assert_response :ok;b=response.parsed_body;assert_equal [e.id],b['items'].map{|v|v['id']};assert_equal '2026-11-16',b.dig('calendar','events',0,'first_day');assert_equal '2026-11-17',b.dig('calendar','events',0,'last_day');assert_equal b.dig('stats','total'),b['distribution'].sum{|v|v['count']};assert_equal 1,b.dig('stats','attendees')
      assert_equal e.id,b.dig('next_event','id') if e.starts_at<draft.starts_at
      staff_get '/api/v1/admin/events',status:'scheduled';assert_equal [draft.id],response.parsed_body['items'].map{|v|v['id']}
      staff_get '/api/v1/admin/events',tab:'completed';assert_equal 1,response.parsed_body.dig('meta','total')
      staff_get '/api/v1/admin/events',q:@program.title;assert_equal 3,response.parsed_body.dig('meta','total')
      staff_get '/api/v1/admin/events',sort:'DROP TABLE events';assert_response :unprocessable_entity
      staff_get '/api/v1/admin/events',month:'2026-99';assert_response :unprocessable_entity
      staff_get '/api/v1/admin/events',day:'2026-02-30';assert_response :unprocessable_entity
      staff_get '/api/v1/admin/events',per_page:100000;assert_response :unprocessable_entity
    end
  end
  test 'ongoing event can end without rewriting historical schedules and calendar does not register staff' do
    e=create_event(starts_at:1.hour.ago,ends_at:1.hour.from_now)
    patch "/api/v1/admin/events/#{e.id}",params:{event:attrs(starts_at:1.day.from_now.iso8601,lock_version:e.lock_version)},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    assert_no_difference 'EventRegistration.count' do
      staff_get "/api/v1/admin/events/#{e.id}/calendar";assert_response :ok;assert_includes response.body,'BEGIN:VCALENDAR'
    end
    post "/api/v1/admin/events/#{e.id}/status",params:{status:'end',lock_version:e.lock_version},headers:auth_headers(@admin),as: :json;assert_response :ok;assert_equal 'completed',response.parsed_body['display_status']
    post "/api/v1/admin/events/#{e.id}/status",params:{status:'published',lock_version:e.reload.lock_version},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
  end
  test 'real image upload persists removal works and future events cannot be moved into the past' do
    e=create_event
    image=Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/profile-photo.png'),'image/png')
    patch "/api/v1/admin/events/#{e.id}",params:{event:attrs(lock_version:e.lock_version,banner:image)},headers:auth_headers(@admin)
    assert_response :ok;assert e.reload.banner.attached?;assert_includes response.parsed_body['image'],'/rails/active_storage/'
    patch "/api/v1/admin/events/#{e.id}",params:{event:attrs(lock_version:e.lock_version,remove_banner:true)},headers:auth_headers(@admin),as: :json
    assert_response :ok;assert_not e.reload.banner.attached?;assert_equal '/images/event-career.png',response.parsed_body['image']
    patch "/api/v1/admin/events/#{e.id}",params:{event:attrs(lock_version:e.lock_version,starts_at:1.hour.ago.iso8601)},headers:auth_headers(@admin),as: :json
    assert_response :unprocessable_entity
    patch "/api/v1/admin/events/#{e.id}",params:{event:'bad'},headers:auth_headers(@admin),as: :json
    assert_response :unprocessable_entity
  end
  test 'paused registrations and cancelled events do not create reminders' do
    e=create_event(starts_at:10.minutes.from_now,ends_at:1.hour.from_now)
    r=e.event_registrations.create!(user:@learner,reminder_minutes:30)
    e.update!(status:'cancelled')
    assert_no_difference "Notification.where(title: 'Upcoming Event: Technology Webinar').count" do
      SyncUserNotifications.new(@learner).call
    end
    config=SystemSetting.current
    config.update!(values:config.values.merge('event_registration_enabled'=>false))
    other=create_event(title:'Registration paused')
    post "/api/v1/admin/events/#{other.id}/attendees",params:{user_ids:[@learner.id]},headers:auth_headers(@admin),as: :json
    assert_response :forbidden;assert_equal 0,other.event_registrations.count
  end
  def csv_file(rows)
    text=CSV.generate{|out|out<<AdminEventImport::HEADERS;rows.each{|r|out<<AdminEventImport::HEADERS.map{|k|r[k]}}}
    Rack::Test::UploadedFile.new(StringIO.new(text),'text/csv',original_filename:'events.csv')
  end
  test 'CSV preview does not write commit is atomic duplicates rejected and exports escape formulas' do
    row=attrs(title:'=Formula Event',status:'draft').stringify_keys;row['program_id']=row.delete('platform_program_id')
    assert_no_difference 'Event.count' do
      post '/api/v1/admin/events/import-preview',params:{file:csv_file([row])},headers:auth_headers(@admin);assert_response :ok;assert response.parsed_body['valid']
    end
    assert_no_difference 'Event.count' do
      post '/api/v1/admin/events/import',params:{file:csv_file([row,row.merge('ends_at'=>'bad')])},headers:auth_headers(@admin);assert_response :unprocessable_entity
    end
    assert_difference 'Event.count',1 do
      post '/api/v1/admin/events/import',params:{file:csv_file([row])},headers:auth_headers(@admin);assert_response :created
    end
    assert_no_difference 'Event.count' do
      post '/api/v1/admin/events/import',params:{file:csv_file([row])},headers:auth_headers(@admin);assert_response :unprocessable_entity
    end
    staff_get '/api/v1/admin/events/export',q:'Formula';assert_response :ok;assert_equal "'=Formula Event",CSV.parse(response.body,headers:true)[0]['title']
    staff_get '/api/v1/admin/events/import-template';assert_response :ok;assert_equal AdminEventImport::HEADERS,CSV.parse_line(response.body)
  end
end
