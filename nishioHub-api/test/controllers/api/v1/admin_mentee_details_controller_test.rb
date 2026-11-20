require 'test_helper'
class Api::V1::AdminMenteeDetailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.current.update!(values: SystemSetting::DEFAULTS)
    @admin = create_user(role: create_role('admin'), email: 'details-admin@example.test')
    @super = create_user(role: create_role('super_admin'), email: 'details-super@example.test')
    @mentee = create_mentee
    @mentor = create_mentor
    @service = create_service(mentor: @mentor)
    @headers = auth_headers(@admin)
    @root = "/api/v1/admin/mentees/#{@mentee.id}"
  end
  def body = response.parsed_body
  def overview
    get "#{@root}/details", headers: @headers
    assert_response :ok
    body
  end
  def enrollment(complete: false)
    course = LearningCatalog.courses.first
    @mentee.learning_enrollments.create!(course_key: course['id'], completed_lesson_ids: complete ? course['lessons'].map { |l| l['id'] } : [course['lessons'].first['id']])
  end
  test 'details and sections require staff and users read permission' do
    get "#{@root}/details"
    assert_response :unauthorized
    [@mentee, @mentor].each do |person|
      get "#{@root}/details", headers: auth_headers(person)
      assert_response :forbidden
      get "#{@root}/sections/activity", headers: auth_headers(person)
      assert_response :forbidden
    end
    [@admin, @super].each do |person|
      get "#{@root}/details", headers: auth_headers(person)
      assert_response :ok
      assert_equal 'private, no-store', response.headers['Cache-Control']
    end
    @admin.role.update!(permissions: ['users.read'])
    data = overview
    assert_not data.dig('capabilities', 'manage_sessions')
    assert_not data.dig('capabilities', 'export')
    @admin.role.update!(permissions: [])
    get "#{@root}/details", headers: @headers
    assert_response :forbidden
    get "/api/v1/admin/mentees/#{@super.id}/details", headers: auth_headers(@super)
    assert_response :not_found
  end
  test 'empty details show zero actual metrics and do not invent time satisfaction or dates' do
    data = overview
    assert_nil data['expected_completion']
    assert_nil data.dig('satisfaction', 'rating')
    assert_nil data.dig('activity_summary', 'time_on_platform_minutes')
    assert_equal 0, data.dig('stats', 'sessions_attended')
    assert_empty data['sessions']
    assert_empty data['achievements']
    assert_empty data['progress']
    assert_empty data['goals']
    assert_not_includes response.body, 'hashed_password'
    assert_nil @mentee.reload.last_active_at
  end
  test 'overview derives profile goals course completion progress badges and program date' do
    program = PlatformProgram.create!(title: 'Data Science', ends_on: Date.new(2026, 12, 20))
    program.program_memberships.create!(user: @mentee)
    @mentee.create_mentee_profile!(school: 'School', grade: 'P6', education: 'BCA', interests: ['Data Science', 'AI'], bio: 'Learning to build useful software.', primary_program: program)
    @mentee.mentee_goals.create!(title: 'Learn', progress: 80)
    @mentee.mentee_goals.create!(title: 'Build', progress: 100)
    enrollment(complete: true)
    create_booking(service: @service, mentor: @mentor, mentee: @mentee, status: 'completed', scheduled_at: 2.days.ago)
    assert_no_difference 'LearningCertificate.count' do
      data = overview
      assert_equal '2026-12-20', data['expected_completion']
      assert_equal 'BCA', data.dig('profile', 'education')
      assert_equal ['Data Science', 'AI'], data.dig('profile', 'interests')
      assert_equal 90, data.dig('mentee', 'progress')
      assert_equal 1, data.dig('stats', 'completed')
      assert_equal 1, data.dig('stats', 'sessions_attended')
      assert_equal 100, data['progress'].first['progress']
      assert_equal 3, data.dig('stats', 'achievements')
    end
  end
  test 'sections paginate and filter only the selected mentee records' do
    22.times { |i| @mentee.mentee_goals.create!(title: "Goal #{i}", progress: i) }
    other = create_mentee(email: 'details-other@example.test')
    other.mentee_goals.create!(title: 'SECRET OTHER GOAL', progress: 80)
    get "#{@root}/sections/goals", headers: @headers, params: { page: 2 }
    assert_response :ok
    assert_equal 22, body.dig('meta', 'total')
    assert_equal 2, body['items'].size
    assert_not_includes response.body, 'SECRET OTHER GOAL'
    get "#{@root}/sections/goals", headers: @headers, params: { q: 'Goal 21' }
    assert_equal 1, body['items'].size
    get "#{@root}/sections/invalid", headers: @headers
    assert_response :unprocessable_entity
    get "#{@root}/sections/activity", headers: @headers, params: { page: 2 }
    assert_response :ok
    assert_equal 2, body['items'].size
  end
  test 'all section types show persisted reviews sessions progress and achievements' do
    booking = create_booking(service: @service, mentor: @mentor, mentee: @mentee, status: 'completed')
    booking.create_review!(service: @service, mentor: @mentor, mentee: @mentee, rating: 4, comment: 'Practical advice')
    enrollment(complete: true)
    %w[sessions progress achievements reviews activity].each do |section|
      get "#{@root}/sections/#{section}", headers: @headers
      assert_response :ok
      assert body['items'].present?, section
    end
    data = overview
    assert_equal 4.0, data.dig('satisfaction', 'rating')
    assert_equal 1, data.dig('satisfaction', 'count')
  end
  test 'mentor interaction counts never expose private chat content or unrelated messages' do
    conversation = Conversation.create!(creator: @mentee, kind: 'direct', direct_key: [@mentee.id, @mentor.id].sort.join(':'))
    [@mentee, @mentor].each { |u| conversation.conversation_memberships.create!(user: u) }
    conversation.chat_messages.create!(sender: @mentee, content: 'SECRET MENTEE CHAT')
    conversation.chat_messages.create!(sender: @mentor, content: 'SECRET MENTOR CHAT')
    data = overview
    assert_equal 2, data.dig('activity_summary', 'mentor_interactions')
    assert_not_includes response.body, 'SECRET'
    get "#{@root}/sections/activity", headers: @headers
    assert_response :ok
    assert_equal 2, body['items'].size
    assert_not_includes response.body, 'SECRET'
    get "/api/v1/conversations/#{conversation.id}/messages", headers: @headers
    assert_response :not_found
    get "#{@root}/sections/activity", headers: @headers, params: { q: 'SECRET MENTOR CHAT' }
    assert_empty body['items']
  end
  test 'engagement counts real local learner days and excludes administrator audits' do
    travel_to Time.iso8601('2026-11-09T09:00:00Z') do
      @mentee.update_columns(created_at: 29.days.ago, last_active_at: Time.iso8601('2026-11-08T21:30:00Z'))
      @mentee.mentee_goals.create!(title: 'One recorded day')
      Administration.audit!(@admin, 'mentee.updated', @mentee, {})
      data = overview
      assert_equal 1, data.dig('stats', 'engagement', 'active_days')
      assert_equal 30, data.dig('stats', 'engagement', 'days')
      assert_equal 3, data.dig('stats', 'engagement', 'percent')
    end
  end
  test 'profile editing persists education interests bio and detects stale revisions' do
    item = overview['mentee']
    patch @root, headers: @headers, params: { mentee: { education: 'Software Engineering', interests: [' Data Science ', 'AI', 'AI'], bio: 'Build technology for my community.', lock_version: item['lock_version'], profile_version: item['profile_version'] } }, as: :json
    assert_response :ok
    assert_equal ['Data Science', 'AI'], @mentee.mentee_profile.reload.interests
    assert_equal 'Software Engineering', @mentee.mentee_profile.education
    patch @root, headers: @headers, params: { mentee: { bio: 'Stale', lock_version: item['lock_version'], profile_version: item['profile_version'] } }, as: :json
    assert_response :conflict
    item = overview['mentee']
    [Array.new(13, 'Interest'), [123], 'not-an-array'].each do |interests|
      # Use distinct values to exercise the post-normalization array limit.
      interests = 13.times.map { |i| "Interest #{i}" } if interests.is_a?(Array) && interests.size == 13
      patch @root, headers: @headers, params: { mentee: { interests: interests, lock_version: item['lock_version'], profile_version: item['profile_version'] } }, as: :json
      assert_response :unprocessable_entity
    end
  end
  test 'photo uploads enforce permission MIME type and displayed revision' do
    item = overview['mentee']
    post "#{@root}/avatar", headers: @headers, params: { avatar: Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/notes.txt'), 'image/png'), lock_version: item['lock_version'] }
    assert_response :unprocessable_entity
    post "#{@root}/avatar", headers: @headers, params: { avatar: Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/profile-photo.png'), 'image/png'), lock_version: item['lock_version'] }
    assert_response :ok
    assert @mentee.reload.avatar.attached?
    assert body['avatar'].present?
    post "#{@root}/avatar", headers: @headers, params: { avatar: Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/profile-photo.png'), 'image/png'), lock_version: item['lock_version'] }
    assert_response :conflict
    @admin.role.update!(permissions: ['users.read'])
    post "#{@root}/avatar", headers: @headers, params: { avatar: Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/profile-photo.png'), 'image/png'), lock_version: @mentee.reload.lock_version }
    assert_response :forbidden
  end
  test 'certificate downloads are scoped to the mentee and require export permission' do
    enrollment(complete: true)
    certificate = @mentee.learning_enrollments.first.learning_certificate
    get "#{@root}/certificates/#{certificate.identifier}", headers: @headers
    assert_response :ok
    assert_includes response.media_type, 'image/svg+xml'
    other = create_mentee(email: 'certificate-other@example.test')
    get "/api/v1/admin/mentees/#{other.id}/certificates/#{certificate.identifier}", headers: @headers
    assert_response :not_found
    @admin.role.update!(permissions: ['users.read'])
    get "#{@root}/certificates/#{certificate.identifier}", headers: @headers
    assert_response :forbidden
  end
  test 'published resource link and file accesses are recorded only for the authenticated user' do
    resource = PlatformResource.create!(title: 'Useful resource', url: 'https://example.com/guide')
    resource.file.attach(io: StringIO.new('Useful notes'), filename: 'notes.txt', content_type: 'text/plain')
    post "/api/v1/learning/resources/#{resource.id}/access"
    assert_response :unauthorized
    post "/api/v1/learning/resources/#{resource.id}/access", headers: auth_headers(@mentee), params: { user_id: @admin.id }
    assert_response :no_content
    get "/api/v1/learning/resources/#{resource.id}/file", headers: auth_headers(@mentee)
    assert_response :ok
    assert_equal [@mentee.id], PlatformResourceAccess.distinct.pluck(:user_id)
    data = overview
    assert_equal 1, data.dig('stats', 'resources_used')
    assert_equal 2, data.dig('activity_summary', 'resources_accessed')
    resource.reload.update!(published: false)
    post "/api/v1/learning/resources/#{resource.id}/access", headers: auth_headers(@mentee)
    assert_response :not_found
    assert_equal 2, PlatformResourceAccess.count
  end
end
