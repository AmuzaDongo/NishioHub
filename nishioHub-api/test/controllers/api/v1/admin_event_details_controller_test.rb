require 'test_helper'
require 'csv'
class Api::V1::AdminEventDetailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin=create_user(role:create_role('admin'),email:'detail-event-admin@example.test')
    @learner=create_mentee(email:'detail-event-learner@example.test')
    @other=create_mentee(email:'detail-event-other@example.test')
    @event=Event.create!(organizer:@admin,title:'Youth Tech Summit',description:'Career opportunities.',category:'talk',starts_at:2.days.from_now.change(usec:0),ends_at:2.days.from_now.change(usec:0)+8.hours,location:'Kampala',capacity:100)
    @reg=@event.event_registrations.create!(user:@learner)
    @base="/api/v1/admin/events/#{@event.id}"
  end
  def agenda
    {title:'Opening Keynote',description:'Technology careers',starts_at:@event.starts_at.iso8601,ends_at:(@event.starts_at+1.hour).iso8601}
  end
  def staff_post(path,params)
    post path,params:params,headers:auth_headers(@admin),as: :json
  end
  test 'details require administrative read access and writes independently enforce manage permission' do
    get "#{@base}/details";assert_response :unauthorized
    get "#{@base}/details",headers:auth_headers(@learner);assert_response :forbidden
    get "#{@base}/details",headers:auth_headers(@admin);assert_response :ok
    b=response.parsed_body;assert_equal 1,b.dig('summary','registered');assert_equal 0,b.dig('summary','no_show');assert_equal 1,b.dig('summary','unrecorded');assert_nil b.dig('summary','rating')
    assert b.dig('summary','trend').all?{|r|Time.iso8601(r['at'])<=Time.current}
    @admin.role.update!(permissions:['dashboard.read'])
    staff_post "#{@base}/sections/agenda",{item:agenda};assert_response :forbidden
    staff_post "#{@base}/announcement",{announcement:{message:'Hello',request_key:SecureRandom.uuid}};assert_response :forbidden
    staff_post "#{@base}/duplicate",{event:{title:'Copy',starts_at:3.days.from_now.iso8601,ends_at:(3.days.from_now+8.hours).iso8601,lock_version:@event.lock_version}};assert_response :forbidden
    get "#{@base}/report",headers:auth_headers(@admin);assert_response :ok
  end
  test 'agenda speakers materials CRUD enforce revisions validation and event scope' do
    staff_post "#{@base}/sections/agenda",{item:agenda};assert_response :no_content;a=@event.event_agenda_items.first
    patch "#{@base}/sections/agenda/#{a.id}",params:{item:agenda.merge(title:'Updated Keynote',lock_version:a.lock_version)},headers:auth_headers(@admin),as: :json;assert_response :no_content
    patch "#{@base}/sections/agenda/#{a.id}",params:{item:agenda.merge(lock_version:0)},headers:auth_headers(@admin),as: :json;assert_response :conflict
    staff_post "#{@base}/sections/agenda",{item:agenda.merge(ends_at:(@event.ends_at+1.minute).iso8601)};assert_response :unprocessable_entity
    staff_post "#{@base}/sections/speakers",{item:{name:'Aisha',title:'Data Scientist',bio:'Building useful tools.'}};assert_response :no_content
    staff_post "#{@base}/sections/speakers",{item:{name:'Unsafe',avatar_url:'javascript:alert(1)'}};assert_response :unprocessable_entity
    staff_post "#{@base}/sections/materials",{item:{title:'Career Guide',url:'https://example.com/guide'}};assert_response :no_content
    staff_post "#{@base}/sections/materials",{item:{title:'Invalid',url:'file:///etc/passwd'}};assert_response :unprocessable_entity
    get "#{@base}/sections/agenda",headers:auth_headers(@admin),params:{q:'Updated'};assert_response :ok;assert_equal 1,response.parsed_body.dig('meta','total')
    get "#{@base}/sections/speakers",headers:auth_headers(@admin);assert_equal 'Aisha',response.parsed_body['items'][0]['name']
    other=Event.create!(organizer:@admin,title:'Other',category:'talk',description:'Another event',starts_at:3.days.from_now,ends_at:3.days.from_now+1.hour,location:'Online')
    delete "/api/v1/admin/events/#{other.id}/sections/agenda/#{a.id}",params:{lock_version:a.reload.lock_version},headers:auth_headers(@admin);assert_response :not_found
    delete "#{@base}/sections/agenda/#{a.id}",params:{lock_version:a.lock_version},headers:auth_headers(@admin);assert_response :no_content
    assert AdministrationAudit.exists?(target_type:'Event',target_id:@event.id,action:'event.content_saved')
  end
  test 'material files are private to staff and registrations and removed material access is revoked' do
    file=Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/notes.txt'),'text/plain')
    post "#{@base}/sections/materials",params:{item:{title:'Notes',file:file}},headers:auth_headers(@admin);assert_response :no_content
    m=@event.event_materials.first
    get "#{@base}/materials/#{m.id}/file",headers:auth_headers(@admin);assert_response :ok
    get "/api/v1/events/#{@event.id}/materials/#{m.id}/file",headers:auth_headers(@other);assert_response :not_found
    get "/api/v1/events/#{@event.id}/materials/#{m.id}/file",headers:auth_headers(@learner);assert_response :ok
    get "/api/v1/events/#{@event.id}/details",headers:auth_headers(@learner);assert_equal 'Notes',response.parsed_body['materials'][0]['title']
    delete "#{@base}/sections/materials/#{m.id}",params:{lock_version:m.lock_version},headers:auth_headers(@admin);assert_response :no_content
    get "/api/v1/events/#{@event.id}/materials/#{m.id}/file",headers:auth_headers(@learner);assert_response :not_found;assert m.reload.file.attached?
  end
  test 'feedback requires confirmed attendance after completion and updates real report statistics' do
    put "/api/v1/events/#{@event.id}/feedback",params:{feedback:{rating:5}},headers:auth_headers(@learner),as: :json;assert_response :forbidden
    travel_to @event.ends_at+1.hour do
      @reg.update!(attended_at:@event.ends_at)
      put "/api/v1/events/#{@event.id}/feedback",params:{feedback:{rating:5}},headers:auth_headers(@other),as: :json;assert_response :not_found
      put "/api/v1/events/#{@event.id}/feedback",params:{feedback:{rating:6}},headers:auth_headers(@learner),as: :json;assert_response :unprocessable_entity
      put "/api/v1/events/#{@event.id}/feedback",params:{feedback:{rating:5,comment:'Useful'}},headers:auth_headers(@learner),as: :json;assert_response :ok;version=response.parsed_body['lock_version']
      put "/api/v1/events/#{@event.id}/feedback",params:{feedback:{rating:4,comment:'Updated',lock_version:version}},headers:auth_headers(@learner),as: :json;assert_response :ok
      put "/api/v1/events/#{@event.id}/feedback",params:{feedback:{rating:3,lock_version:version}},headers:auth_headers(@learner),as: :json;assert_response :conflict
      get "#{@base}/details",headers:auth_headers(@admin);assert_equal 4.0,response.parsed_body.dig('summary','rating');assert_equal 100.0,response.parsed_body.dig('summary','attendance_rate')
      get "#{@base}/sections/feedback",headers:auth_headers(@admin);assert_equal 'Updated',response.parsed_body['items'][0]['comment']
      get "#{@base}/report",headers:auth_headers(@admin);assert_response :ok;assert_equal '1',CSV.parse(response.body,headers:true).find{|r|r['metric']=='attended'}['value']
    end
  end
  test 'announcements respect preferences exclude cancelled RSVPs and deduplicate retries' do
    @learner.create_notification_preference!(events:false)
    @event.event_registrations.create!(user:@other,status:'cancelled');key=SecureRandom.uuid
    2.times do
      staff_post "#{@base}/announcement",{announcement:{message:'Bring your notebook',request_key:key}};assert_response :ok;assert_equal 0,response.parsed_body['delivered'];assert_equal 1,response.parsed_body['skipped']
    end
    staff_post "#{@base}/announcement",{announcement:{message:'Changed message',request_key:key}};assert_response :conflict
    @learner.notification_preference.update!(events:true)
    assert_difference "Notification.where(user: @learner, icon: 'megaphone').count",1 do
      staff_post "#{@base}/announcement",{announcement:{message:'Bring your notebook',request_key:SecureRandom.uuid}};assert_response :ok;assert_equal 1,response.parsed_body['delivered']
    end
    assert_not Notification.where(user:@other,icon:'megaphone').exists?
  end
  test 'duplication copies and shifts event content atomically without participants or feedback' do
    @event.event_agenda_items.create!(agenda);@event.event_speakers.create!(name:'Aisha');@event.event_materials.create!(title:'Guide',url:'https://example.com/guide')
    target=5.days.from_now.change(usec:0)
    staff_post "#{@base}/duplicate",{event:{title:'Summit Copy',starts_at:target.iso8601,ends_at:(target+8.hours).iso8601,lock_version:@event.reload.lock_version}}
    assert_response :created;copy=Event.find(response.parsed_body['id']);assert_equal 'draft',copy.status;assert_equal target.to_i,copy.event_agenda_items.first.starts_at.to_i;assert_equal 1,copy.event_speakers.count;assert_equal 1,copy.event_materials.count;assert_equal 0,copy.event_registrations.count;assert_equal 0,copy.event_feedbacks.count
    assert_no_difference 'Event.count' do
      staff_post "#{@base}/duplicate",{event:{title:'Too Short',starts_at:target.iso8601,ends_at:(target+10.minutes).iso8601,lock_version:@event.reload.lock_version}};assert_response :unprocessable_entity
    end
  end
  test 'rescheduling shifts agenda atomically and soft deletion hides access but retains history' do
    a=@event.event_agenda_items.create!(agenda);old_start=@event.starts_at
    data=@event.attributes.slice('title','description','event_type','status','format','location','meeting_url','capacity','platform_program_id','lock_version').merge('starts_at'=>(old_start+1.day).iso8601,'ends_at'=>(@event.ends_at+1.day).iso8601)
    patch @base,params:{event:data},headers:auth_headers(@admin),as: :json;assert_response :ok;assert_equal (old_start+1.day).to_i,a.reload.starts_at.to_i
    delete @base,params:{lock_version:@event.reload.lock_version},headers:auth_headers(@admin);assert_response :unprocessable_entity
    staff_post "#{@base}/status",{status:'cancelled',lock_version:@event.reload.lock_version};assert_response :ok
    delete @base,params:{lock_version:@event.reload.lock_version},headers:auth_headers(@admin);assert_response :no_content;assert @event.reload.deleted_at;assert EventRegistration.exists?(@reg.id)
    get "#{@base}/details",headers:auth_headers(@admin);assert_response :not_found
    get "/api/v1/events/#{@event.id}",headers:auth_headers(@learner);assert_response :not_found
    get '/api/v1/admin/events',headers:auth_headers(@admin);assert_equal 0,response.parsed_body.dig('stats','total')
    get '/api/v1/events',headers:auth_headers(@learner);assert_empty response.parsed_body['registrations']
  end
  test 'deleted completed events do not leave attendee counts in platform summaries' do
    travel_to @event.ends_at+1.hour do
      @reg.update!(attended_at:@event.ends_at)
      delete @base,params:{lock_version:@event.reload.lock_version},headers:auth_headers(@admin)
      assert_response :no_content
      get '/api/v1/admin/events',headers:auth_headers(@admin)
      assert_response :ok
      assert_equal 0,response.parsed_body.dig('stats','total')
      assert_equal 0,response.parsed_body.dig('stats','attendees')
      assert EventRegistration.exists?(@reg.id)
    end
  end

end
