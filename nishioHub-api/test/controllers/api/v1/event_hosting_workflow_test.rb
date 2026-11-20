require 'test_helper'

class Api::V1::EventHostingWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS.merge('public_events_enabled'=>true))
    @admin=create_user(role:create_role('admin'),email:'review-admin@example.test')
    @super=create_user(role:create_role('super_admin'),email:'review-super@example.test')
    @host=create_user(role:create_role('mentor'),email:'review-host@example.test')
    @other=create_user(role:create_role('organization'),email:'review-other@example.test')
    @payload={name:'School Partner',email:'partner@example.test',phone_number:'+256772345678',title:'Learner Technology Workshop',description:'A practical workshop with mentorship and digital skills activities.',event_type:'workshop',preferred_date:2.weeks.from_now.to_date.iso8601,location:'Kampala',additional_information:'Projector access',terms_accepted:true,submission_key:SecureRandom.uuid}
    post '/api/v1/platform/event-hosting-requests',params:{event_request:@payload},headers:auth_headers(@host),as: :json
    assert_response :created
    @hosting_request=PublicInquiry.last
    @schedule={starts_at:2.weeks.from_now.iso8601,ends_at:(2.weeks.from_now+2.hours).iso8601,format:'on_site',location:'NishioHub Learning Centre',capacity:100,status:'published',organizer_id:@admin.id}
  end

  test 'approval atomically creates one linked private draft owned by the host and notifies them' do
    assert_difference('Event.count',1) { decide('approved') }
    assert_response :ok
    @hosting_request.reload;event=@hosting_request.event
    assert_equal 'approved',@hosting_request.status
    assert_equal @admin.id,@hosting_request.reviewer_id
    assert @hosting_request.reviewed_at
    assert @hosting_request.reviewed
    assert_equal 'draft',event.status
    assert_equal @host.id,event.organizer_id
    assert_equal @payload[:title],event.title
    assert_equal @payload[:description],event.description
    assert_equal 'workshop',event.event_type
    assert_equal @schedule[:location],event.location
    assert Notification.exists?(user:@host,title:'Event Request Approved',href:'/host-an-event#my-event-requests')
    assert AdministrationAudit.exists?(action:'event_request.reviewed',target_id:@hosting_request.id)
    get "/api/v1/platform/events/discover/#{event.id}"
    assert_response :not_found
    assert_no_difference('Event.count') do
      decide('approved',version:0)
      assert_response :conflict
    end
  end

  test 'super admin can approve and staff without event management permissions cannot create drafts' do
    @admin.role.update!(permissions:['system.manage'])
    assert_no_difference('Event.count') { decide('approved') }
    assert_response :forbidden
    assert_equal 'pending',@hosting_request.reload.status
    decide('approved',actor:@super)
    assert_response :ok
    assert_equal @super.id,@hosting_request.reload.reviewer_id
  end

  test 'approval requires a real future schedule and rejects invalid time capacity and inactive host without changes' do
    [{starts_at:'invalid'}, {starts_at:1.day.ago.iso8601}, {ends_at:1.day.ago.iso8601}, {capacity:0}, {format:'invalid'}].each do |invalid|
      assert_no_difference(['Event.count','Notification.count']) { decide('approved',schedule:@schedule.merge(invalid)) }
      assert_response :unprocessable_entity
      assert_equal 'pending',@hosting_request.reload.status
    end
    @host.update!(is_active:false)
    assert_no_difference('Event.count') { decide('approved') }
    assert_response :unprocessable_entity
  end

  test 'changes requested notifies the host and only that host can amend and resubmit for a new review' do
    decide('changes_requested',note:'Please clarify the audience and objectives.')
    assert_response :ok
    assert_equal 'changes_requested',@hosting_request.reload.status
    assert_nil @hosting_request.event_id
    assert Notification.exists?(user:@host,title:'Changes Requested for Your Event')
    assert_no_difference('Event.count') { decide('approved',version:@hosting_request.lock_version) }
    assert_response :conflict
    updated=@payload.merge(title:'Updated Learner Technology Workshop',lock_version:@hosting_request.lock_version,requester_id:@other.id,status:'approved',reviewer_id:@host.id)
    patch "/api/v1/me/event-hosting-requests/#{@hosting_request.id}",params:{event_request:updated},headers:auth_headers(@other),as: :json
    assert_response :not_found
    patch "/api/v1/me/event-hosting-requests/#{@hosting_request.id}",params:{event_request:updated},headers:auth_headers(@host),as: :json
    assert_response :ok
    @hosting_request.reload
    assert_equal 'pending',@hosting_request.status
    assert_equal 'Updated Learner Technology Workshop',@hosting_request.subject
    assert_equal @host.id,@hosting_request.requester_id
    assert_not @hosting_request.reviewed
    assert Notification.exists?(user:@admin,title:'Event Request Resubmitted')
    assert AdministrationAudit.exists?(actor:@host,action:'event_request.resubmitted')
    patch "/api/v1/me/event-hosting-requests/#{@hosting_request.id}",params:{event_request:updated},headers:auth_headers(@host),as: :json
    assert_response :conflict
    decide('approved',version:@hosting_request.lock_version)
    assert_response :ok
    assert_equal @hosting_request.subject,@hosting_request.reload.event.title
  end

  test 'rejection is terminal and feedback is required for rejection or changes' do
    %w[rejected changes_requested].each do |decision|
      decide(decision,note:'')
      assert_response :unprocessable_entity
      assert_equal 'pending',@hosting_request.reload.status
    end
    decide('rejected',note:'The proposed topic does not fit the current programme.')
    assert_response :ok
    assert_equal 'rejected',@hosting_request.reload.status
    assert_nil @hosting_request.event_id
    assert Notification.exists?(user:@host,title:'Event Request Rejected')
    patch "/api/v1/me/event-hosting-requests/#{@hosting_request.id}",params:{event_request:@payload.merge(lock_version:@hosting_request.lock_version)},headers:auth_headers(@host),as: :json
    assert_response :conflict
    decide('approved',version:@hosting_request.lock_version)
    assert_response :conflict
  end

  test 'stale reviews invalid decisions and cross role actions cannot change a request' do
    decide('published')
    assert_response :unprocessable_entity
    decide('rejected',note:'No',version:99)
    assert_response :conflict
    decide('approved',actor:@host)
    assert_response :forbidden
    post "/api/v1/admin/inquiries/#{@hosting_request.id}/decision",params:{review:{decision:'approved',lock_version:0,event:@schedule}},as: :json
    assert_response :unauthorized
    assert_equal 'pending',@hosting_request.reload.status
    @admin.role.update!(permissions:['dashboard.read','dashboard.manage'])
    decide('approved')
    assert_response :forbidden
  end

  test 'request status is private and existing requests may be reviewed after their preferred date passes' do
    get '/api/v1/me/event-hosting-requests'
    assert_response :unauthorized
    get '/api/v1/me/event-hosting-requests',headers:auth_headers(@other)
    assert_response :ok
    assert_empty response.parsed_body['items']
    get '/api/v1/me/event-hosting-requests',headers:auth_headers(@host)
    assert_response :ok
    assert_equal @hosting_request.id,response.parsed_body['items'].first['id']
    assert_not_includes response.body,'submission_key'
    assert_not_includes response.body,'ip_digest'
    @hosting_request.update_columns(event_details:@hosting_request.event_details.merge('preferred_date'=>'2020-01-01'))
    decide('approved')
    assert_response :ok
  end

  test 'draft creation rolls back if the linked request cannot be saved' do
    @hosting_request.update_columns(message:'Invalid')
    assert_no_difference(['Event.count','AdministrationAudit.count','Notification.count']) { decide('approved') }
    assert_response :unprocessable_entity
    assert_equal 'pending',@hosting_request.reload.status
    assert_nil @hosting_request.event_id
  end

  test 'publication uses existing event management flow and alerts the approved host' do
    decide('approved')
    event=@hosting_request.reload.event
    post "/api/v1/admin/events/#{event.id}/status",params:{status:'published',lock_version:event.lock_version},headers:auth_headers(@admin),as: :json
    assert_response :ok
    assert_equal 'published',event.reload.status
    get "/api/v1/platform/events/discover/#{event.id}"
    assert_response :ok
    assert Notification.exists?(user:@host,title:'Your Event Is Published')
    get '/api/v1/me/event-hosting-requests',headers:auth_headers(@host)
    assert_response :ok
    assert_equal 'published',response.parsed_body['items'].first['event']['status']
    get "/api/v1/events/#{event.id}",headers:auth_headers(@host)
    assert_response :ok
  end

  private

  def decide(value,note:'',version:0,actor:@admin,schedule:@schedule)
    post "/api/v1/admin/inquiries/#{@hosting_request.id}/decision",params:{review:{decision:value,note:note,lock_version:version,event:schedule}},headers:auth_headers(actor),as: :json
  end
end
