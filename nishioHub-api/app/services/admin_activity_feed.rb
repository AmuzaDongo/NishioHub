class AdminActivityFeed
  def initialize(period, query = '')
    @period, @query = period, query.to_s.first(150).strip
  end

  def page(page = 1, per_page = 20)
    conn = ApplicationRecord.connection
    sources = [
      User.where(created_at: @period.range).select("users.id::text AS entity_id, users.created_at AS occurred_at, 'user' AS kind, 'New member registered' AS title, users.full_name || ' joined the platform.' AS description"),
      Booking.joins(:service).where(created_at: @period.range).select("bookings.id::text AS entity_id, bookings.created_at AS occurred_at, 'session' AS kind, 'Session created' AS title, services.title AS description"),
      Event.kept.where(created_at: @period.range).select("events.id::text AS entity_id, events.created_at AS occurred_at, 'event' AS kind, 'Event scheduled' AS title, events.title AS description"),
      LearningCertificate.joins(learning_enrollment: :user).where(issued_at: @period.range).select("learning_certificates.id::text AS entity_id, learning_certificates.issued_at AS occurred_at, 'certificate' AS kind, 'Course certificate issued' AS title, users.full_name || ' earned a learning certificate.' AS description"),
      PlatformProgram.where(created_at: @period.range).select("platform_programs.id::text AS entity_id, platform_programs.created_at AS occurred_at, 'program' AS kind, 'Program created' AS title, platform_programs.title AS description"),
      PlatformResource.where(created_at: @period.range).select("platform_resources.id::text AS entity_id, platform_resources.created_at AS occurred_at, 'resource' AS kind, 'Resource added' AS title, platform_resources.title AS description"),
      SystemSettingAudit.where(created_at: @period.range).select("system_setting_audits.id::text AS entity_id, system_setting_audits.created_at AS occurred_at, 'system' AS kind, 'System settings changed' AS title, system_setting_audits.actor_name || ' updated platform configuration.' AS description"),
      AdministrationAudit.where(created_at: @period.range).where.not(action: %w[user.created user.imported program.created resource.created session.created event.created]).select("administration_audits.id::text AS entity_id, administration_audits.created_at AS occurred_at, 'administration' AS kind, REPLACE(administration_audits.action, '.', ' ') AS title, administration_audits.actor_name || ' updated ' || administration_audits.target_type AS description")
    ]
    union = "(#{sources.map(&:to_sql).join(' UNION ALL ')}) AS activities"
    term = conn.quote("%#{ActiveRecord::Base.sanitize_sql_like(@query)}%")
    filter = @query.present? ? "WHERE title ILIKE #{term} OR description ILIKE #{term}" : ''
    total = conn.select_value("SELECT COUNT(*) FROM #{union} #{filter}").to_i
    rows = conn.select_all("SELECT * FROM #{union} #{filter} ORDER BY occurred_at DESC, kind ASC, entity_id DESC LIMIT #{per_page.to_i} OFFSET #{(page.to_i - 1) * per_page.to_i}").to_a
    { items: rows.map { |row| { id: "#{row['kind']}-#{row['entity_id']}", entity_id: row['entity_id'].to_i, kind: row['kind'], title: row['title'], description: row['description'], occurred_at: row['occurred_at'].to_time.iso8601 } },
      meta: { page: page, per_page: per_page, total: total, total_pages: (total / per_page.to_f).ceil } }
  end
end
