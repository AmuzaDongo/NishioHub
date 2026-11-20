require 'test_helper'

class Api::V1::PublicEventDetailsTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS.merge('public_events_enabled'=>true))
    @admin=create_user(role:create_role('admin'),email:'public-details-admin@example.test')
    @learner=create_mentee(email:'public-details-learner@example.test')
    @event=make_event(public_details:{objectives:['Build practical digital skills','Connect with mentors'],faqs:[{question:'What should I bring?',answer:'Bring a laptop and a notebook.'}]})
    @agenda=@event.event_agenda_items.create!(title:'Digital skills session',description:'Practical exercises',starts_at:@event.starts_at,ends_at:@event.starts_at+30.minutes)
    @speaker=@event.event_speakers.create!(name:'Grace Namutebi',title:'Technology Educator',role:'Keynote Speaker',bio:'An experienced educator.',avatar_url:'https://example.com/speaker.jpg')
    @material=@event.event_materials.create!(title:'Participant Guide',description:'Private workbook',url:'https://example.com/private-workbook')
    @file=@event.event_materials.new(title:'Event Handout');@file.file.attach(io:StringIO.new('Private handout'),filename:'handout.txt',content_type:'text/plain');@file.save!
    @event.event_materials.create!(title:'Inactive Handout',url:'https://example.com/inactive',is_active:false)
  end

  test 'public details include authored outcomes agenda speakers FAQs and published related events without private material' do
    related=make_event(title:'Related published workshop')
    make_event(title:'Hidden draft',status:'draft');make_event(title:'Cancelled event',status:'cancelled');make_event(title:'Deleted event',deleted_at:Time.current)
    get details_path
    assert_response :ok
    body=response.parsed_body
    assert_equal ['Build practical digital skills','Connect with mentors'],body['objectives']
    assert_equal 'What should I bring?',body['faqs'].first['question']
    assert_equal @agenda.id,body['agenda'].first['id']
    assert_equal @speaker.role,body['speakers'].first['role']
    assert_equal [related.id],body['related_events'].map{|row|row['id']}
    assert_nil body['related_events'].first['meeting_url']
    assert body['resources_locked']
    assert_empty body['materials']
    assert_equal 2,body['materials_count']
    assert_not_includes response.body,'private-workbook'
    assert_not_includes response.body,'Private handout'
    assert_not_includes response.body,@learner.email
    assert_nil body['meeting_url']
    assert_includes response.headers['Cache-Control'],'no-store'
  end

  test 'registration unlocks only the current users active resources and cancellation removes access' do
    get "/api/v1/events/#{@event.id}/materials/#{@file.id}/file"
    assert_response :unauthorized
    get "/api/v1/events/#{@event.id}/materials/#{@file.id}/file",headers:auth_headers(@learner)
    assert_response :not_found
    post "/api/v1/events/#{@event.id}/registration",headers:auth_headers(@learner)
    assert_response :ok
    get details_path,headers:auth_headers(@learner)
    body=response.parsed_body
    assert_not body['resources_locked']
    assert_equal [@material.id,@file.id].sort,body['materials'].map{|row|row['id']}.sort
    assert_equal @event.meeting_url,body['meeting_url']
    get "/api/v1/events/#{@event.id}/materials/#{@file.id}/file",headers:auth_headers(@learner)
    assert_response :ok
    assert_equal 'Private handout',response.body
    get details_path,headers:auth_headers(@admin)
    assert response.parsed_body['resources_locked']
    assert_empty response.parsed_body['materials']
    delete "/api/v1/events/#{@event.id}/registration",headers:auth_headers(@learner)
    assert_response :no_content
    get details_path,headers:auth_headers(@learner)
    assert response.parsed_body['resources_locked']
    assert_nil response.parsed_body['meeting_url']
    get "/api/v1/events/#{@event.id}/materials/#{@file.id}/file",headers:auth_headers(@learner)
    assert_response :not_found
  end

  test 'anonymous calendar does not register a user or leak meeting links while a registered calendar includes reminders' do
    assert_no_difference('EventRegistration.count') { get "#{details_path}/calendar" }
    assert_response :ok
    assert_equal 'text/calendar',response.media_type
    assert_includes response.body,"UID:event-#{@event.id}@nishiohub.com"
    assert_includes response.body,"DTSTART:#{@event.starts_at.utc.strftime('%Y%m%dT%H%M%SZ')}"
    assert_not_includes response.body,'private-room'
    assert_not_includes response.body,'VALARM'
    post "/api/v1/events/#{@event.id}/registration",headers:auth_headers(@learner)
    patch "/api/v1/events/#{@event.id}/registration",headers:auth_headers(@learner),params:{registration:{reminder_minutes:60}},as: :json
    get "#{details_path}/calendar",headers:auth_headers(@learner)
    assert_response :ok
    assert_includes response.body,@event.meeting_url
    assert_includes response.body,'TRIGGER:-PT60M'
    assert_includes response.body,"UID:event-#{@event.id}@nishiohub.com"
    get "#{details_path}/calendar",headers:auth_headers(@admin)
    assert_not_includes response.body,@event.meeting_url
    assert_not_includes response.body,'TRIGGER'
  end

  test 'unpublished cancelled deleted and public disabled events expose neither content nor calendar' do
    %w[draft cancelled].each do |status|
      @event.update_columns(status:status)
      [details_path,"#{details_path}/calendar"].each{|path|get path;assert_response :not_found}
    end
    @event.update_columns(status:'published',deleted_at:Time.current)
    get details_path;assert_response :not_found
    @event.update_columns(deleted_at:nil)
    SystemSetting.current.update!(values:SystemSetting.config.merge('public_events_enabled'=>false))
    [details_path,"#{details_path}/calendar"].each{|path|get path;assert_response :not_found}
  end

  test 'admin authoring accepts structured and multipart JSON content while preserving it on unrelated edits' do
    data={objectives:['Practice coding'],faqs:[{question:'Is a laptop required?',answer:'A laptop is recommended.'}]}
    patch "/api/v1/admin/events/#{@event.id}",headers:auth_headers(@admin),params:{event:edit_payload.merge(public_details:data)},as: :json
    assert_response :ok
    assert_equal data.deep_stringify_keys,@event.reload.public_details
    assert_equal data.deep_stringify_keys,response.parsed_body['public_details']
    patch "/api/v1/admin/events/#{@event.id}",headers:auth_headers(@admin),params:{event:edit_payload.merge(public_details:data.to_json)}
    assert_response :ok
    patch "/api/v1/admin/events/#{@event.id}",headers:auth_headers(@admin),params:{event:edit_payload.merge(title:'Updated event title')},as: :json
    assert_response :ok
    assert_equal data.deep_stringify_keys,@event.reload.public_details
    patch "/api/v1/admin/events/#{@event.id}",headers:auth_headers(@learner),params:{event:edit_payload.merge(public_details:{})},as: :json
    assert_response :forbidden
  end

  test 'invalid public content is rejected and event speaker roles are editable by staff only' do
    ['invalid json','[]',{objectives:['x']*11},{objectives:['']},{faqs:[{question:'Missing answer'}]},{faqs:[{question:'Question',answer:'x'*1001}]}].each do |data|
      patch "/api/v1/admin/events/#{@event.id}",headers:auth_headers(@admin),params:{event:edit_payload.merge(public_details:data.is_a?(String) ? data : data.to_json)}
      assert_response :unprocessable_entity
    end
    patch "/api/v1/admin/events/#{@event.id}/sections/speakers/#{@speaker.id}",headers:auth_headers(@admin),params:{item:{lock_version:@speaker.lock_version,role:'Facilitator'}},as: :json
    assert_response :no_content
    assert_equal 'Facilitator',@speaker.reload.role
    patch "/api/v1/admin/events/#{@event.id}/sections/speakers/#{@speaker.id}",headers:auth_headers(@learner),params:{item:{lock_version:@speaker.lock_version,role:'Panelist'}},as: :json
    assert_response :forbidden
  end

  private

  def make_event(**attrs)
    record=Event.new({organizer:@admin,title:'Digital Employable Skills Bootcamp',description:'Equip learners with practical digital skills for education, work and entrepreneurship.',category:'workshop',event_type:'workshop',format:'hybrid',status:'published',location:'Makerere Innovation Hub, Kampala',meeting_url:'https://example.com/private-room',capacity:200,starts_at:7.days.from_now,ends_at:7.days.from_now+6.hours,target_audiences:['secondary','university']}.merge(attrs))
    record.type_explicit=true;record.save!;record
  end
  def details_path = "/api/v1/platform/events/discover/#{@event.id}"
  def edit_payload
    @event.reload
    {title:@event.title,description:@event.description,event_type:@event.event_type,format:@event.format,location:@event.location,starts_at:@event.starts_at.iso8601,ends_at:@event.ends_at.iso8601,lock_version:@event.lock_version}
  end
end
