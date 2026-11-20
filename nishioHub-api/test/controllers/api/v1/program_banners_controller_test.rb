require 'test_helper'

class Api::V1::ProgramBannersControllerTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS)
    @admin=create_user(role:create_role('admin'),email:'banner-admin@example.test')
    @super=create_user(role:create_role('super_admin'),email:'banner-super@example.test')
    @mentor=create_user(role:create_role('mentor'),email:'banner-mentor@example.test')
    @learner=create_mentee(email:'banner-learner@example.test')
    @program=PlatformProgram.create!(title:'Digital Skills Program',status:'active')
  end

  test 'admin and super admin can save banners and receive consistent list detail and public URLs' do
    [@admin,@super].each do |actor|
      post '/api/v1/admin/programs',params:{program:{title:"#{actor.id} Program",status:'active',banner:upload}},headers:auth_headers(actor)
      assert_response :created
      program=PlatformProgram.find(response.parsed_body['id'])
      assert program.banner.attached?
      assert_equal 'branding.png',response.parsed_body['banner_filename']
      url=response.parsed_body['banner_url']
      assert_match %r{\A/api/v1/platform/programs/#{program.id}/banner\?version=\d+\z},url
      get "/api/v1/admin/programs/#{program.id}",headers:auth_headers(actor)
      assert_response :ok
      assert_equal url,response.parsed_body['banner_url']
      get '/api/v1/admin/programs',headers:auth_headers(actor),params:{q:program.title}
      assert_equal url,response.parsed_body['programs'].first['banner_url']
      get '/api/v1/platform/catalog',params:{kind:'programs',q:program.title}
      assert_response :ok
      assert_equal url,response.parsed_body['items'].first['image']
      get url
      assert_response :ok
      assert_equal 'image/png',response.media_type
      assert_equal file_fixture('branding.png').binread,response.body.b
      assert_equal 'nosniff',response.headers['X-Content-Type-Options']
      assert_includes response.headers['Cache-Control'],'no-store'
    end
  end

  test 'banner-only replacement updates revision and URL and stale edits cannot overwrite it' do
    patch_program(banner:upload)
    assert_response :ok
    old_url=response.parsed_body['banner_url'];old_version=@program.reload.lock_version
    patch_program(banner:upload('avatar.png'))
    assert_response :ok
    assert_operator @program.reload.lock_version,:>,old_version
    assert_not_equal old_url,response.parsed_body['banner_url']
    assert_equal 'avatar.png',@program.banner.filename.to_s
    patch_program(banner:upload,lock_version:old_version)
    assert_response :conflict
    assert_equal 'avatar.png',@program.reload.banner.filename.to_s
  end

  test 'unrelated JSON edits preserve the banner and explicit removal restores the placeholder' do
    patch_program(banner:upload)
    blob_id=@program.reload.banner.blob.id
    patch_program(title:'Updated Program')
    assert_response :ok
    assert_equal blob_id,@program.reload.banner.blob.id
    patch_program(remove_banner:'false')
    assert_response :ok
    assert @program.reload.banner.attached?
    patch_program(remove_banner:'true')
    assert_response :ok
    assert_nil response.parsed_body['banner_url']
    assert_not @program.reload.banner.attached?
    get "/api/v1/platform/programs/#{@program.id}/banner"
    assert_response :not_found
  end

  test 'draft and archived banners require a staff viewer and public catalog does not expose them' do
    patch_program(banner:upload)
    %w[draft archived].each do |status|
      @program.reload.update!(status:status)
      url=@program.banner_url
      get url
      assert_response :not_found
      [@mentor,@learner].each{|user|get url,headers:auth_headers(user);assert_response :not_found}
      get url,headers:auth_headers(@admin)
      assert_response :ok
      get '/api/v1/platform/catalog',params:{kind:'programs',q:@program.title}
      assert_empty response.parsed_body['items']
    end
  end

  test 'anonymous non staff and read only staff cannot change images' do
    patch "/api/v1/admin/programs/#{@program.id}",params:{program:{banner:upload,lock_version:@program.lock_version}}
    assert_response :unauthorized
    [@mentor,@learner].each do |user|
      patch_program({banner:upload},actor:user)
      assert_response :forbidden
    end
    @admin.role.update!(permissions:['dashboard.read'])
    patch_program(banner:upload)
    assert_response :forbidden
    assert_not @program.reload.banner.attached?
  end

  test 'wrong formats forged types oversized files and conflicting operations cannot replace a valid banner' do
    patch_program(banner:upload)
    blob_id=@program.reload.banner.blob.id
    forged=Rack::Test::UploadedFile.new(file_fixture('notes.txt'),'image/png')
    patch_program(banner:forged)
    assert_response :unprocessable_entity
    assert_equal blob_id,@program.reload.banner.blob.id
    patch_program(banner:upload,remove_banner:true)
    assert_response :unprocessable_entity
    patch_program(remove_banner:'invalid')
    assert_response :unprocessable_entity
    file=Tempfile.new(['large-program-banner','.png']);file.binmode;file.write(file_fixture('branding.png').binread);file.write('x'*(2.megabytes+1));file.flush
    patch_program(banner:Rack::Test::UploadedFile.new(file.path,'image/png'))
    assert_response :unprocessable_entity
    assert_equal blob_id,@program.reload.banner.blob.id
  ensure
    file&.close!
  end

  test 'failed program validation rolls back banner removal and replacement' do
    patch_program(banner:upload)
    original=@program.reload.banner.blob.id
    patch_program(title:'',remove_banner:true)
    assert_response :unprocessable_entity
    assert_equal original,@program.reload.banner.blob.id
    patch_program(title:'',banner:upload('avatar.png'))
    assert_response :unprocessable_entity
    assert_equal original,@program.reload.banner.blob.id
  end

  test 'multipart upload retains normal program fields and supports clearing array selections' do
    category=Category.create!(name:'Banner Category',slug:'banner-category')
    @program.program_mentor_assignments.create!(user:@mentor)
    @program.update!(objectives:['Prior objective'])
    patch_program(banner:upload,category_id:category.id,mentor_ids:[''],objectives:[''],description:'Updated curriculum')
    assert_response :ok
    assert_equal category.id,@program.reload.category_id
    assert_equal 'Updated curriculum',@program.description
    assert_empty @program.objectives
    assert_empty @program.program_mentor_assignments.active
    audit=AdministrationAudit.where(target_type:'PlatformProgram',target_id:@program.id,action:'program.updated').last
    assert audit.changeset['banner_changed']
    assert_not audit.changeset.key?('banner')
    assert_not_includes audit.changeset.to_json,'tempfile'
  end

  test 'dashboard quick create and edit use the same upload rules without losing memberships' do
    post '/api/v1/admin/dashboard/programs',params:{program:{title:'Dashboard Banner Program',status:'active',participant_ids:[@learner.id],banner:upload}},headers:auth_headers(@admin)
    assert_response :created
    program=PlatformProgram.find(response.parsed_body['id'])
    assert program.banner.attached?
    assert program.program_memberships.exists?(user:@learner,is_active:true)
    patch "/api/v1/admin/dashboard/programs/#{program.id}",params:{program:{lock_version:program.lock_version,remove_banner:'true'}},headers:auth_headers(@admin)
    assert_response :ok
    assert_not program.reload.banner.attached?
    assert program.program_memberships.exists?(user:@learner,is_active:true)
    post '/api/v1/admin/dashboard/programs',params:{program:{title:'Banner without initial members',status:'active',participant_ids:[''],banner:upload}},headers:auth_headers(@admin)
    assert_response :created
    assert_equal 0,response.parsed_body['member_count']
    get response.parsed_body['banner_url']
    assert_response :ok
    assert_equal file_fixture('branding.png').binread,response.body.b
  end

  private
  def upload(name='branding.png') = Rack::Test::UploadedFile.new(file_fixture(name),'image/png')
  def patch_program(data=nil,actor:@admin,**fields)
    attrs=(data||{}).merge(fields)
    attrs[:lock_version]=@program.reload.lock_version unless attrs.key?(:lock_version)
    patch "/api/v1/admin/programs/#{@program.id}",params:{program:attrs},headers:auth_headers(actor)
  end
end
