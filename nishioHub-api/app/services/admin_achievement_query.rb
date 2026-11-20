# A read-only union keeps automatic learner achievements connected to their source
# records. Custom awards retain snapshots so catalog edits never rewrite history.
class AdminAchievementQuery
  def initialize(params={})
    @params=params
  end
  def quote(value) = ApplicationRecord.connection.quote(value)
  def automatic_sql
    courses=LearningCatalog.courses.map{|c|"(#{quote(c['id'])},#{quote(c['title'])},#{quote(c['lessons'].map{|l|l['id']}.to_json)}::jsonb)"}.join(',')
    badge_sources={
      'active-learner'=>"SELECT user_id,MIN(earned_at) earned_at FROM (SELECT user_id,earned_at,ROW_NUMBER() OVER(PARTITION BY user_id,date_trunc('month',earned_at AT TIME ZONE 'UTC' AT TIME ZONE #{quote(SystemSetting.config['timezone'])}) ORDER BY earned_at,id) n FROM completions) c WHERE n=3 GROUP BY user_id",
      'goal-setter'=>'SELECT user_id,MIN(updated_at) earned_at FROM mentee_goals WHERE completed GROUP BY user_id',
      'course-completer'=>'SELECT user_id,MIN(earned_at) earned_at FROM completions GROUP BY user_id',
      'event-participant'=>"SELECT user_id,MIN(attended_at) earned_at FROM event_registrations WHERE status='registered' AND attended_at IS NOT NULL GROUP BY user_id",
      'rising-innovator'=>"SELECT user_id,earned_at FROM completions WHERE course_key='innovation'",
      'first-session'=>'SELECT mentee_id user_id,updated_at earned_at FROM ranked_sessions WHERE n=1',
      'five-sessions'=>'SELECT mentee_id user_id,updated_at earned_at FROM ranked_sessions WHERE n=5',
      'ten-sessions'=>'SELECT mentee_id user_id,updated_at earned_at FROM ranked_sessions WHERE n=10'
    }
    badge_sql=AchievementCatalog::BADGES.map do |key,title,description,icon,color|
      "SELECT 'badge-#{key}-'||b.user_id::text award_key,'automatic' source,'skill_badge' kind,#{quote(title)} title,#{quote(description)} description,#{quote(icon)} icon,#{quote(color)} color,b.user_id,NULL::bigint platform_program_id,b.earned_at awarded_at,'builtin-#{key}' definition_key,NULL::text certificate_id,0 lock_version,NULL::timestamp revoked_at,NULL::text revocation_reason,NULL::text issuer_name FROM (#{badge_sources.fetch(key)}) b"
    end.join(' UNION ALL ')
    <<~SQL
      WITH catalog(course_key,title,lessons) AS (VALUES #{courses}),
      completions AS (
        SELECT e.id,e.user_id,e.course_key,c.title,COALESCE((SELECT MAX(l.created_at) FROM learning_lesson_completions l WHERE l.learning_enrollment_id=e.id),e.updated_at) earned_at
        FROM learning_enrollments e JOIN catalog c ON c.course_key=e.course_key WHERE e.completed_lesson_ids @> c.lessons
      ), ranked_sessions AS (SELECT *,ROW_NUMBER() OVER(PARTITION BY mentee_id ORDER BY updated_at,id) n FROM bookings WHERE status='completed')
      SELECT 'course-'||id::text award_key,'automatic' source,'course_completion' kind,'Completed: '||title title,'Finished every course lesson.' description,'trophy' icon,'purple' color,user_id,NULL::bigint platform_program_id,earned_at awarded_at,NULL::text definition_key,NULL::text certificate_id,0 lock_version,NULL::timestamp revoked_at,NULL::text revocation_reason,NULL::text issuer_name FROM completions
      UNION ALL SELECT 'certificate-'||lc.identifier,'automatic','certificate',c.title,'Course completion certificate','certificate','blue',c.user_id,NULL::bigint,lc.issued_at,NULL::text,lc.identifier,0,NULL::timestamp,NULL::text,NULL::text FROM learning_certificates lc JOIN completions c ON c.id=lc.learning_enrollment_id
      UNION ALL SELECT 'session-'||id::text,'automatic','other',COALESCE(session_title,'Attended Mentorship Session'),'Completed mentorship session','users','purple',mentee_id,platform_program_id,updated_at,NULL::text,NULL::text,0,NULL::timestamp,NULL::text,NULL::text FROM bookings WHERE status='completed'
      UNION ALL SELECT 'program-'||pm.id::text,'automatic','program_completion','Completed: '||p.title,'Program progress reached 100%.','graduation','blue',pm.user_id,p.id,pm.completed_at,NULL::text,NULL::text,0,NULL::timestamp,NULL::text,NULL::text FROM program_memberships pm JOIN platform_programs p ON p.id=pm.platform_program_id WHERE pm.progress=100 AND pm.completed_at IS NOT NULL
      UNION ALL #{badge_sql}
    SQL
  end
  def base
    manual="SELECT 'award-'||identifier award_key,'manual' source,kind,title,description,icon,color,user_id,platform_program_id,awarded_at,'definition-'||achievement_definition_id::text definition_key,CASE WHEN kind='certificate' THEN 'award-'||identifier ELSE NULL END certificate_id,lock_version,revoked_at,revocation_reason,issuer_name FROM achievement_awards"
    AchievementAward.unscoped.from("((#{automatic_sql}) UNION ALL #{manual}) achievement_rows")
      .joins('JOIN users achievement_users ON achievement_users.id=achievement_rows.user_id LEFT JOIN platform_programs achievement_programs ON achievement_programs.id=achievement_rows.platform_program_id').readonly
  end
  def filtered
    scope=base
    status=@params[:status].presence||'active'
    raise Administration::Rejected.new('Choose active, revoked or all awards',:unprocessable_entity) unless %w[active revoked all].include?(status)
    scope=scope.where("achievement_rows.revoked_at IS #{status=='active' ? 'NULL' : 'NOT NULL'}") unless status=='all'
    kind=@params[:kind]
    if kind.present?&&kind!='all'
      raise Administration::Rejected.new('Invalid achievement type',:unprocessable_entity) unless AchievementDefinition::KINDS.include?(kind)
      scope=scope.where('achievement_rows.kind=?',kind)
    end
    if @params[:q].present?
      term="%#{ActiveRecord::Base.sanitize_sql_like(@params[:q].to_s.strip.first(150))}%"
      scope=scope.where('achievement_rows.title ILIKE :q OR achievement_rows.description ILIKE :q OR achievement_users.full_name ILIKE :q OR achievement_users.email ILIKE :q OR achievement_programs.title ILIKE :q',q:term)
    end
    scope=scope.where('achievement_rows.user_id=?',AdminMenteeQuery.positive_id!(@params[:user_id])) if @params[:user_id].present?
    if @params[:program_id].present?
      scope=@params[:program_id]=='none' ? scope.where('achievement_rows.platform_program_id IS NULL') : scope.where('achievement_rows.platform_program_id=?',AdminMenteeQuery.positive_id!(@params[:program_id]))
    end
    if @params[:definition_key].present?
      raise Administration::Rejected.new('Invalid badge identifier',:unprocessable_entity) unless @params[:definition_key].to_s.match?(/\A(?:builtin-[a-z-]+|definition-[1-9]\d*)\z/)
      scope=scope.where('achievement_rows.definition_key=?',@params[:definition_key])
    end
    scope
  end
  def ordered(scope=filtered)
    sort={'awarded'=>'achievement_rows.awarded_at','title'=>'achievement_rows.title','learner'=>'achievement_users.full_name'}[@params[:sort].presence||'awarded']
    direction=@params[:direction].presence||'desc'
    raise Administration::Rejected.new('Invalid achievement sorting',:unprocessable_entity) unless sort&&%w[asc desc].include?(direction)
    scope.order(Arel.sql("#{sort} #{direction.upcase},achievement_rows.award_key ASC"))
  end
  def rows(scope)
    records=scope.select('achievement_rows.*').to_a
    people=User.where(id:records.map(&:user_id)).includes(:profile,:mentor_profile,avatar_attachment: :blob).index_by(&:id)
    programs=PlatformProgram.where(id:records.map(&:platform_program_id).compact).index_by(&:id)
    records.map do |r|
      u=people[r.user_id];p=programs[r.platform_program_id]
      {id:r[:award_key],source:r[:source],kind:r.kind,title:r.title,description:r.description,icon:r.icon,color:r.color,awarded_at:r.awarded_at.iso8601,definition_key:r[:definition_key],certificate_id:r[:certificate_id],lock_version:r.lock_version,revoked_at:r.revoked_at&.iso8601,revocation_reason:r.revocation_reason,issuer:r.issuer_name,
       learner:{id:u.id,name:u.full_name,email:u.email,avatar:u.avatar_url,active:u.is_active?},program:p&&{id:p.id,title:p.title,status:p.status}}
    end
  end
  def page = bounded(:page,1,1..100000)
  def size = bounded(:per_page,5,[5,10,20,50])
  def bounded(key,fallback,range)
    raw=@params.fetch(key,fallback).to_s
    raise Administration::Rejected.new("Invalid #{key}",:unprocessable_entity) unless raw.match?(/\A\d+\z/)&&range.include?(raw.to_i)
    raw.to_i
  end
  def meta(total) = {page:page,per_page:size,total:total,total_pages:(total/size.to_f).ceil}
  def report(scope=filtered)
    zone=ActiveSupport::TimeZone[SystemSetting.config['timezone']];now=Time.current.in_time_zone(zone);month=now.beginning_of_month
    n=bounded(:months,6,[3,6,12]);active=scope.where('achievement_rows.revoked_at IS NULL')
    before=now-30.days;window=month-(n-1).months;previous=month-(2*n-1).months
    # Aggregate the union once for counters and comparisons instead of querying it
    # separately for each card. Revoked records never inflate active metrics.
    total,learners,certificates,old_total,old_learners,old_certificates,current_window,previous_window = active.pick(*[
      'COUNT(*)','COUNT(DISTINCT achievement_rows.user_id)',
      "COUNT(*) FILTER(WHERE achievement_rows.kind='certificate')",
      "COUNT(*) FILTER(WHERE achievement_rows.awarded_at < #{quote(before)})",
      "COUNT(DISTINCT achievement_rows.user_id) FILTER(WHERE achievement_rows.awarded_at < #{quote(before)})",
      "COUNT(*) FILTER(WHERE achievement_rows.kind='certificate' AND achievement_rows.awarded_at < #{quote(before)})",
      "COUNT(*) FILTER(WHERE achievement_rows.awarded_at >= #{quote(window)})",
      "COUNT(*) FILTER(WHERE achievement_rows.awarded_at >= #{quote(previous)} AND achievement_rows.awarded_at < #{quote(window)})"
    ].map{|expression|Arel.sql(expression)})
    kinds=active.group('achievement_rows.kind').count
    distribution=AchievementDefinition::KINDS.map{|kind|{kind:kind,count:kinds[kind]||0}}
    badge_counts=active.where('achievement_rows.kind=?','skill_badge').group('achievement_rows.definition_key').count
    badges=AchievementCatalog::BADGES.length+AchievementDefinition.active.where(kind:'skill_badge').count
    bucket="DATE_TRUNC('month',achievement_rows.awarded_at AT TIME ZONE 'UTC' AT TIME ZONE #{quote(zone.tzinfo.name)})::date"
    monthly=active.where('achievement_rows.awarded_at >= ?',window).group(Arel.sql(bucket)).count.transform_keys(&:to_s)
    trend=(n-1).downto(0).map{|i|start=month-i.months;{month:start.to_date.iso8601,count:monthly[start.to_date.iso8601]||0}}
    change=->(current,old){old.zero? ? nil : ((current-old)*100.0/old).round(1)}
    top=active.where('achievement_rows.platform_program_id IS NOT NULL').group('achievement_rows.platform_program_id').order(Arel.sql('COUNT(*) DESC,achievement_rows.platform_program_id ASC')).limit(5).count
    names=PlatformProgram.where(id:top.keys).pluck(:id,:title).to_h
    ranked_badges=badge_counts.sort_by{|key,count|[-count,key.to_s]}.first(5)
    definitions=AchievementDefinition.where(id:ranked_badges.filter_map{|key,_|key.delete_prefix('definition-') if key&.start_with?('definition-')}).index_by{|d|"definition-#{d.id}"}
    top_badges=ranked_badges.map do |key,count|
      catalog=AchievementCatalog::BADGES.find{|b|"builtin-#{b[0]}"==key};definition=definitions[key]
      {key:key,title:catalog&.[](1)||definition&.title||'Archived badge',icon:catalog&.[](3)||definition&.icon||'trophy',color:catalog&.[](4)||definition&.color||'purple',count:count}
    end
    {stats:{total:total,learners:learners,badges:badges,certificates:certificates,changes:{total:change.call(total,old_total),learners:change.call(learners,old_learners),badges:nil,certificates:change.call(certificates,old_certificates)}},distribution:distribution,trend:trend,trend_change:previous_window.zero? ? nil : ((current_window-previous_window)*100.0/previous_window).round(1),top_badges:top_badges,top_programs:top.map{|id,count|{id:id,title:names[id],count:count}},timezone:zone.tzinfo.name}
  end
  def people(scope=filtered)
    total=scope.distinct.count('achievement_rows.user_id')
    aggregate=scope.group('achievement_rows.user_id').select('achievement_rows.user_id','COUNT(*) AS award_count','MAX(achievement_rows.awarded_at) AS latest_award').order(Arel.sql('COUNT(*) DESC,achievement_rows.user_id ASC')).limit(size).offset((page-1)*size).to_a
    users=User.where(id:aggregate.map(&:user_id)).includes(:profile,:mentor_profile,avatar_attachment: :blob).index_by(&:id)
    {items:aggregate.map{|r|u=users[r.user_id];{id:u.id,name:u.full_name,email:u.email,avatar:u.avatar_url,count:r[:award_count].to_i,latest_at:r[:latest_award].iso8601}},meta:meta(total)}
  end
end
