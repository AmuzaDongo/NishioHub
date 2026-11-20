require 'test_helper'
require 'tempfile'
class Api::V1::AdminMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin=create_user(role:create_role('admin'),email:'admin-chat@example.test')
    @learner=create_mentee(email:'admin-chat-learner@example.test')
    @other=create_mentee(email:'admin-chat-other@example.test')
    @conversation=Conversation.create!(creator:@admin,kind:'direct',direct_key:[@admin.id,@learner.id].sort.join(':'))
    [@admin,@learner].each{|u|@conversation.conversation_memberships.create!(user:u)}
    @message=@conversation.chat_messages.create!(sender:@learner,content:'Please review my project')
  end
  def path(suffix='') = "/api/v1/admin/messages/#{@conversation.id}#{suffix}"
  def member = @admin.conversation_memberships.find_by!(conversation:@conversation)
  def state(**attrs)
    patch path('/state'),params:{state:attrs,lock_version:member.lock_version},headers:auth_headers(@admin),as: :json
  end
  test 'admin super admin read-only and member access stay scoped to membership' do
    get '/api/v1/admin/messages';assert_response :unauthorized
    get '/api/v1/admin/messages',headers:auth_headers(@learner);assert_response :forbidden
    super_admin=create_user(role:create_role('Super Admin'),email:'chat-super@example.test')
    get path,headers:auth_headers(super_admin);assert_response :not_found
    get '/api/v1/admin/messages',headers:auth_headers(super_admin);assert_response :ok;assert_empty response.parsed_body['conversations']
    @admin.role.update!(permissions:['dashboard.read'])
    get path,headers:auth_headers(@admin);assert_response :ok;assert_equal false,response.parsed_body['can_send']
    post path('/messages'),params:{message:{content:'Denied'}},headers:auth_headers(@admin),as: :json;assert_response :forbidden
    post "/api/v1/conversations/#{@conversation.id}/messages",params:{message:{content:'No alternate bypass'}},headers:auth_headers(@admin),as: :json;assert_response :forbidden
    state(starred:true);assert_response :forbidden
  end
  test 'inbox flags unread filters pagination and revisions belong to the viewer' do
    get '/api/v1/admin/messages',headers:auth_headers(@admin);assert_response :ok;assert_equal 1,response.parsed_body.dig('counts','unread')
    state(starred:true,muted:true);assert_response :no_content
    get '/api/v1/admin/messages',params:{tab:'starred'},headers:auth_headers(@admin);assert_equal [@conversation.id],response.parsed_body['conversations'].map{|c|c['id']}
    assert_not @learner.conversation_memberships.find_by!(conversation:@conversation).starred
    patch path('/state'),params:{state:{starred:false},lock_version:0},headers:auth_headers(@admin),as: :json;assert_response :conflict
    state(archived:true);assert_response :no_content
    get '/api/v1/admin/messages',headers:auth_headers(@admin);assert_empty response.parsed_body['conversations']
    get '/api/v1/admin/messages',params:{tab:'archived',q:'project'},headers:auth_headers(@admin);assert_equal 1,response.parsed_body.dig('meta','total')
    version=member.lock_version
    patch path('/read'),params:{last_message_id:@message.id},headers:auth_headers(@admin),as: :json;assert_response :ok
    assert_equal version,member.lock_version,'Read cursors must not invalidate inbox flag revisions'
    get '/api/v1/admin/messages',params:{tab:'invalid'},headers:auth_headers(@admin);assert_response :unprocessable_entity
  end
  test 'deletion hides only your history and attachments new incoming messages revive a clean thread' do
    @message.attachment.attach(io:StringIO.new('Private previous notes'),filename:'notes.txt',content_type:'text/plain')
    state(deleted:true);assert_response :no_content
    get path,headers:auth_headers(@admin);assert_response :not_found
    get "/api/v1/conversations/#{@conversation.id}/messages/#{@message.id}/attachment",headers:auth_headers(@admin);assert_response :not_found
    get "/api/v1/conversations/#{@conversation.id}/messages",headers:auth_headers(@learner);assert_response :ok;assert_equal 1,response.parsed_body['messages'].length
    new_message=@conversation.chat_messages.create!(sender:@learner,content:'New contact after deletion')
    get path('/messages'),headers:auth_headers(@admin);assert_response :ok;assert_equal [new_message.id],response.parsed_body['messages'].map{|m|m['id']}
    get "/api/v1/conversations/#{@conversation.id}/messages/#{@message.id}/attachment",headers:auth_headers(@admin);assert_response :not_found
    get path('/content'),headers:auth_headers(@admin);assert_empty response.parsed_body['items']
  end
  test 'blocking prevents direct messages and invitations through both admin and member APIs' do
    patch path('/block'),params:{blocked:true},headers:auth_headers(@admin),as: :json;assert_response :no_content
    post "/api/v1/conversations/#{@conversation.id}/messages",params:{message:{content:'Cannot contact'}},headers:auth_headers(@learner),as: :json;assert_response :unprocessable_entity
    post path('/messages'),params:{message:{content:'Cannot bypass own block'}},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    post '/api/v1/conversations',params:{participant_ids:[@admin.id,@other.id],kind:'group',title:'Blocked invitation'},headers:auth_headers(@learner),as: :json;assert_response :unprocessable_entity
    get '/api/v1/admin/messages/contacts',params:{q:'Mentee'},headers:auth_headers(@admin);assert_not response.parsed_body['people'].any?{|p|p['id']==@learner.id}
    patch path('/block'),params:{blocked:false},headers:auth_headers(@admin),as: :json;assert_response :no_content
    post path('/messages'),params:{message:{content:'Unblocked',client_nonce:'one-send'}},headers:auth_headers(@admin),as: :json;assert_response :created
  end
  test 'muting and personal notification preferences suppress alerts while receipt preferences hide read cursors' do
    state(muted:true);before=@admin.notifications.count
    @conversation.chat_messages.create!(sender:@learner,content:'Muted incoming')
    assert_equal before,@admin.notifications.count
    state(muted:false)
    patch '/api/v1/admin/messages/preferences',params:{preferences:{notify_messages:false,send_read_receipts:false,enter_to_send:false,lock_version:0}},headers:auth_headers(@admin),as: :json;assert_response :ok
    @conversation.chat_messages.create!(sender:@learner,content:'No alert preference')
    assert_equal before,@admin.notifications.count
    patch path('/read'),params:{last_message_id:@message.id},headers:auth_headers(@admin),as: :json;assert_response :ok
    get "/api/v1/conversations/#{@conversation.id}/messages",headers:auth_headers(@learner);assert_not response.parsed_body['messages'].first['read_by'].include?(@admin.id)
  end
  test 'broadcasts deliver private direct messages idempotently and roll back invalid recipient batches' do
    payload={recipient_ids:[@learner.id,@other.id],title:'Program update',content:'Workshop starts tomorrow',client_nonce:'broadcast-once'}
    2.times do
      post '/api/v1/admin/messages/broadcast',params:payload,headers:auth_headers(@admin),as: :json;assert_response :ok;assert_equal 2,response.parsed_body['delivered']
    end
    assert_equal 2,ChatMessage.where(client_nonce:"broadcast-#{MessageBroadcast.last.id}").count
    private_thread=Conversation.find_by!(direct_key:[@admin.id,@other.id].sort.join(':'))
    get "/api/v1/conversations/#{private_thread.id}",headers:auth_headers(@learner);assert_response :not_found
    post '/api/v1/admin/messages/broadcast',params:payload.merge(content:'Changed content'),headers:auth_headers(@admin),as: :json;assert_response :conflict
    @other.update!(is_active:false)
    assert_no_difference 'ChatMessage.count' do
      post '/api/v1/admin/messages/broadcast',params:payload.merge(client_nonce:'invalid-batch'),headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    end
  end
  test 'compose respects recipient privacy validates groups and shares attachment metadata privately' do
    @other.create_account_setting!(allow_contact_requests:false)
    post '/api/v1/admin/messages',params:{participant_ids:[@other.id],kind:'direct'},headers:auth_headers(@admin),as: :json;assert_response :unprocessable_entity
    post '/api/v1/admin/messages',params:{participant_ids:[@learner.id],kind:'direct'},headers:auth_headers(@admin),as: :json;assert_response :ok;assert_equal @conversation.id,response.parsed_body['id']
    file=Tempfile.new(['chat','.txt']);file.write('Shared text content');file.rewind
    upload=Rack::Test::UploadedFile.new(file.path,'text/plain',original_filename:'shared.txt')
    post path('/messages'),params:{message:{attachment:upload,client_nonce:'file-once'}},headers:auth_headers(@admin);assert_response :created
    get path('/content'),headers:auth_headers(@admin);assert_response :ok;assert_equal 'shared.txt',response.parsed_body['items'][0].dig('attachment','filename')
    get path('/content'),headers:auth_headers(@other);assert_response :forbidden
  end
  test 'Office attachments retain their document type and downloads require membership' do
    file=Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/message-sheet.xlsx'),'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    post path('/messages'),params:{message:{attachment:file,client_nonce:'spreadsheet-once'}},headers:auth_headers(@admin);assert_response :created
    assert_equal 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',response.parsed_body.dig('attachment','content_type')
    download=response.parsed_body.dig('attachment','download_path')
    get "/api/v1#{download}",headers:auth_headers(@learner);assert_response :ok;assert_equal File.binread(Rails.root.join('test/fixtures/files/message-sheet.xlsx')),response.body.b
    get "/api/v1#{download}",headers:auth_headers(@other);assert_response :not_found
  end

end
