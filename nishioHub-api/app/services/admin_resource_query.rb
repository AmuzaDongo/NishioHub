class AdminResourceQuery
  def initialize(params = {}) = @params = params
  def filtered
    scope = PlatformResource.kept.left_joins(:platform_program, :created_by)
    if @params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(@params[:q].to_s.first(150))}%"
      scope = scope.where('platform_resources.title ILIKE :q OR platform_resources.description ILIKE :q OR platform_resources.tags::text ILIKE :q OR platform_programs.title ILIKE :q OR users.full_name ILIKE :q', q: term)
    end
    %i[tab type].each do |key|
      next if @params[key].blank? || @params[key] == 'all'
      value = @params[key]
      raise Administration::Rejected.new('Invalid resource type', :unprocessable_entity) unless PlatformResource::RESOURCE_TYPES.include?(value)
      scope = scope.where(resource_type: value)
    end
    if @params[:status].present? && @params[:status] != 'all'
      scope = scope.where(AdminResourceManagement.status_attributes(@params[:status]))
    end
    scope = scope.where(platform_program_id: AdminMenteeQuery.positive_id!(@params[:program_id])) if @params[:program_id].present?
    scope
  end
  def ordered(scope = filtered)
    column = { 'added' => 'platform_resources.created_at', 'title' => 'platform_resources.title', 'views' => '(SELECT COUNT(*) FROM platform_resource_accesses a WHERE a.platform_resource_id = platform_resources.id)' }[@params[:sort].presence || 'added']
    direction = @params[:direction].presence || 'desc'
    raise Administration::Rejected.new('Invalid resource sorting', :unprocessable_entity) unless column && %w[asc desc].include?(direction)
    scope.order(Arel.sql("#{column} #{direction.upcase}, platform_resources.id DESC"))
  end
  def self.rows(scope)
    values = scope.includes(:platform_program, created_by: [:profile, :mentor_profile, avatar_attachment: :blob]).with_attached_file.to_a
    views = PlatformResourceAccess.where(platform_resource_id: values.map(&:id)).group(:platform_resource_id).count
    values.map do |r|
      { id: r.id, title: r.title, description: r.description, resource_type: r.resource_type, tags: r.tags,
        status: r.archived? ? 'archived' : r.published? ? 'published' : 'draft',
        program: r.platform_program && { id: r.platform_program_id, title: r.platform_program.title },
        uploaded_by: r.created_by && { id: r.created_by_id, name: r.created_by.full_name, avatar: r.created_by.avatar_url },
        url: r.url, file: r.file.attached? ? { filename: r.file.filename.to_s, size: r.file.byte_size, type: r.file.content_type } : nil,
        views: views.fetch(r.id, 0), created_at: r.created_at.iso8601, lock_version: r.lock_version }
    end
  end
  def report
    now = Time.current.in_time_zone(SystemSetting.config['timezone']); month = now.beginning_of_month
    months = (@params[:months].presence || '6').to_s
    raise Administration::Rejected.new('Choose 3, 6 or 12 months', :unprocessable_entity) unless %w[3 6 12].include?(months)
    counts = PlatformResource.kept.group(:resource_type).count
    changes = { 'all' => AdminReportingPeriod.change(PlatformResource.kept.where(created_at: (now - 30.days)..now).count, PlatformResource.kept.where(created_at: (now - 60.days)...(now - 30.days)).count) }
    PlatformResource::RESOURCE_TYPES.each do |type|
      scope = PlatformResource.kept.where(resource_type: type)
      changes[type] = AdminReportingPeriod.change(scope.where(created_at: (now - 30.days)..now).count, scope.where(created_at: (now - 60.days)...(now - 30.days)).count)
    end
    trend = (months.to_i - 1).downto(0).map do |n|
      start = month - n.months
      { month: start.to_date.iso8601, views: PlatformResourceAccess.where(created_at: start...[start + 1.month, now].min).count }
    end
    top = PlatformResource.kept.where(archived: false, published: true).where('EXISTS (SELECT 1 FROM platform_resource_accesses a WHERE a.platform_resource_id = platform_resources.id)')
      .order(Arel.sql('(SELECT COUNT(*) FROM platform_resource_accesses a WHERE a.platform_resource_id = platform_resources.id) DESC, platform_resources.id ASC')).limit(4)
    first = month - (months.to_i - 1).months
    elapsed = now - first
    prior = PlatformResourceAccess.where(created_at: (first - elapsed)...first).count
    { stats: { total: counts.values.sum, counts: counts, changes: changes }, distribution: counts.map { |type, n| { type: type, count: n } }, trend: trend,
      trend_change: AdminReportingPeriod.change(trend.sum { |p| p[:views] }, prior), top_resources: self.class.rows(top) }
  end
end
