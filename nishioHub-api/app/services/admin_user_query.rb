module AdminUserQuery
  def self.role_condition(ids)
    ids = ids.map(&:to_i).uniq
    return 'FALSE' if ids.empty?
    list = ids.join(',')
    "(users.role_id IN (#{list}) OR EXISTS (SELECT 1 FROM user_role_assignments ura WHERE ura.user_id = users.id AND ura.role_id IN (#{list})))"
  end

  def self.filtered(params)
    scope = User.all
    if params[:q].present?
      text = params[:q].to_s.strip.first(150)
      term = "%#{ActiveRecord::Base.sanitize_sql_like(text)}%"
      scope = scope.where('users.full_name ILIKE :q OR users.email ILIKE :q OR users.affiliation ILIKE :q OR CAST(users.id AS TEXT) = :id', q: term, id: text.sub(/\ANH-/i, ''))
    end
    if params[:role_id].present? || params[:role].present?
      role = params[:role_id].present? ? Role.find_by(id: params[:role_id]) : Role.find_by(name: params[:role])
      raise Administration::Rejected.new('Choose a valid role filter', :unprocessable_entity) unless role
      scope = scope.where(role_condition([role.id]))
    end
    if params[:status].present? && params[:status] != 'all'
      raise Administration::Rejected.new('Choose active or inactive status', :unprocessable_entity) unless params[:status].in?(%w[active inactive])
      scope = scope.where(is_active: params[:status] == 'active' ? true : [false, nil])
    end
    scope
  end

  def self.ordered(scope, params)
    columns = { 'name' => 'full_name', 'email' => 'email', 'joined' => 'created_at', 'last_active' => 'last_active_at', 'id' => 'id' }
    sort = columns[params[:sort].presence || 'joined']
    direction = params[:direction].presence || 'desc'
    raise Administration::Rejected.new('Invalid sort order', :unprocessable_entity) unless sort && direction.in?(%w[asc desc])
    scope.order(Arel.sql("users.#{sort} #{direction.upcase} NULLS LAST, users.id ASC"))
  end

  def self.summary(scope = User.all)
    roles = Role.all.to_a
    groups = { mentors: roles.select { |role| role.canonical_name == 'mentor' }.map(&:id),
      mentees: roles.select { |role| role.canonical_name == 'mentee' }.map(&:id),
      staff: roles.select { |role| role.canonical_name.in?(%w[admin superadmin moderator]) }.map(&:id),
      supers: roles.select { |role| role.canonical_name == 'superadmin' }.map(&:id) }
    counts = groups.transform_values { |ids| scope.where(role_condition(ids)).count }
    expression = "CASE WHEN #{role_condition(groups[:supers])} THEN 'supers' WHEN #{role_condition(groups[:staff])} THEN 'staff' WHEN #{role_condition(groups[:mentors])} THEN 'mentors' WHEN #{role_condition(groups[:mentees])} THEN 'mentees' ELSE 'other' END"
    distribution = scope.group(Arel.sql(expression)).count
    { stats: { total: scope.count, mentors: counts[:mentors], mentees: counts[:mentees], staff: counts[:staff] },
      distribution: %w[mentees mentors staff supers other].map { |key| { key: key, count: distribution.fetch(key, 0) } } }
  end

  def self.csv_cell(value)
    text = value.to_s
    text.match?(/\A[\s]*[=+\-@\t\r]/) ? "'#{text}" : text
  end
end
