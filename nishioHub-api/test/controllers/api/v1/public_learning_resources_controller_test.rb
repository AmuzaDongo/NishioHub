require 'test_helper'
class Api::V1::PublicLearningResourcesControllerTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.current.update!(values:SystemSetting::DEFAULTS)
    @admin=create_user(role:create_role('admin'),email:'library-admin@example.test')
    @learner=create_mentee(email:'library-learner@example.test')
    @resource=PlatformResource.create!(title:'Digital Study Guide',description:'Build useful learning skills.',url:'https://example.test/private-content',published:true,resource_type:'document',library_details:{category:'digital',learning_paths:['secondary'],featured:true,page_count:12,level:'beginner'})
    @other=PlatformResource.create!(title:'Career Toolkit',url:'https://example.test/career',published:true,library_details:{category:'career',format:'toolkit',learning_paths:['career']})
    @private=PlatformResource.create!(title:'Private Staff Resource',url:'https://example.test/staff',published:true,visibility:'staff')
    @draft=PlatformResource.create!(title:'Unpublished Draft',url:'https://example.test/draft',published:false)
  end
  test 'public library filters and counters use only public summaries and never expose file links or learner identities' do
    PlatformResourceAccess.create!(platform_resource:@resource,user:@learner,kind:'download')
    get '/api/v1/platform/learning-resources'
    assert_response :ok
    assert_equal 2,response.parsed_body['total']
    assert_equal 1,response.parsed_body.dig('categories','digital')
    assert_equal @resource.id,response.parsed_body['items'].first['id']
    assert_equal 1,response.parsed_body['items'].first['accesses']
    assert_equal [@resource.id],response.parsed_body['popular'].map{|r|r['id']}
    assert_not_includes response.body,'private-content'
    assert_not_includes response.body,@learner.email
    assert_not_includes response.body,'Private Staff Resource'
    assert_not_includes response.body,'Unpublished Draft'
    [{category:'digital'},{path:'secondary'},{format:'study_material'},{q:'Digital'},{featured:true}].each do |filters|
      get '/api/v1/platform/learning-resources',params:filters
      assert_response :ok
      assert_equal [@resource.id],response.parsed_body['items'].map{|r|r['id']}
    end
    get '/api/v1/platform/learning-resources',params:{q:'%'}
    assert_empty response.parsed_body['items']
    [{category:'unknown'},{path:'unknown'},{format:'unknown'},{sort:'unknown'},{page:'1abc'},{per_page:100},{saved:'bad'}].each do |filters|
      get '/api/v1/platform/learning-resources',params:filters
      assert_response :unprocessable_entity
    end
    get "/api/v1/platform/learning-resources/#{@private.id}"
    assert_response :not_found
    get "/api/v1/learning/resources/#{@resource.id}/details"
    assert_response :unauthorized
  end
  test 'thumbnails remain publication gated while resource content remains authenticated' do
    @resource.thumbnail.attach(io:File.open(file_fixture('branding.png')),filename:'branding.png',content_type:'image/png')
    get "/api/v1/platform/learning-resources/#{@resource.id}/thumbnail"
    assert_response :ok
    assert_equal file_fixture('branding.png').binread,response.body.b
    @resource.update!(published:false)
    get "/api/v1/platform/learning-resources/#{@resource.id}/thumbnail"
    assert_response :not_found
    get "/api/v1/platform/learning-resources/#{@resource.id}"
    assert_response :not_found
  end
  test 'bookmarks are idempotent private and supported for every active account role' do
    put "/api/v1/me/resource-bookmarks/#{@resource.id}"
    assert_response :unauthorized
    get '/api/v1/platform/learning-resources',params:{saved:true}
    assert_response :unauthorized
    %w[mentee mentor organization founder admin super_admin].each do |role|
      user=create_user(role:create_role(role),email:"library-#{role}-save@example.test")
      assert_difference('ResourceBookmark.count',1) do
        2.times do
          put "/api/v1/me/resource-bookmarks/#{@resource.id}",headers:auth_headers(user)
          assert_response :no_content
        end
      end
      get '/api/v1/me/resource-bookmarks',headers:auth_headers(user)
      assert_equal [@resource.id],response.parsed_body['resource_ids']
      assert_no_difference('ResourceBookmark.count') do
        put "/api/v1/me/resource-bookmarks/#{@private.id}",headers:auth_headers(user)
        assert_response :not_found
      end
      delete "/api/v1/me/resource-bookmarks/#{@resource.id}",headers:auth_headers(user)
      assert_response :no_content
    end
    ResourceBookmark.create!(user:@learner,platform_resource:@resource)
    ResourceBookmark.create!(user:@admin,platform_resource:@other)
    get '/api/v1/platform/learning-resources',params:{saved:true},headers:auth_headers(@learner)
    assert_equal [@resource.id],response.parsed_body['items'].map{|r|r['id']}
    assert_equal 'private, no-store',response.headers['Cache-Control']
    @resource.update!(published:false)
    get '/api/v1/me/resource-bookmarks',headers:auth_headers(@learner)
    assert_empty response.parsed_body['resource_ids']
    delete "/api/v1/me/resource-bookmarks/#{@other.id}",headers:auth_headers(@learner)
    assert ResourceBookmark.exists?(user:@admin,platform_resource:@other)
  end
  test 'admin library metadata is validated audited and saved with thumbnails and versions' do
    @resource.file.attach(io:File.open(file_fixture('notes.txt')),filename:'notes.txt',content_type:'text/plain')
    @resource.reload
    details={category:'academic',learning_paths:['primary'],format:'study_material',level:'beginner',page_count:10,featured:true}
    patch "/api/v1/admin/resources/#{@resource.id}/details",headers:auth_headers(@admin),params:{details:{lock_version:@resource.lock_version,library_details_json:details.to_json,thumbnail:fixture_file_upload('branding.png','image/png')}}
    assert_response :ok
    assert_equal details.stringify_keys,@resource.reload.library_details
    assert @resource.thumbnail.attached?
    assert_equal file_fixture('notes.txt').binread,@resource.file.download
    assert @resource.resource_versions.last.snapshot.key?('library_details')
    [{category:'unknown'},{learning_paths:['primary','primary']},{page_count:0},{featured:'true'},{unknown:'bad'}].each do |invalid|
      patch "/api/v1/admin/resources/#{@resource.id}/details",headers:auth_headers(@admin),params:{details:{lock_version:@resource.lock_version,library_details_json:details.merge(invalid).to_json}}
      assert_response :unprocessable_entity
      assert_equal details.stringify_keys,@resource.reload.library_details
    end
    patch "/api/v1/admin/resources/#{@resource.id}/details",headers:auth_headers(@learner),params:{details:{lock_version:@resource.lock_version,library_details_json:details.to_json}}
    assert_response :forbidden
  end
end
