class MenteeAchievements
  def initialize(user)
    @user = user
  end

  def as_json(*)
    {
      name: @user.full_name, avatar: @user.avatar_url, vision: @user.mentee_profile&.vision,
      summary: { courses: completed_enrollments.size, badges: badges.count { |badge| badge[:earned] },
        certificates: certificates.size, progress: overall_progress },
      badges: badges, certificates: certificates, achievements: achievements, milestones: milestones
    }
  end

  def badges
    @badges ||= begin
      completions = completed_enrollments.map { |enrollment| completion_time(enrollment) }.sort
      active_date = completions.group_by { |time| time.in_time_zone(SystemSetting.config["timezone"]).strftime("%Y-%m") }.values
        .filter_map { |month| month[2] if month.size >= 3 }.min
      goals = @user.mentee_goals.where(completed: true).order(:updated_at)
      sessions = @user.mentee_bookings.where(status: "completed").order(:updated_at).limit(10).to_a
      innovation = completed_enrollments.find { |enrollment| enrollment.course_key == "innovation" }
      times = [active_date, goals.first&.updated_at, completions.first,
        @user.event_registrations.where(status: "registered").where.not(attended_at: nil).minimum(:attended_at),
        innovation && completion_time(innovation), sessions[0]&.updated_at, sessions[4]&.updated_at, sessions[9]&.updated_at]
      links = ["/learning-area", "/my-goals", "/learning-area", "/events", "/learning-area?course=innovation", "/bookings", "/bookings", "/bookings"]
      automatic = AchievementCatalog::BADGES.each_with_index.map do |(id,name,description,icon,color),i|
        badge(id,name,description,icon,color,times[i],links[i])
      end
      automatic + manual_awards.select{|a|a.kind=='skill_badge'}.map do |a|
        badge("award-#{a.identifier}",a.title,a.description,a.icon,a.color,a.awarded_at,"/learning-area")
      end
    end
  end

  def certificates
    @certificates ||= completed_enrollments.map do |enrollment|
      # Existing completed courses receive a stable certificate on first visit.
      enrollment.with_lock { enrollment.issue_certificate_if_complete } unless enrollment.learning_certificate
      certificate = enrollment.learning_certificate
      { id: certificate.identifier, title: course(enrollment)["title"], course_id: enrollment.course_key,
        issued_at: certificate.issued_at.iso8601 }
    end.concat(manual_awards.select{|a|a.kind=='certificate'}.map{|a|{id:"award-#{a.identifier}",title:a.title,course_id:'',issued_at:a.awarded_at.iso8601}}).sort_by { |certificate| certificate[:issued_at] }.reverse
  end

  private

  def manual_awards
    @manual_awards ||= @user.achievement_awards.active.order(awarded_at: :desc).to_a
  end

  def enrollments
    @enrollments ||= @user.learning_enrollments.includes(:learning_lesson_completions, :learning_certificate).to_a
      .select { |enrollment| course(enrollment) }
  end

  def completed_enrollments
    @completed_enrollments ||= enrollments.select(&:course_complete?)
  end

  def course(enrollment)
    LearningCatalog.find(enrollment.course_key)
  end

  def completion_time(enrollment)
    enrollment.learning_lesson_completions.map(&:created_at).max || enrollment.updated_at
  end

  def overall_progress
    lessons = enrollments.sum { |enrollment| course(enrollment)["lessons"].size }
    completed = enrollments.sum do |enrollment|
      (course(enrollment)["lessons"].map { |lesson| lesson["id"] } & enrollment.completed_lesson_ids).size
    end
    lessons.zero? ? 0 : (completed * 100.0 / lessons).round
  end

  def badge(id, name, description, icon, color, earned_at, href)
    { id: id, name: name, description: description, icon: icon, color: color,
      earned: earned_at.present?, earned_at: earned_at&.iso8601, href: href }
  end

  def achievements
    courses = completed_enrollments.map do |enrollment|
      { id: "course-#{enrollment.id}", title: "Completed: #{course(enrollment)['title']}",
        description: "Finished all #{course(enrollment)['lessons'].size} lessons and practice activities.",
        kind: "completed", icon: "laptop", occurred_at: completion_time(enrollment).iso8601,
        href: "/learning-area?course=#{enrollment.course_key}" }
    end
    sessions = @user.mentee_bookings.where(status: "completed").includes(:service, :mentor).map do |booking|
      { id: "session-#{booking.id}", title: "Attended Mentorship Session",
        description: "#{booking.service.title} with #{booking.mentor.full_name}.", kind: "completed", icon: "users",
        occurred_at: booking.updated_at.iso8601, href: "/bookings" }
    end
    awards = badges.select { |badge| badge[:earned] }.map do |badge|
      { id: "badge-#{badge[:id]}", title: "Earned “#{badge[:name]}” Badge", description: badge[:description],
        kind: "badge", icon: "trophy", occurred_at: badge[:earned_at], href: badge[:href] }
    end
    documents = certificates.map do |certificate|
      { id: "certificate-#{certificate[:id]}", title: "Received Course Certificate", description: certificate[:title],
        kind: "certificate", icon: "certificate", occurred_at: certificate[:issued_at], certificate_id: certificate[:id] }
    end
    custom = manual_awards.reject{|a|%w[skill_badge certificate].include?(a.kind)}.map do |a|
      {id:"award-#{a.identifier}",title:a.title,description:a.description,kind:'completed',icon:a.icon,occurred_at:a.awarded_at.iso8601,href:'/my-achievements'}
    end
    programs = ProgramMembership.where(user:@user,progress:100).where.not(completed_at:nil).includes(:platform_program).map do |m|
      {id:"program-#{m.id}",title:"Completed: #{m.platform_program.title}",description:'Program progress reached 100%.',kind:'completed',icon:'trophy',occurred_at:m.completed_at.iso8601,href:'/my-achievements'}
    end
    (courses + sessions + awards + documents + custom + programs).sort_by { |entry| [entry[:occurred_at], entry[:id]] }.reverse
  end

  def milestones
    GoalMilestone.joins(:mentee_goal).where(mentee_goals: { user_id: @user.id }).includes(:mentee_goal)
      .order(completed: :desc, target_date: :asc, id: :asc).map do |milestone|
        { id: milestone.id, title: milestone.title, goal_title: milestone.mentee_goal.title,
          completed: milestone.completed, target_date: milestone.target_date, href: "/my-goals" }
      end
  end
end
