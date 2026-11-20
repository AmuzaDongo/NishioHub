require 'test_helper'

# Real commits are essential: Active Storage uploads only in after_commit.
class Api::V1::PlatformBrandingTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    @setting = SystemSetting.current
    @previous = @setting.attributes.slice('values', 'updated_by_id', 'updated_at')
    @originals = %w[logo favicon].to_h { |kind| [kind, @setting.public_send(kind).blob] }
    @originals.each_key { |kind| @setting.public_send(kind).detach }
    @existing_role = Role.find_by(name: 'admin')
    @admin = create_user(role: create_role('admin'), email: "branding-#{SecureRandom.hex(5)}@example.test")
    @headers = auth_headers(@admin)
    @blobs = []
  end

  teardown do
    @setting.reload
    %w[logo favicon].each { |kind| @setting.public_send(kind).detach }
    @blobs.each { |blob| blob.purge if ActiveStorage::Blob.exists?(blob.id) }
    @originals.each { |kind, blob| @setting.public_send(kind).attach(blob) if blob }
    @setting.update_columns(@previous)
    SystemSettingAudit.where(actor_id: @admin.id).delete_all
    role_id = @admin.role_id
    @admin.destroy!
    Role.where(id: role_id).delete_all unless @existing_role
  end

  def upload(kind, file, revision: @setting.reload.lock_version)
    post "/api/v1/admin/system_settings/assets/#{kind}", headers: @headers, params: { file: file, lock_version: revision }
    assert_response :ok
    @setting.reload
    assert_equal @setting.lock_version, response.parsed_body['lock_version']
    blob = @setting.public_send(kind).blob
    @blobs << blob
    assert blob.service.exist?(blob.key), 'The image bytes must exist after a successful upload'
    blob
  end

  test 'committed branding uploads serve actual image bytes through stable public URLs' do
    bytes = File.binread(Rails.root.join('test/fixtures/files/branding.png'))
    initial_revision = @setting.lock_version
    upload('logo', Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/branding.png'), 'image/png'))
    assert @setting.lock_version > initial_revision
    logo_url = response.parsed_body.dig('assets', 'logo_url')
    assert_includes logo_url, '/rails/active_storage/blobs/proxy/'
    get logo_url
    assert_response :ok
    assert_equal bytes, response.body.b

    upload('favicon', Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/branding.png'), 'image/png'))
    favicon_url = response.parsed_body.dig('assets', 'favicon_url')
    assert_equal 'image/png', response.parsed_body.dig('assets', 'favicon_content_type')
    get '/api/v1/platform/config'
    assert_response :ok
    assert_equal logo_url, response.parsed_body['logo_url']
    assert_equal favicon_url, response.parsed_body['favicon_url']
    travel 2.hours do
      get logo_url
      assert_response :ok
      assert_equal bytes, response.body.b
    end

    # A replacement gets a new immutable URL and rejects edits with the old revision.
    stale_revision = @setting.lock_version
    upload('logo', Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/branding.png'), 'image/png'))
    replacement_url = response.parsed_body.dig('assets', 'logo_url')
    assert_not_equal logo_url, replacement_url
    delete '/api/v1/admin/system_settings/assets/logo', headers: @headers, params: { lock_version: stale_revision }, as: :json
    assert_response :conflict
    delete '/api/v1/admin/system_settings/assets/logo', headers: @headers, params: { lock_version: @setting.reload.lock_version }, as: :json
    assert_response :ok
    assert_nil response.parsed_body.dig('assets', 'logo_url')
    delete '/api/v1/admin/system_settings/assets/favicon', headers: @headers, params: { lock_version: @setting.reload.lock_version }, as: :json
    assert_response :ok
    assert_nil response.parsed_body.dig('assets', 'favicon_url')
    assert_nil response.parsed_body.dig('assets', 'favicon_content_type')
  end

  test 'ICO favicon bytes persist and retain their browser content type' do
    png = File.binread(Rails.root.join('test/fixtures/files/branding.png'))
    ico = [0, 1, 1].pack('vvv') + [1, 1, 0, 0, 1, 32, png.bytesize, 22].pack('CCCCvvVV') + png
    Tempfile.create(['branding', '.ico']) do |file|
      file.binmode; file.write(ico); file.flush
      upload('favicon', Rack::Test::UploadedFile.new(file.path, 'image/x-icon'))
      assert_includes %w[image/x-icon image/vnd.microsoft.icon], response.parsed_body.dig('assets', 'favicon_content_type')
      get response.parsed_body.dig('assets', 'favicon_url')
      assert_response :ok
      assert_equal ico, response.body.b
    end
  end
end
