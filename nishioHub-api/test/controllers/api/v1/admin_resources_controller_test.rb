require 'test_helper'
require 'csv'
class Api::V1::AdminResourcesControllerTest < ActionDispatch::IntegrationTest
  ROOT = '/api/v1/admin/resources'
  setup do
    SystemSetting.current.update!(values: SystemSetting::DEFAULTS)
    @admin = create_user(role: create_role('admin'), email: 'resources-admin@example.test')
    @super = create_user(role: create_role('super_admin'), email: 'resources-super@example.test')
    @mentee = create_mentee
    @program = PlatformProgram.create!(title: 'Data Science Program')
    @headers = auth_headers(@admin)
  end
  def body = response.parsed_body
  def draft(**fields) = { title: 'Learning Guide', description: 'Build practical skills', resource_type: 'link', status: 'draft', url: 'https://example.com/guide', platform_program_id: @program.id, tags: ['Python'] }.merge(fields)
  def add_resource(**fields)
    post ROOT, headers: @headers, params: { resource: draft(**fields) }, as: :json
    assert_response :created
    PlatformResource.find(body['id'])
  end
  def pdf
    file = Tempfile.new(['resource', '.pdf']); file.binmode; file.write("%PDF-1.4\n%Learning Guide\n%%EOF\n"); file.flush
    [file, Rack::Test::UploadedFile.new(file.path, 'application/pdf')]
  end
  def csv(rows)
    file = Tempfile.new(['resources', '.csv']); file.write(CSV.generate { |out| out << AdminResourceImport::HEADERS; rows.each { |r| out << r } }); file.flush
    [file, Rack::Test::UploadedFile.new(file.path, 'text/csv')]
  end
  test 'admin and super admin can read and read only accounts cannot mutate' do
    get ROOT
    assert_response :unauthorized
    get ROOT, headers: auth_headers(@mentee)
    assert_response :forbidden
    [@admin, @super].each do |u|
      get ROOT, headers: auth_headers(u)
      assert_response :ok
      assert body.dig('capabilities', 'manage')
      assert_equal 'private, no-store', response.headers['Cache-Control']
    end
    @admin.role.update!(permissions: ['dashboard.read'])
    post ROOT, headers: @headers, params: { resource: draft }, as: :json
    assert_response :forbidden
    get ROOT, headers: @headers
    assert_not body.dig('capabilities', 'manage')
    @admin.role.update!(permissions: [])
    get ROOT, headers: @headers
    assert_response :forbidden
  end
  test 'types program keyword uploader status filters and pagination are applied on server' do
    course = add_resource(resource_type: 'course', title: 'Agriculture Course', status: 'published')
    add_resource(resource_type: 'video', title: 'Programming Video')
    get ROOT, headers: @headers, params: { tab: 'course', program_id: @program.id, q: 'Python', status: 'published', sort: 'title', direction: 'asc' }
    assert_response :ok
    assert_equal [course.id], body['items'].map { |r| r['id'] }
    assert_equal @admin.id, body['items'].first.dig('uploaded_by', 'id')
    assert_equal 2, body.dig('stats', 'total')
    get ROOT, headers: @headers, params: { page: 2 }
    assert_empty body['items']
    assert_equal 2, body.dig('meta', 'total')
    [{type:'unknown'},{status:'x'},{program_id:'x'},{sort:'SQL'},{direction:'sideways'},{per_page:100},{months:2}].each do |args|
      get ROOT, headers: @headers, params: args
      assert_response :unprocessable_entity
    end
  end
  test 'resource engagement comes from recorded accesses and staff previews add no events' do
    resource = add_resource(status: 'published')
    3.times { PlatformResourceAccess.create!(platform_resource: resource, user: @mentee, kind: 'link') }
    get ROOT, headers: @headers
    assert_response :ok
    assert_equal 3, body['items'].first['views']
    assert_equal resource.id, body['top_resources'].first['id']
    assert_equal 3, body['trend'].sum { |v| v['views'] }
    assert_equal 1, body['distribution'].sum { |v| v['count'] }
    post "/api/v1/learning/resources/#{resource.id}/access", headers: @headers
    assert_response :no_content
    assert_equal 3, PlatformResourceAccess.count
    post "/api/v1/learning/resources/#{resource.id}/access", headers: auth_headers(@mentee)
    assert_response :no_content
    get "#{ROOT}/#{resource.id}", headers: @headers
    assert_equal 4, body['link_opens']
    assert_equal 1, body['unique_users']
    assert_not_includes response.body, @mentee.email
  end
  test 'multipart files persist download safely and removing sole content rolls back' do
    temp, upload = pdf
    post ROOT, headers: @headers, params: { resource: draft(resource_type: 'document', url: '', file: upload) }
    assert_response :created
    resource = PlatformResource.find(body['id'])
    assert resource.file.attached?
    assert_equal 'document', resource.resource_type
    get "#{ROOT}/#{resource.id}/file", headers: @headers
    assert_response :ok
    assert_includes response.body, '%PDF'
    assert_equal 0, PlatformResourceAccess.count
    get "/api/v1/learning/resources/#{resource.id}/file", headers: auth_headers(@mentee)
    assert_response :not_found
    patch "#{ROOT}/#{resource.id}", headers: @headers, params: { resource: { status: 'published', lock_version: resource.lock_version } }, as: :json
    assert_response :ok
    get "/api/v1/learning/resources/#{resource.id}/file", headers: auth_headers(@mentee)
    assert_response :ok
    assert_equal 1, PlatformResourceAccess.count
    patch "#{ROOT}/#{resource.id}", headers: @headers, params: { resource: { remove_file: true, lock_version: resource.reload.lock_version } }, as: :json
    assert_response :unprocessable_entity
    assert resource.reload.file.attached?
    patch "#{ROOT}/#{resource.id}", headers: @headers, params: { resource: { remove_file: true, url: 'https://example.com/new', resource_type: 'link', lock_version: resource.lock_version } }, as: :json
    assert_response :ok
    assert_not resource.reload.file.attached?
    assert_equal 1, resource.platform_resource_accesses.count
    temp.close!
  end
  test 'invalid content type unsafe URL tags and stale revisions are rejected' do
    [{url:''},{url:'javascript:alert(1)'},{url:'https://user:password@example.com'},{resource_type:'bogus'},{tags:'bad'},{tags:Array.new(21,'tag')}].each do |change|
      post ROOT, headers: @headers, params: { resource: draft(**change) }, as: :json
      assert_response :unprocessable_entity
    end
    assert_equal 0, PlatformResource.count
    resource = add_resource
    patch "#{ROOT}/#{resource.id}", headers: @headers, params: { resource: { title: 'Stale', lock_version: 9999 } }, as: :json
    assert_response :conflict
    assert_equal 'Learning Guide', resource.reload.title
    file, upload = pdf
    post ROOT, headers: @headers, params: { resource: draft(resource_type: 'video', file: upload) }
    assert_response :unprocessable_entity
    assert_equal 1, PlatformResource.count
    file.close!
  end
  test 'bulk state changes are atomic and archiving preserves content history and learner hiding' do
    first = add_resource(status: 'published'); second = add_resource(title: 'Second Guide', status: 'published')
    PlatformResourceAccess.create!(platform_resource: first, user: @mentee, kind: 'link')
    values = { resource_ids: [first.id,second.id], versions: { first.id => first.lock_version,second.id => 999 }, status: 'archived' }
    post "#{ROOT}/bulk-status", headers: @headers, params: values, as: :json
    assert_response :conflict
    assert first.reload.published?
    values[:versions][second.id] = second.reload.lock_version
    post "#{ROOT}/bulk-status", headers: @headers, params: values, as: :json
    assert_response :ok
    assert first.reload.archived?
    assert_not first.published?
    assert_equal 1, first.platform_resource_accesses.count
    post "/api/v1/learning/resources/#{first.id}/access", headers: auth_headers(@mentee)
    assert_response :not_found
    get '/api/v1/me/learning_area', headers: auth_headers(@mentee)
    assert_response :ok
    assert_empty body['shared_resources']
  end
  test 'CSV exports are filtered selected and neutralize spreadsheet formulas' do
    resource = add_resource(title: '=FORMULA', status: 'published')
    add_resource(title: 'Other')
    get "#{ROOT}/export", headers: @headers, params: { resource_ids: [resource.id], status: 'published' }
    assert_response :ok
    rows = CSV.parse(response.body, headers: true)
    assert_equal 1, rows.size
    assert_equal "'=FORMULA", rows.first['title']
    assert_not_includes response.body, @mentee.email
  end
  test 'CSV preview is read only and commit preserves each program assignment or blank' do
    rows = [['Imported Course','A course','course',@program.id,'https://example.com/course','published','Python;Career'],['Independent Guide','A guide','document','','https://example.com/doc','draft','']]
    file, uploaded = csv(rows)
    post "#{ROOT}/import-preview", headers: @headers, params: {file:uploaded}
    assert_response :ok
    assert body['valid']
    assert_equal 0, PlatformResource.count
    post "#{ROOT}/import", headers: @headers, params: {file:Rack::Test::UploadedFile.new(file.path,'text/csv')}
    assert_response :created
    assert_equal 2, body['imported']
    assert_equal @program.id, PlatformResource.find_by!(title:'Imported Course').platform_program_id
    assert_nil PlatformResource.find_by!(title:'Independent Guide').platform_program_id
    file.close!
    file, uploaded = csv([rows.first,['Bad','Invalid','link','','javascript:evil','published','']])
    post "#{ROOT}/import", headers: @headers, params: {file:uploaded}
    assert_response :unprocessable_entity
    assert_equal 2, PlatformResource.count
    file.close!
  end
end
