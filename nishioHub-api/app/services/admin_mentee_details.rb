class AdminMenteeDetails
  def initialize(user, actor)
    @user, @actor = user, actor
  end
  def call
    mentee = AdminMenteeQuery.rows(AdminMenteeQuery.base.where(users: { id: @user.id }), @actor).first
    progress = courses
    completed = @user.mentee_bookings.where(status: 'completed')
    reviews = @user.given_reviews.joins(:booking).where(bookings: { status: 'completed' })
    accesses = PlatformResourceAccess.where(user: @user)
    timeline = AdminMenteeTimeline.new(@user)
    badges = earned_badges
    known = ConversationMembership.where(conversation_id: @actor.conversation_memberships.select(:conversation_id)).exists?(user_id: @user.id)
    selected_program = PlatformProgram.find_by(id: mentee.dig(:program, :id))
    { mentee: mentee, expected_completion: selected_program&.ends_on&.iso8601,
      satisfaction: { rating: reviews.average(:rating)&.to_f&.round(1), count: reviews.count },
      stats: { sessions_attended: completed.count, completed: progress.count { |c| c[:completed] }, in_progress: progress.count { |c| !c[:completed] },
        resources_used: accesses.distinct.count(:platform_resource_id), achievements: badges.size, engagement: timeline.engagement },
      profile: { education: @user.mentee_profile&.education, interests: @user.mentee_profile&.interests || [], bio: @user.mentee_profile&.bio || @user.profile&.bio,
        location: @user.mentee_profile&.location.presence || [@user.profile&.city, @user.profile&.country].compact.join(', '), school: @user.mentee_profile&.school, grade: @user.mentee_profile&.grade },
      progress: progress.first(4), goals: goals(@user.mentee_goals.kept.order(completed: :desc, created_at: :desc).limit(4)),
      sessions: sessions(@user.mentee_bookings.order(scheduled_at: :desc).limit(3)), achievements: badges.first(3),
      activity_summary: { since: 30.days.ago.iso8601, sessions_attended: completed.where(updated_at: 30.days.ago..Time.current).count,
        resources_accessed: accesses.where(created_at: 30.days.ago..Time.current).count,
        mentor_interactions: timeline.interactions.where(created_at: 30.days.ago..Time.current).count, time_on_platform_minutes: nil },
      capabilities: { manage_sessions: @actor.management_permission?('dashboard.read') && @actor.management_permission?('dashboard.manage'),
        message: @user.id != @actor.id && @user.is_active? && (@user.account_setting&.allow_contact_requests != false || known),
        export: @actor.management_permission?('users.export') } }
  end
  def section(kind, page, query)
    return AdminMenteeTimeline.new(@user).page(page, query) if kind == 'activity'
    case kind
    when 'sessions'
      scope = @user.mentee_bookings.joins(:service)
      scope = scope.where('services.title ILIKE ?', term(query)) if query.present?
      paginated(scope, page) { |rows| sessions(rows.order(scheduled_at: :desc)) }
    when 'goals'
      scope = @user.mentee_goals.kept
      scope = scope.where('title ILIKE ?', term(query)) if query.present?
      paginated(scope, page) { |rows| goals(rows.order(completed: :asc, created_at: :desc)) }
    when 'reviews'
      scope = @user.given_reviews.joins(:booking).where(bookings: { status: 'completed' })
      scope = scope.where('comment ILIKE ?', term(query)) if query.present?
      paginated(scope, page) { |rows| rows.includes(:mentor, :service).order(created_at: :desc).map { |review| { id: review.id, rating: review.rating, comment: review.comment, mentor: review.mentor.full_name, service: review.service.title, created_at: review.created_at.iso8601 } } }
    when 'progress'
      list_page(courses.select { |c| query.blank? || c[:title].downcase.include?(query.downcase) }, page)
    when 'achievements'
      certificates = LearningCertificate.joins(:learning_enrollment).where(learning_enrollments: { user_id: @user.id }).includes(:learning_enrollment).order(issued_at: :desc).filter_map do |cert|
        course = LearningCatalog.find(cert.learning_enrollment.course_key)
        next unless course && cert.learning_enrollment.course_complete?
        { id: cert.identifier, name: course['title'], description: 'Course completion certificate', icon: 'certificate', color: 'blue', kind: 'certificate', earned_at: cert.issued_at.iso8601 }
      end
      certificates += @user.achievement_awards.active.where(kind:'certificate').map do |award|
        {id:"award-#{award.identifier}",name:award.title,description:award.description,icon:'certificate',color:award.color,kind:'certificate',earned_at:award.awarded_at.iso8601}
      end
      list = earned_badges + certificates
      list_page(list.select { |item| query.blank? || "#{item[:name]} #{item[:description]}".downcase.include?(query.downcase) }, page)
    else raise Administration::Rejected.new('Choose sessions, progress, goals, achievements, reviews or activity', :unprocessable_entity)
    end
  end
  private
  def term(query) = "%#{ActiveRecord::Base.sanitize_sql_like(query.first(150))}%"
  def courses
    @courses ||= @user.learning_enrollments.order(:created_at).filter_map do |enrollment|
      course = LearningCatalog.find(enrollment.course_key)
      next unless course
      lessons = course['lessons'].map { |lesson| { id: lesson['id'], title: lesson['title'], completed: enrollment.completed_lesson_ids.include?(lesson['id']) } }
      done = lessons.count { |lesson| lesson[:completed] }
      { id: enrollment.id, title: course['title'], course_key: course['id'], completed: done == lessons.size, progress: lessons.empty? ? 0 : (done * 100.0 / lessons.size).round, completed_lessons: done, total_lessons: lessons.size, lessons: lessons }
    end
  end
  def earned_badges = @badges ||= MenteeAchievements.new(@user).badges.select { |badge| badge[:earned] }.map { |badge| badge.slice(:id, :name, :description, :icon, :color, :earned_at).merge(kind: 'badge') }
  def sessions(scope)
    scope.includes(:service, :mentor).map { |booking| { id: booking.id, title: booking.service.title, mentor: booking.mentor.full_name, status: booking.status, scheduled_at: booking.scheduled_at.iso8601, duration: booking.duration, updated_at: booking.updated_at.iso8601(6), can_complete: booking.status == 'confirmed' && booking.scheduled_at + booking.duration.minutes <= Time.current } }
  end
  def goals(scope)
    scope.map { |goal| { id: goal.id, title: goal.title, description: goal.description, progress: goal.progress, completed: goal.completed, target_date: goal.target_date&.iso8601,
      milestone_count: goal.goal_milestones.count, milestones: goal.goal_milestones.order(:id).limit(20).as_json(only: %i[id title completed target_date]) } }
  end
  def paginated(scope, page)
    total = scope.count
    { items: yield(scope.limit(20).offset((page - 1) * 20)), meta: { page: page, total: total, total_pages: (total / 20.0).ceil, per_page: 20 } }
  end
  def list_page(items, page)
    { items: items.slice((page - 1) * 20, 20) || [], meta: { page: page, total: items.size, total_pages: (items.size / 20.0).ceil, per_page: 20 } }
  end
end
