class AdminGoalQuery
  TYPES={'mentee'=>MenteeGoal,'mentor'=>MentorGoal,'program'=>ProgramGoal}.freeze
  FIELDS=%w[title description progress completed target_date icon category tracking_status platform_program_id lock_version priority completed_at created_at updated_at].freeze
  UNION=TYPES.map{|kind,model|"SELECT '#{kind}' AS kind, '#{kind}-' || id::text AS goal_key, id AS source_id, #{kind=='program' ? 'NULL::integer' : 'user_id'} AS user_id, #{FIELDS.join(', ')} FROM #{model.table_name} WHERE archived_at IS NULL"}.join(' UNION ALL ').freeze
  def initialize(params={})
    @params=params;@now=Time.current;@today=@now.in_time_zone(SystemSetting.config['timezone']).to_date
  end
  def status_sql
    "CASE WHEN goal_rows.progress = 100 THEN 'completed' WHEN goal_rows.target_date < #{ActiveRecord::Base.connection.quote(@today)} THEN 'at_risk' ELSE goal_rows.tracking_status END"
  end
  def base
    MenteeGoal.unscoped.from("(#{UNION}) goal_rows").joins('LEFT JOIN users goal_users ON goal_users.id = goal_rows.user_id LEFT JOIN platform_programs goal_programs ON goal_programs.id = goal_rows.platform_program_id').readonly
  end
  def filtered
    scope=base
    tab=@params[:tab].presence||'overview'
    raise Administration::Rejected.new('Choose a valid goal section',:unprocessable_entity) unless %w[overview all programs mentees mentors reports].include?(tab)
    kind={'programs'=>'program','mentees'=>'mentee','mentors'=>'mentor'}[tab]
    scope=scope.where('goal_rows.kind = ?',kind) if kind
    if @params[:type].present?&&@params[:type]!='all'
      raise Administration::Rejected.new('Invalid goal type',:unprocessable_entity) unless TYPES.key?(@params[:type])
      scope=scope.where('goal_rows.kind = ?',@params[:type])
    end
    if @params[:q].present?
      term="%#{ActiveRecord::Base.sanitize_sql_like(@params[:q].to_s.strip.first(150))}%"
      scope=scope.where('goal_rows.title ILIKE :q OR goal_rows.description ILIKE :q OR goal_users.full_name ILIKE :q OR goal_programs.title ILIKE :q',q:term)
    end
    if @params[:status].present?&&@params[:status]!='all'
      raise Administration::Rejected.new('Invalid goal status',:unprocessable_entity) unless %w[completed on_track in_progress at_risk].include?(@params[:status])
      scope=scope.where("#{status_sql} = ?",@params[:status])
    end
    if @params[:category].present?&&@params[:category]!='all'
      raise Administration::Rejected.new('Invalid goal category',:unprocessable_entity) unless ManagedGoal::CATEGORIES.include?(@params[:category])
      scope=scope.where('goal_rows.category = ?',@params[:category])
    end
    scope=scope.where('goal_rows.platform_program_id = ?',AdminMenteeQuery.positive_id!(@params[:program_id])) if @params[:program_id].present?
    scope=scope.where('goal_rows.user_id = ?',AdminMenteeQuery.positive_id!(@params[:assignee_id])) if @params[:assignee_id].present?
    scope
  end
  def ordered(scope=filtered)
    field={'created'=>'goal_rows.created_at','title'=>'goal_rows.title','target'=>'goal_rows.target_date','progress'=>'goal_rows.progress','status'=>status_sql}[@params[:sort].presence||'created']
    direction=@params[:direction].presence||'desc'
    raise Administration::Rejected.new('Invalid goal sorting',:unprocessable_entity) unless field&&%w[asc desc].include?(direction)
    scope.order(Arel.sql("#{field} #{direction.upcase} NULLS LAST, goal_rows.kind ASC, goal_rows.source_id ASC"))
  end
  def rows(scope)
    records=scope.select('goal_rows.*',"#{status_sql} AS display_status").to_a
    people=User.where(id:records.map(&:user_id).compact).includes(:profile,:mentor_profile,avatar_attachment: :blob).index_by(&:id)
    programs=PlatformProgram.where(id:records.map(&:platform_program_id).compact).index_by(&:id)
    records.map do |r|
      u=people[r.user_id];p=programs[r.platform_program_id]
      {id:r[:goal_key],kind:r[:kind],title:r.title,description:r.description,progress:r.progress,completed:r.completed,target_date:r.target_date&.iso8601,icon:r.icon,category:r.category,tracking_status:r.tracking_status,status:r[:display_status],lock_version:r.lock_version,created_at:r.created_at.iso8601,priority:r.priority,completed_at:r.completed_at&.iso8601,
       assignee:u&&{id:u.id,name:u.full_name,avatar:u.avatar_url,active:u.is_active?},program:p&&{id:p.id,title:p.title,status:p.status}}
    end
  end
  def people(scope=filtered)
    total=scope.distinct.count('goal_rows.user_id')
    records=scope.where('goal_rows.user_id IS NOT NULL').select('goal_rows.user_id','COUNT(*) AS goal_count','AVG(goal_rows.progress) AS average_progress',"COUNT(*) FILTER (WHERE goal_rows.progress = 100) AS completed_count","COUNT(*) FILTER (WHERE #{status_sql} = 'at_risk') AS risk_count").group('goal_rows.user_id')
      .order(Arel.sql('AVG(goal_rows.progress) DESC, goal_rows.user_id ASC'))
    size=per_page;page=page_number
    rows=records.limit(size).offset((page-1)*size).to_a
    people=User.where(id:rows.map(&:user_id)).includes(:profile,:mentor_profile,avatar_attachment: :blob).index_by(&:id)
    {items:rows.map{|r|u=people.fetch(r.user_id);{id:u.id,name:u.full_name,avatar:u.avatar_url,active:u.is_active?,goals:r[:goal_count].to_i,progress:r[:average_progress].to_f.round(1),completed:r[:completed_count].to_i,at_risk:r[:risk_count].to_i}},meta:{page:page,per_page:size,total:total,total_pages:(total/size.to_f).ceil}}
  end
  def per_page
    n=@params.fetch(:per_page,5).to_i
    raise Administration::Rejected.new('Choose 5, 10, 25 or 50 goals per page',:unprocessable_entity) unless [5,10,25,50].include?(n)
    n
  end
  def page_number = [[@params.fetch(:page,1).to_i,1].max,100000].min
  def history_sql(scope,stamp)
    source=scope.reorder(nil).select('goal_rows.kind','goal_rows.source_id','goal_rows.created_at').to_sql
    "FROM (#{source}) goals JOIN LATERAL (SELECT pe.progress FROM goal_progress_events pe WHERE ((goals.kind='mentee' AND pe.mentee_goal_id=goals.source_id) OR (goals.kind='mentor' AND pe.mentor_goal_id=goals.source_id) OR (goals.kind='program' AND pe.program_goal_id=goals.source_id)) AND pe.created_at <= #{stamp} ORDER BY pe.created_at DESC, pe.id DESC LIMIT 1) recorded ON TRUE WHERE goals.created_at <= #{stamp}"
  end
  def snapshot(scope,at)
    stamp=ActiveRecord::Base.connection.quote(at)
    sql="SELECT AVG(recorded.progress) AS progress, COUNT(*) AS recorded_goals #{history_sql(scope,stamp)}"
    row=ActiveRecord::Base.connection.select_one(sql)
    {progress:row['progress']&.to_f&.round(1),recorded_goals:row['recorded_goals'].to_i}
  end
  def report(scope=filtered)
    counts=scope.group(Arel.sql(status_sql)).count
    categories=scope.group('goal_rows.category').count;total=counts.values.sum
    recent=scope.where('goal_rows.created_at >= ? AND goal_rows.created_at <= ?',@now-30.days,@now).count
    prior=scope.where('goal_rows.created_at >= ? AND goal_rows.created_at < ?',@now-60.days,@now-30.days).count
    changes={total:AdminReportingPeriod.change(recent,prior),on_track:nil,in_progress:nil,at_risk:nil,completed:nil}
    zone=SystemSetting.config['timezone'];start=@now.in_time_zone(zone).beginning_of_month
    months=@params[:months].presence||'6'
    raise Administration::Rejected.new('Choose 3, 6 or 12 months',:unprocessable_entity) unless %w[3 6 12].include?(months.to_s)
    trend=(months.to_i-1).downto(0).map do |n|
      month=start-n.months;at=[month.end_of_month,@now].min
      snapshot(scope,at).merge(month:month.to_date.iso8601)
    end
    before=snapshot(scope,(start-(months.to_i-1).months)-0.000001)
    current=scope.average('goal_rows.progress')&.to_f&.round(1)
    {stats:{total:total,on_track:counts.fetch('on_track',0),in_progress:counts.fetch('in_progress',0),at_risk:counts.fetch('at_risk',0),completed:counts.fetch('completed',0),overall_progress:current,changes:changes},
     distribution:%w[completed on_track in_progress at_risk].map{|v|{status:v,count:counts.fetch(v,0)}},categories:ManagedGoal::CATEGORIES.map{|v|{category:v,count:categories.fetch(v,0)}},trend:trend,
     trend_change:trend.last[:progress]&&before[:progress] ? AdminReportingPeriod.change(trend.last[:progress],before[:progress]) : nil,timezone:zone}
  end
end
