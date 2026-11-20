require 'csv'
class AnalyticsReport
  DATASETS={
    'users'=>{'id'=>'ID','name'=>'User','email'=>'Email','roles'=>'Current Roles','status'=>'Status','joined'=>'Joined On','sessions'=>'Completed Sessions','accesses'=>'Resource Accesses'},
    'programs'=>{'id'=>'ID','title'=>'Program','enrolled'=>'Enrolled Users','completed'=>'Completed','completion_rate'=>'Completion Rate (%)','achievements'=>'Achievements','progress'=>'Average Progress (%)','status'=>'Current Status'},
    'learning'=>{'id'=>'ID','title'=>'Resource','type'=>'Type','program'=>'Program','accesses'=>'Period Accesses','learners'=>'Unique Learners','completions'=>'Recorded Completions','status'=>'Current Status'},
    'events'=>{'id'=>'ID','title'=>'Event','type'=>'Type','starts_at'=>'Starts At','registrations'=>'Current Registrations','attended'=>'Confirmed Attendance','attendance_rate'=>'Attendance Rate (%)','status'=>'Current Status'},
    'achievements'=>{'id'=>'ID','title'=>'Achievement','learner'=>'Learner','type'=>'Type','program'=>'Program','awarded_at'=>'Awarded On','source'=>'Source'}
  }.freeze
  FILTER_KEYS=%w[period from to q program_id].freeze
  attr_reader :actor,:filters,:period
  def initialize(actor,filters={})
    @actor=actor;@filters=filters.to_h.stringify_keys.slice(*FILTER_KEYS);@period=AnalyticsPeriod.build(@filters)
    @term="%#{ActiveRecord::Base.sanitize_sql_like(@filters['q'].to_s.strip.first(150))}%"
    @program_id=AdminMenteeQuery.positive_id!(@filters['program_id']) if @filters['program_id'].present?
  end
  def search? = filters['q'].present?
  def users
    scope=User.where('users.created_at < ?',period.finishes_at)
    scope=scope.where('users.full_name ILIKE :q OR users.email ILIKE :q',q:@term) if search?
    scope=scope.where(id:ProgramMembership.where(platform_program_id:@program_id).select(:user_id)).or(scope.where(id:ProgramMentorAssignment.where(platform_program_id:@program_id).select(:user_id))) if @program_id
    scope
  end
  def programs
    scope=PlatformProgram.where('created_at < ?',period.finishes_at)
    scope=scope.where('title ILIKE :q OR description ILIKE :q',q:@term) if search?
    scope=scope.where(id:@program_id) if @program_id
    scope
  end
  def resources
    scope=PlatformResource.kept.where('created_at < ?',period.finishes_at)
    scope=scope.where('title ILIKE :q OR description ILIKE :q',q:@term) if search?
    scope=scope.where(platform_program_id:@program_id).or(scope.where(id:ResourceProgramShare.where(platform_program_id:@program_id).select(:platform_resource_id))) if @program_id
    scope
  end
  def events(range=period.range)
    scope=Event.kept.where(starts_at:range)
    scope=scope.where('title ILIKE :q OR location ILIKE :q',q:@term) if search?
    scope=scope.where(platform_program_id:@program_id) if @program_id
    scope
  end
  def awards(range=period.range)
    @award_query ||= AdminAchievementQuery.new(q:filters['q'],program_id:@program_id,status:'active')
    @award_query.filtered.where('achievement_rows.awarded_at >= ? AND achievement_rows.awarded_at < ?',range.begin,range.end)
  end
  def enrollments(range=period.range)
    ProgramMembership.where(platform_program_id:programs.select(:id),created_at:range)
  end
  def rate(completed,total) = total.zero? ? nil : (completed*100.0/total).round(1)
  def change(now,before) = AdminReportingPeriod.change(now,before)
  def overview
    u=users;p=programs;r=resources;a=awards
    counts={users:u.count,programs:p.count,resources:r.count,events:events.count,achievements:a.count}
    previous={users:u.where('users.created_at < ?',period.begins_at).count,programs:p.where('created_at < ?',period.begins_at).count,resources:r.where('created_at < ?',period.begins_at).count,events:events(period.previous_range).count,achievements:awards(period.previous_range).count}
    members=enrollments;total=members.count;done=members.where(progress:100).count;progress=members.where(progress:1..99).count
    prior_members=enrollments(period.previous_range);prior_rate=rate(prior_members.where(progress:100).count,prior_members.count)
    completion=rate(done,total)
    accesses=PlatformResourceAccess.where(platform_resource_id:r.select(:id),created_at:period.range).count
    past_accesses=PlatformResourceAccess.where(platform_resource_id:r.select(:id),created_at:period.previous_range).count
    insights=[{title:'User Growth',text:"#{counts[:users]} retained users at the selected end; #{previous[:users]} before the period.",change:change(counts[:users],previous[:users])},
      {title:'Program Completion',text:completion ? "#{done} of #{total} period enrollments are currently complete (#{completion}%)." : 'No enrollments joined in the selected period.',change:nil},
      {title:'Achievements',text:"#{counts[:achievements]} active recognition records were issued in this period; #{previous[:achievements]} in the preceding period.",change:change(counts[:achievements],previous[:achievements])},
      {title:'Learning Engagement',text:"#{accesses} recorded resource accesses; #{past_accesses} in the preceding period.",change:change(accesses,past_accesses)}]
    {period:period.json,generated_at:Time.current.iso8601,metrics:counts.map{|key,value|{key:key,value:value,previous:previous[key],change:change(value,previous[key])}},
     user_growth:series(u,:created_at,cumulative:true),roles:AdminUserQuery.summary(u)[:distribution],achievement_trend:award_series,
     completion:{enrolled:total,completed:done,in_progress:progress,not_started:total-done-progress,rate:completion,previous_rate:prior_rate},
     goal_categories:goal_categories,insights:insights,top_programs:program_rows(programs).sort_by{|row|[-row[:enrolled],row[:title]]}.first(5),capabilities:{manage:actor.management_permission?('dashboard.manage'),users:actor.management_permission?('users.read'),user_export:actor.management_permission?('users.export')}}
  end
  def months
    first=period.starts_on.beginning_of_month;last=period.ends_on.beginning_of_month
    result=[];while first<=last;result<<first;first=first.next_month;end;result
  end
  def bucket_sql(column) = "DATE_TRUNC('month',#{column} AT TIME ZONE 'UTC' AT TIME ZONE #{ApplicationRecord.connection.quote(period.zone.tzinfo.name)})::date"
  def series(scope,column,cumulative:false)
    counts=scope.where(column=>period.range).group(Arel.sql(bucket_sql(column))).count
    carried=cumulative ? scope.where("#{column} < ?",period.begins_at).count : 0
    months.map{|date|value=counts.fetch(date,0);carried+=value;{month:date.iso8601,value:cumulative ? carried : value}}
  end
  def award_series
    grouped=awards.group(Arel.sql(bucket_sql('achievement_rows.awarded_at'))).count
    months.map{|date|{month:date.iso8601,value:grouped.fetch(date,0)}}
  end
  def goal_categories
    at=[period.finishes_at-0.000001,Time.current].min
    quoted=ApplicationRecord.connection.quote(at)
    union=AdminGoalQuery::TYPES.map{|kind,model|"SELECT '#{kind}' kind,id source_id,title,description,category,platform_program_id,created_at FROM #{model.table_name} WHERE created_at<=#{quoted} AND (archived_at IS NULL OR archived_at>#{quoted})"}.join(' UNION ALL ')
    scope=MenteeGoal.unscoped.from("(#{union}) goal_rows").readonly
    scope=scope.where('goal_rows.platform_program_id=?',@program_id) if @program_id
    scope=scope.where('goal_rows.title ILIKE :q OR goal_rows.description ILIKE :q',q:@term) if search?
    query=AdminGoalQuery.new
    ManagedGoal::CATEGORIES.map{|category|{category:category,**query.snapshot(scope.where('goal_rows.category=?',category),at)}}
  end
  def dataset(kind)
    authorize_dataset!(kind)
    case kind
    when 'users' then users
    when 'programs' then programs
    when 'learning' then resources
    when 'events' then events
    when 'achievements' then awards
    end
  end
  def authorize_dataset!(kind)
    raise Administration::Rejected.new('Choose a valid report dataset',:unprocessable_entity) unless DATASETS.key?(kind)
    Administration.authorize!(actor,'users.read') if kind=='users'
  end
  def rows(kind,scope)
    case kind
    when 'users'
      people=scope.includes(:role,:additional_roles).to_a;ids=people.map(&:id)
      sessions=Booking.where(mentee_id:ids,status:'completed',scheduled_at:period.range).group(:mentee_id).count
      accesses=PlatformResourceAccess.where(user_id:ids,created_at:period.range).group(:user_id).count
      people.map{|u|{id:u.id,name:u.full_name,email:u.email,roles:u.effective_roles.map(&:name).join(', '),status:u.is_active? ? 'Active' : 'Inactive',joined:u.created_at.iso8601,sessions:sessions[u.id]||0,accesses:accesses[u.id]||0}}
    when 'programs' then program_rows(scope)
    when 'learning'
      list=scope.includes(:platform_program).to_a;ids=list.map(&:id)
      accesses=PlatformResourceAccess.where(platform_resource_id:ids,created_at:period.range)
      counts=accesses.group(:platform_resource_id).count;people=accesses.group(:platform_resource_id).distinct.count(:user_id)
      completed=ResourceProgress.where(platform_resource_id:ids,percent:100,completed_at:period.range).group(:platform_resource_id).count
      list.map{|r|{id:r.id,title:r.title,type:r.resource_type,program:r.platform_program&.title||'Independent',accesses:counts[r.id]||0,learners:people[r.id]||0,completions:completed[r.id]||0,status:r.archived? ? 'Archived' : r.published? ? 'Published' : 'Draft'}}
    when 'events'
      list=scope.to_a;ids=list.map(&:id);registrations=EventRegistration.where(event_id:ids,status:'registered')
      counts=registrations.group(:event_id).count;attended=registrations.where.not(attended_at:nil).group(:event_id).count
      list.map{|e|n=counts[e.id]||0;done=attended[e.id]||0;{id:e.id,title:e.title,type:e.event_type,starts_at:e.starts_at.iso8601,registrations:n,attended:done,attendance_rate:rate(done,n),status:e.status}}
    when 'achievements'
      @award_query.rows(scope).map{|a|{id:a[:id],title:a[:title],learner:a.dig(:learner,:name),type:a[:kind],program:a.dig(:program,:title)||'Independent',awarded_at:a[:awarded_at],source:a[:source]}}
    end
  end
  def program_rows(scope)
    list=scope.to_a;ids=list.map(&:id)
    enrollments=ProgramMembership.where(platform_program_id:ids,created_at:period.range)
    enrolled=enrollments.group(:platform_program_id).count;done=enrollments.where(progress:100).group(:platform_program_id).count;averages=enrollments.group(:platform_program_id).average(:progress)
    awards=awards().where('achievement_rows.platform_program_id IN (?)',ids).group('achievement_rows.platform_program_id').count
    list.map{|p|n=enrolled[p.id]||0;c=done[p.id]||0;{id:p.id,title:p.title,enrolled:n,completed:c,completion_rate:rate(c,n),achievements:awards[p.id]||0,progress:averages[p.id]&.to_f&.round(1),status:p.status}}
  end
  def ordered(kind,scope)
    column={'users'=>'users.id','programs'=>'platform_programs.id','learning'=>'platform_resources.id','events'=>'events.starts_at','achievements'=>'achievement_rows.awarded_at'}.fetch(kind)
    scope.order(Arel.sql("#{column} DESC"))
  end
  def table(kind,page:1,size:10,columns:nil)
    chosen=columns_for(kind,columns);scope=dataset(kind);total=scope.count
    {columns:chosen.map{|key|{key:key,title:DATASETS[kind][key]}},items:rows(kind,ordered(kind,scope).limit(size).offset((page-1)*size)).map{|row|row.slice(*chosen.map(&:to_sym))},meta:{page:page,per_page:size,total:total,total_pages:(total/size.to_f).ceil},period:period.json}
  end
  def columns_for(kind,columns)
    authorize_dataset!(kind)
    return DATASETS[kind].keys if columns.nil?
    unless columns.is_a?(Array)&&columns.size.between?(1,12)&&columns.uniq==columns&&columns.all?{|c|DATASETS[kind].key?(c)}
      raise Administration::Rejected.new('Choose distinct available report columns',:unprocessable_entity)
    end
    columns
  end
  def csv(kind='overview',columns:nil)
    if kind=='overview'
      data=overview
      return CSV.generate do |out|
        out<<%w[metric value previous change_percent]
        data[:metrics].each{|m|out<<[m[:key],m[:value],m[:previous],m[:change]]}
        out<<['Period',period.starts_on.iso8601,period.ends_on.iso8601,period.zone.tzinfo.name]
        out<<['Current completion rate for period enrollments',data[:completion][:rate]]
        data[:goal_categories].each{|g|out<<["goal_#{g[:category]}",g[:progress],g[:recorded_goals]]}
      end
    end
    Administration.authorize!(actor,'users.export') if kind=='users'
    chosen=columns_for(kind,columns);scope=dataset(kind)
    raise Administration::Rejected.new('Filter to at most 10,000 rows before exporting',:unprocessable_entity) if scope.count>10000
    CSV.generate do |out|
      out<<chosen.map{|key|DATASETS[kind][key]}
      (scope.count/100.0).ceil.times do |n|
        rows(kind,ordered(kind,scope).limit(100).offset(n*100)).each{|row|out<<chosen.map{|key|AdminUserQuery.csv_cell(row[key.to_sym])}}
      end
    end
  end
end
