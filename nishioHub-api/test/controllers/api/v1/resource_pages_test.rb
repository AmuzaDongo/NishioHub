require 'test_helper'
class Api::V1::ResourcePagesTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS)
    @admin=create_user(role:create_role('admin'),email:'page-admin@example.test')
    @user=create_mentee(email:'page-reader@example.test')
    @resource=PlatformResource.create!(title:'Excel Skills',url:'https://example.test/secret',published:true,library_details:{category:'digital'},page_details:{topic:'Data Analysis',learning_outcomes:['Organize data'],author_name:'Public Author'})
    @public="/api/v1/platform/learning-resources/#{@resource.id}"
    @learner="/api/v1/learning/resources/#{@resource.id}"
    @root="/api/v1/admin/resources/#{@resource.id}"
  end
  test 'public metadata only includes explicitly published supporting titles and author information' do
    @resource.resource_contents.create!(title:'Private chapter',body:'Private instructions',url:'https://example.test/private-chapter',position:1)
    @resource.resource_contents.create!(title:'Practice Dataset',url:'https://example.test/private-dataset',position:2,public_listing:true)
    get @public
    assert_response :ok
    assert_equal 'Public Author',response.parsed_body.dig('page_details','author_name')
    assert_equal ['Practice Dataset'],response.parsed_body['supporting_resources'].map{|c|c['title']}
    %w[Private\ chapter Private\ instructions private-dataset private-chapter secret].each{|value|assert_not_includes response.body,value}
    assert_not_includes response.body,@admin.email
    @resource.update!(published:false)
    get @public
    assert_response :not_found
  end
  test 'comments are authenticated idempotent private until approved and owner deletable' do
    fields={display_name:'Reader Alias',body:'Useful resource',submission_key:SecureRandom.uuid}
    post "#{@learner}/comments",params:{comment:fields},as: :json
    assert_response :unauthorized
    assert_difference('ResourceComment.count',1) do
      2.times do
        post "#{@learner}/comments",params:{comment:fields},headers:auth_headers(@user),as: :json
        assert_includes [200,201],response.status
        assert_equal 'pending',response.parsed_body['status']
      end
    end
    comment=ResourceComment.last
    get "#{@public}/comments"
    assert_equal 0,response.parsed_body['total']
    patch "#{@root}/comments/#{comment.id}",params:{review:{status:'approved',lock_version:comment.lock_version}},headers:auth_headers(@user),as: :json
    assert_response :forbidden
    patch "#{@root}/comments/#{comment.id}",params:{review:{status:'approved',lock_version:comment.lock_version}},headers:auth_headers(@admin),as: :json
    assert_response :no_content
    get "#{@public}/comments"
    assert_equal 1,response.parsed_body['total']
    assert_equal 'Reader Alias',response.parsed_body['items'][0]['display_name']
    assert_not_includes response.body,@user.email
    assert_not response.parsed_body['items'][0].key?('user_id')
    delete "#{@learner}/comments/#{comment.id}",headers:auth_headers(@admin)
    assert_response :not_found
    delete "#{@learner}/comments/#{comment.id}",headers:auth_headers(@user)
    assert_response :no_content
  end
  test 'all account roles may submit comments but publication and throttling are enforced' do
    %w[mentee mentor organization founder admin super_admin].each do |role|
      user=create_user(role:create_role(role),email:"comment-#{role}@example.test")
      post "#{@learner}/comments",params:{comment:{display_name:'Community member',body:'A helpful lesson',submission_key:SecureRandom.uuid}},headers:auth_headers(user),as: :json
      assert_response :created
      assert_equal 'pending',response.parsed_body['status']
    end
    10.times{ResourceComment.create!(platform_resource:@resource,user:@user,display_name:'Reader',body:'A comment',submission_key:SecureRandom.uuid)}
    post "#{@learner}/comments",params:{comment:{display_name:'Reader',body:'Another comment',submission_key:SecureRandom.uuid}},headers:auth_headers(@user),as: :json
    assert_response :too_many_requests
    @resource.update!(published:false)
    get "#{@public}/comments"
    assert_response :not_found
    post "#{@learner}/comments",params:{comment:{display_name:'Reader',body:'Comment',submission_key:SecureRandom.uuid}},headers:auth_headers(@admin),as: :json
    assert_response :not_found
  end
  test 'support files enforce authentication and parent scope and survive version restore' do
    post "#{@root}/contents",params:{content:{title:'Practice file',position:1,public_listing:true,file:fixture_file_upload('message-sheet.xlsx','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')}},headers:auth_headers(@admin)
    assert_response :no_content
    content=@resource.resource_contents.last
    assert content.file.attached?
    version=@resource.resource_versions.order(:number).last
    get "#{@learner}/contents/#{content.id}/file"
    assert_response :unauthorized
    get "#{@learner}/contents/#{content.id}/file",headers:auth_headers(@user)
    assert_response :ok
    assert_equal file_fixture('message-sheet.xlsx').binread,response.body.b
    assert_equal 1,@resource.platform_resource_accesses.where(kind:'download').count
    other=PlatformResource.create!(title:'Other',url:'https://example.test/other',published:true)
    get "/api/v1/learning/resources/#{other.id}/contents/#{content.id}/file",headers:auth_headers(@user)
    assert_response :not_found
    delete "#{@root}/contents/#{content.id}",headers:auth_headers(@admin),params:{lock_version:content.reload.lock_version},as: :json
    assert_response :no_content
    post "#{@root}/versions/#{version.id}/restore",params:{lock_version:@resource.reload.lock_version},headers:auth_headers(@admin),as: :json
    assert_response :ok
    restored=@resource.resource_contents.last
    assert restored.file.attached?
    assert restored.public_listing
    assert_equal file_fixture('message-sheet.xlsx').binread,restored.file.download
  end
  test 'page metadata is validated and preview tracks views instead of downloads' do
    patch "#{@root}/details",params:{details:{lock_version:@resource.reload.lock_version,page_details_json:{topic:'Data',takeaways:['Practice regularly']}.to_json}},headers:auth_headers(@admin)
    assert_response :ok
    patch "#{@root}/details",params:{details:{lock_version:@resource.reload.lock_version,page_details_json:{author_profile_url:'javascript:alert(1)'}.to_json}},headers:auth_headers(@admin)
    assert_response :unprocessable_entity
    @resource.with_lock{@resource.file= {io:File.open(file_fixture('notes.txt')),filename:'notes.txt',content_type:'text/plain'};@resource.save!}
    get "#{@learner}/file",params:{preview:true},headers:auth_headers(@user)
    assert_response :ok
    assert_equal 1,@resource.platform_resource_accesses.where(kind:'view').count
    assert_equal 0,@resource.platform_resource_accesses.where(kind:'download').count
  end
end
