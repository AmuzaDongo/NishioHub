require 'test_helper'
class Api::V1::AdminResourceDetailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.current.update!(values: SystemSetting::DEFAULTS)
    @admin=create_user(role:create_role('admin'),email:'resource-details-admin@example.test')
    @super=create_user(role:create_role('super_admin'),email:'resource-details-super@example.test')
    @mentee=create_mentee
    @other=create_mentee(email:'resource-details-other@example.test')
    @program=PlatformProgram.create!(title:'Science Program')
    @resource=PlatformResource.create!(title:'Data Science',description:'Learn practical tools',url:'https://example.com/guide',platform_program:@program,created_by:@admin)
    @root="/api/v1/admin/resources/#{@resource.id}";@public="/api/v1/learning/resources/#{@resource.id}";@headers=auth_headers(@admin)
  end
  def body = response.parsed_body
  def revision = @resource.reload.lock_version
  def pdf
    file=Tempfile.new(['version-file','.pdf']);file.binmode;file.write("%PDF-1.4\nOriginal File\n%%EOF\n");file.flush
    [file,Rack::Test::UploadedFile.new(file.path,'application/pdf')]
  end
  test 'administrator guards and real learner performance are reflected in details' do
    get "#{@root}/details"
    assert_response :unauthorized
    get "#{@root}/details",headers:auth_headers(@mentee)
    assert_response :forbidden
    @resource.resource_progresses.create!(user:@mentee,percent:100)
    @resource.resource_feedbacks.create!(user:@mentee,rating:4,comment:'Practical resource')
    [@admin,@super].each do |u|
      get "#{@root}/details",headers:auth_headers(u)
      assert_response :ok
      assert_equal 1,body.dig('summary','completed')
      assert_equal 2,body.dig('summary','audience')
      assert_equal 50.0,body.dig('summary','completion_rate')
      assert_equal 4.0,body.dig('summary','rating')
      assert_equal 'private, no-store',response.headers['Cache-Control']
    end
    @admin.role.update!(permissions:['dashboard.read'])
    patch "#{@root}/details",headers:@headers,params:{details:{language:'fr',lock_version:revision}},as: :json
    assert_response :forbidden
    get "#{@root}/details",headers:@headers
    assert_not body.dig('capabilities','manage')
  end
  test 'metadata validates visibility language duration captions and revision' do
    patch "#{@root}/details",headers:@headers,params:{details:{language:'en-UG',module_name:'Fundamentals',position:1,target_audience:'Students',required:true,awards:'Course credits',duration_seconds:2732,visibility:'program',lock_version:revision}},as: :json
    assert_response :ok
    assert_equal 'Fundamentals',body['module_name']
    assert body['required']
    assert_equal 2732,body['duration_seconds']
    patch "#{@root}/details",headers:@headers,params:{details:{language:'fr',lock_version:99999}},as: :json
    assert_response :conflict
    [{language:'bad code!'},{duration_seconds:-1},{required:'yes'},{visibility:'unknown'}].each do |change|
      patch "#{@root}/details",headers:@headers,params:{details:change.merge(lock_version:revision)},as: :json
      assert_response :unprocessable_entity
    end
    file=Tempfile.new(['captions','.vtt']);file.write("WEBVTT\n\n00:00.000 --> 00:01.000\nWelcome\n");file.flush
    patch "#{@root}/details",headers:@headers,params:{details:{lock_version:revision,captions:Rack::Test::UploadedFile.new(file.path,'text/vtt')}}
    assert_response :ok
    assert @resource.reload.captions.attached?
    get "#{@root}/captions",headers:@headers
    assert_response :ok
    assert_includes response.body,'WEBVTT'
    file.close!
  end
  test 'program and staff visibility protect learner metadata files and links' do
    @resource.reload.update!(visibility:'program')
    get "#{@public}/details",headers:auth_headers(@mentee)
    assert_response :not_found
    @program.program_memberships.create!(user:@mentee)
    get "#{@public}/details",headers:auth_headers(@mentee)
    assert_response :ok
    get "#{@public}/details",headers:auth_headers(@other)
    assert_response :not_found
    @resource.reload.update!(visibility:'staff')
    post "#{@public}/access",headers:auth_headers(@mentee)
    assert_response :not_found
    get "#{@public}/details",headers:@headers
    assert_response :ok
    @admin.role.update!(permissions:[])
    get "#{@public}/details",headers:@headers
    assert_response :not_found
  end
  test 'ordered contents are scoped versioned and reject invalid chapter ranges' do
    @resource.reload.update!(duration_seconds:120)
    post "#{@root}/contents",headers:@headers,params:{content:{title:'First chapter',body:'Learn concepts',position:1,start_seconds:10}},as: :json
    assert_response :no_content
    c=@resource.resource_contents.first
    patch "#{@root}/contents/#{c.id}",headers:@headers,params:{content:{title:'Updated chapter',lock_version:c.lock_version}},as: :json
    assert_response :no_content
    patch "#{@root}/contents/#{c.id}",headers:@headers,params:{content:{title:'Stale chapter',lock_version:0}},as: :json
    assert_response :conflict
    post "#{@root}/contents",headers:@headers,params:{content:{title:'Too late',position:2,start_seconds:121}},as: :json
    assert_response :unprocessable_entity
    get "#{@root}/sections/contents",headers:@headers
    assert_response :ok
    assert_equal 'Updated chapter',body['items'].first['title']
    delete "#{@root}/contents/#{c.id}",headers:@headers,params:{lock_version:c.reload.lock_version},as: :json
    assert_response :no_content
    assert_equal 0,@resource.resource_contents.count
    assert @resource.resource_versions.count>=3
  end
  test 'sharing grants eligible program members and removing the final program-only association rolls back' do
    secondary=PlatformProgram.create!(title:'Other Program');secondary.program_memberships.create!(user:@other)
    @resource.reload.update!(visibility:'program')
    post "#{@root}/shares",headers:@headers,params:{share:{program_id:secondary.id,lock_version:revision}},as: :json
    assert_response :no_content
    get "#{@public}/details",headers:auth_headers(@other)
    assert_response :ok
    share=@resource.resource_program_shares.first
    delete "#{@root}/shares/#{share.id}",headers:@headers,params:{lock_version:revision},as: :json
    assert_response :no_content
    get "#{@public}/details",headers:auth_headers(@other)
    assert_response :not_found
    @resource.reload.update!(visibility:'platform',platform_program:nil)
    post "#{@root}/shares",headers:@headers,params:{share:{program_id:secondary.id,lock_version:revision}},as: :json
    assert_response :no_content
    @resource.reload.update!(visibility:'program')
    share=@resource.resource_program_shares.first
    delete "#{@root}/shares/#{share.id}",headers:@headers,params:{lock_version:revision},as: :json
    assert_response :unprocessable_entity
    assert @resource.resource_program_shares.exists?(share.id)
  end
  test 'progress feedback and access events are authentic learner records with revision checks' do
    post "#{@public}/access",headers:auth_headers(@mentee)
    assert_response :no_content
    post "#{@public}/access",headers:auth_headers(@mentee)
    assert_response :no_content
    assert_equal 1,@resource.resource_progresses.count
    p=@resource.resource_progresses.find_by!(user:@mentee)
    assert_equal 1,p.percent
    put "#{@public}/progress",headers:auth_headers(@mentee),params:{progress:{percent:100,lock_version:p.lock_version}},as: :json
    assert_response :ok
    assert p.reload.completed_at
    put "#{@public}/progress",headers:auth_headers(@mentee),params:{progress:{percent:50,lock_version:0}},as: :json
    assert_response :conflict
    put "#{@public}/feedback",headers:auth_headers(@mentee),params:{feedback:{rating:5,comment:'Very helpful'}},as: :json
    assert_response :ok
    put "#{@public}/feedback",headers:auth_headers(@mentee),params:{feedback:{rating:4.5,comment:'Invalid'}},as: :json
    assert_response :unprocessable_entity
    put "#{@public}/progress",headers:@headers,params:{progress:{percent:100,lock_version:0}},as: :json
    assert_response :forbidden
    get "#{@root}/details",headers:@headers
    assert_equal 1,body.dig('summary','completed')
    assert_equal 2,body.dig('summary','views')
    assert_equal 5.0,body.dig('summary','rating')
  end
  test 'versions retain replaced file bytes and restore contents as a draft' do
    file,upload=pdf
    patch @root,headers:@headers,params:{resource:{resource_type:'document',file:upload,lock_version:revision}}
    assert_response :ok
    version=@resource.resource_versions.order(number: :desc).first
    assert version.file.attached?
    post "#{@root}/contents",headers:@headers,params:{content:{title:'Original section',position:1}},as: :json
    assert_response :no_content
    version=@resource.resource_versions.order(number: :desc).first
    patch @root,headers:@headers,params:{resource:{title:'Changed title',remove_file:true,url:'https://example.com/new',resource_type:'link',lock_version:revision}},as: :json
    assert_response :ok
    post "#{@root}/versions/#{version.id}/restore",headers:@headers,params:{lock_version:revision},as: :json
    assert_response :ok
    assert_equal 'Data Science',@resource.reload.title
    assert_not @resource.published?
    assert @resource.file.attached?
    get "#{@root}/file",headers:@headers
    assert_response :ok
    assert_includes response.body,'Original File'
    file.close!
  end
  test 'duplicate starts as draft and deletion keeps history while excluding all learner access' do
    @resource.resource_contents.create!(title:'Section',position:1)
    @resource.resource_progresses.create!(user:@mentee,percent:100)
    post "#{@root}/duplicate",headers:@headers,params:{resource:{title:'Copy of science',url:'https://example.com/copy',resource_type:'link',status:'published',platform_program_id:@program.id}},as: :json
    assert_response :created
    copy=PlatformResource.find(body['id'])
    assert_not copy.published?
    assert_equal 1,copy.resource_contents.count
    assert_equal 0,copy.resource_progresses.count
    delete @root,headers:@headers,params:{lock_version:revision},as: :json
    assert_response :no_content
    assert @resource.reload.deleted_at
    assert @resource.resource_versions.any?
    get "#{@root}/details",headers:@headers
    assert_response :not_found
    get "#{@public}/details",headers:auth_headers(@mentee)
    assert_response :not_found
    get '/api/v1/admin/resources',headers:@headers
    assert_equal [copy.id],body['items'].map{|r|r['id']}
  end
end
