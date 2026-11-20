require 'test_helper'
# Active Storage bytes are uploaded after commit, so this test uses real transactions.
class Api::V1::MentorApplicationStorageTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests=false
  setup do
    @existing_role=Role.find_by(name:'mentee')
    @user=create_user(role:create_role('mentee'),email:"onboarding-storage-#{SecureRandom.hex(6)}@example.test")
    @headers=auth_headers(@user);@blobs=[]
    get '/api/v1/me/mentor-application',headers:@headers;assert_response :ok
    @application=@user.reload.mentor_application
  end
  teardown do
    role_id=@user.role_id
    @application.destroy! if @application.persisted?
    @blobs.each{|blob|blob.purge if ActiveStorage::Blob.exists?(blob.id)}
    @user.destroy!
    Role.where(id:role_id).delete_all unless @existing_role
  end
  test 'all committed uploads download bytes and return the current revision for subsequent edits' do
    bytes=File.binread(Rails.root.join('test/fixtures/files/branding.png'))
    revision=@application.lock_version
    MentorApplication::UPLOADS.each do |kind|
      file=Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/branding.png'),'image/png')
      post "/api/v1/me/mentor-application/documents/#{kind}",params:{file:file,lock_version:revision},headers:@headers
      assert_response :ok
      revision=response.parsed_body['lock_version']
      assert_equal @application.reload.lock_version,revision
      blob=@application.public_send(kind).blob;@blobs<<blob
      assert blob.service.exist?(blob.key),'Successful upload must have committed the file bytes'
      get "/api/v1/me/mentor-application/documents/#{kind}",headers:@headers
      assert_response :ok;assert_equal bytes,response.body.b
    end
    patch '/api/v1/me/mentor-application',params:{application:{headline:'Updated after three uploads'},lock_version:revision},headers:@headers,as: :json
    assert_response :ok
    revision=response.parsed_body['lock_version']
    delete '/api/v1/me/mentor-application/documents/identity_document',params:{lock_version:revision},headers:@headers
    assert_response :ok;assert_nil response.parsed_body.dig('documents','identity_document')
    assert_equal @application.reload.lock_version,response.parsed_body['lock_version']
    get '/api/v1/me/mentor-application/documents/identity_document',headers:@headers;assert_response :not_found
  end
end
