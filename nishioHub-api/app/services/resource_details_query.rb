class ResourceDetailsQuery
  def initialize(resource) = @resource = resource
  def self.content(item) = item.attributes.slice('id','title','body','url','position','start_seconds','lock_version','public_listing').merge('file'=>item.file.attached? ? {filename:item.file.filename.to_s,type:item.file.content_type,size:item.file.byte_size} : nil)
  def metadata
    { page_details: ResourcePageDetails::DEFAULTS.merge(@resource.page_details), library_details: ResourceLibraryDetails::DEFAULTS.merge(@resource.library_details), language: @resource.language, target_audience: @resource.target_audience, module_name: @resource.module_name,
      position: @resource.position, required: @resource.required?, awards: @resource.awards, duration_seconds: @resource.duration_seconds,
      published_at: @resource.published_at&.iso8601, visibility: @resource.visibility,
      thumbnail: @resource.thumbnail.attached? ? @resource.thumbnail.url : nil, captions: @resource.captions.attached?,
      contents_count: @resource.resource_contents.count, shares: @resource.resource_program_shares.includes(:platform_program).map { |s| { id: s.id, program_id: s.platform_program_id, title: s.platform_program.title } } }
  end
  def summary(months = '6')
    raise Administration::Rejected.new('Choose 3, 6 or 12 months', :unprocessable_entity) unless %w[3 6 12].include?(months.to_s)
    progress = @resource.resource_progresses
    recorded_ids = progress.select(:user_id).pluck(:user_id) | @resource.platform_resource_accesses.distinct.pluck(:user_id)
    programs = [@resource.platform_program_id, *@resource.resource_program_shares.pluck(:platform_program_id)].compact
    eligible = User.with_role('mentee').where(is_active: true)
    eligible = eligible.where(id: ProgramMembership.active.where(platform_program_id: programs).select(:user_id)) if @resource.visibility == 'program'
    eligible = eligible.none if @resource.visibility == 'staff'
    total = User.where(id: eligible.select(:id)).or(User.where(id: recorded_ids)).count
    completed = progress.where(percent: 100).count; ongoing = progress.where(percent: 1..99).count
    now = Time.current.in_time_zone(SystemSetting.config['timezone']); month = now.beginning_of_month
    accesses = @resource.platform_resource_accesses
    trend = (months.to_i - 1).downto(0).map { |n| first = month - n.months; { month: first.to_date.iso8601, views: accesses.where(created_at: first...[first + 1.month, now].min).count } }
    first = month - (months.to_i - 1).months; prior = accesses.where(created_at: (first - (now - first))...first).count
    { views: accesses.count, downloads: accesses.where(kind: 'download').count, unique_users: accesses.distinct.count(:user_id),
      completed: completed, in_progress: ongoing, not_started: [total - completed - ongoing, 0].max, audience: total,
      completion_rate: total.zero? ? 0 : (completed * 100.0 / total).round(1), engagement: total.zero? ? 0 : ((completed + ongoing) * 100.0 / total).round,
      rating: @resource.resource_feedbacks.average(:rating)&.to_f&.round(1), feedback_count: @resource.resource_feedbacks.count,
      trend: trend, trend_change: AdminReportingPeriod.change(trend.sum { |p| p[:views] }, prior) }
  end
  def activity
    events = AdministrationAudit.where(target_type: 'PlatformResource', target_id: @resource.id).order(created_at: :desc).limit(10).map { |a| { id: "audit-#{a.id}", title: a.action.delete_prefix('resource.').tr('_', ' '), actor: a.actor_name, created_at: a.created_at.iso8601 } }
    events += @resource.platform_resource_accesses.order(created_at: :desc).limit(10).map { |a| { id: "access-#{a.id}", title: "Resource #{a.kind == 'download' ? 'downloaded' : 'opened'}", actor: 'Learner', created_at: a.created_at.iso8601 } }
    events += @resource.resource_feedbacks.order(updated_at: :desc).limit(5).map { |f| { id: "feedback-#{f.id}", title: "New rating: #{f.rating} / 5", actor: 'Learner', created_at: f.updated_at.iso8601 } }
    events.sort_by { |e| e[:created_at] }.reverse.first(5)
  end
end
