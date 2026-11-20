class PublicEventQuery
  TYPES={
    'webinar'=>{label:'Webinar',values:%w[webinar]},
    'workshop'=>{label:'Workshop',values:%w[workshop training]},
    'mentorship'=>{label:'Mentorship Session',values:%w[mentorship]},
    'talk'=>{label:'Career Talk',values:%w[talk conference]},
    'community'=>{label:'Community Event',values:%w[networking launch challenge other]}
  }.freeze
  AUDIENCES={'primary'=>'Primary Learners','secondary'=>'Secondary Students','university'=>'University & College','early_career'=>'Early Career / Job Seekers','professionals'=>'Professionals & Leaders'}.freeze
  attr_reader :tab,:page,:from,:to
  def initialize(params={})
    @params=params;@now=Time.current;@zone=ActiveSupport::TimeZone[SystemSetting.config['timezone']]
    @tab=params[:tab].presence||'upcoming'
    reject!('Choose upcoming, live, past or featured events') unless %w[upcoming live past featured].include?(@tab)
    raw=params.fetch(:page,'1').to_s;reject!('Choose a valid event page') unless raw.match?(/\A[1-9]\d{0,3}\z/);@page=raw.to_i
    @types=selection(:types,TYPES.keys);@audiences=selection(:audiences,AUDIENCES.keys)
    @mode=params[:mode].presence||'all';reject!('Choose a valid event mode') unless %w[all online on_site hybrid].include?(@mode)
    dates!
  end
  def reject!(message) = raise(Administration::Rejected.new(message,:unprocessable_entity))
  def selection(key,allowed)
    value=@params[key]||[]
    reject!("Choose valid #{key}") unless value.is_a?(Array)&&value.size<=allowed.size&&value.all?{|v|v.is_a?(String)&&allowed.include?(v)}&&value.uniq==value
    value
  end
  def dates!
    range=@params[:date_range].presence||'all';today=@now.in_time_zone(@zone).to_date
    case range
    when 'all' then return
    when 'today' then @from=@to=today
    when 'week' then @from=today;@to=today+6
    when 'month' then @from=today;@to=today+29
    when 'custom'
      @from=Date.iso8601(@params[:from].to_s);@to=Date.iso8601(@params[:to].to_s)
    else reject!('Choose a valid date range')
    end
    reject!('Choose a date range of 1–366 days') unless (@to-@from).to_i.between?(0,365)
  rescue Date::Error,ArgumentError
    reject!('Choose valid start and end dates')
  end
  def visible
    scope=Event.kept.where(status:'published')
    SystemSetting.config['public_events_enabled'] ? scope : scope.none
  end
  def base
    case tab
    when 'upcoming' then visible.where('starts_at > ?',@now)
    when 'live' then visible.where('starts_at <= ? AND ends_at > ?',@now,@now).where(format:%w[online hybrid])
    when 'past' then visible.where('ends_at <= ?',@now)
    when 'featured' then visible.where(public_featured:true).where('ends_at > ?',@now)
    end
  end
  def audience(scope,values)
    return scope if values.empty?
    sql=["events.target_audiences = '[]'::jsonb"]+values.map{'events.target_audiences @> ?::jsonb'}
    scope.where(sql.join(' OR '),*values.map{|v|[v].to_json})
  end
  def filtered
    scope=base
    scope=scope.where(event_type:@types.flat_map{|t|TYPES.fetch(t)[:values]}) if @types.any?
    scope=audience(scope,@audiences)
    scope=scope.where(format:@mode) unless @mode=='all'
    if from
      last=to+1
      scope=scope.where(starts_at:@zone.local(from.year,from.month,from.day)...@zone.local(last.year,last.month,last.day))
    end
    if @params[:q].present?
      term="%#{ActiveRecord::Base.sanitize_sql_like(@params[:q].to_s.strip.first(150))}%"
      scope=scope.where('events.title ILIKE :q OR events.description ILIKE :q OR events.location ILIKE :q',q:term)
    end
    scope
  end
  def rows = filtered.includes(:organizer).with_attached_banner.order(starts_at:tab=='past' ? :desc : :asc,id: :asc).offset((page-1)*6).limit(6).to_a
  def meta
    total=filtered.count
    {page:page,per_page:6,total:total,total_pages:(total/6.0).ceil}
  end
  def facets
    {total:base.count,types:TYPES.map{|key,info|{key:key,label:info[:label],count:base.where(event_type:info[:values]).count}},audiences:AUDIENCES.map{|key,label|{key:key,label:label,count:audience(base,[key]).count}}}
  end
end
