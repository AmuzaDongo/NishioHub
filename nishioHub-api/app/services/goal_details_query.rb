class GoalDetailsQuery
  def initialize(goal) = @goal=goal
  def self.attachment(item)
    {id:item.id,title:item.title,url:item.url,lock_version:item.lock_version,author:item.author_name,created_at:item.created_at.iso8601,file:item.file.attached? ? {filename:item.file.filename.to_s,type:item.file.content_type,size:item.file.byte_size} : nil}
  end
  def summary
    tasks=@goal.goal_milestones;total=tasks.count;completed=tasks.where(completed:true).count
    history=@goal.goal_progress_events.order(created_at: :desc,id: :desc).limit(100).to_a.reverse
    baseline=@goal.goal_progress_events.where('created_at <= ?',30.days.ago).order(created_at: :desc,id: :desc).first
    zone=SystemSetting.config['timezone'];finished=@goal.progress==100 ? @goal.completed_at : nil
    days=finished ? [(finished.in_time_zone(zone).to_date-@goal.created_at.in_time_zone(zone).to_date).to_i,0].max : nil
    {total_tasks:total,completed_tasks:completed,task_completion_rate:total.zero? ? nil : (completed*100.0/total).round(1),completed_at:finished&.iso8601,days_taken:days,
     trend:history.map{|h|{id:h.id,progress:h.progress,at:h.created_at.iso8601,note:h.note}},progress_change:baseline ? @goal.progress-baseline.progress : nil,
     updates:@goal.goal_updates.active.count+@goal.goal_progress_events.count,attachments:@goal.goal_attachments.active.count,
     recent_updates:updates(page:1,size:4)[:items],recent_attachments:@goal.goal_attachments.active.with_attached_file.order(created_at: :desc,id: :desc).limit(3).map{|a|self.class.attachment(a)}}
  end
  def updates(page:,size:20,q:'')
    progress=@goal.goal_progress_events.select("'progress-'||id::text AS item_key, 'progress' AS kind, id AS source_id, progress, note AS body, actor_name AS author, created_at, updated_at, 0 AS lock_version")
    notes=@goal.goal_updates.active.select("'note-'||id::text AS item_key, 'note' AS kind, id AS source_id, NULL::integer AS progress, body, author_name AS author, created_at, updated_at, lock_version")
    union="#{progress.to_sql} UNION ALL #{notes.to_sql}"
    condition="body ILIKE :q OR author ILIKE :q"
    paginated(union,condition,q,page,size).then do |result|
      result[:items]=result[:items].map{|r|{id:r['item_key'],kind:r['kind'],source_id:r['source_id'].to_i,progress:r['progress'],body:r['body'],author:r['author'],created_at:stamp(r['created_at']),updated_at:stamp(r['updated_at']),lock_version:r['lock_version'].to_i}}
      result
    end
  end
  def activity(page:,q:'')
    logs=AdministrationAudit.where(target_type:@goal.class.name,target_id:@goal.id).select("'audit-'||id::text AS item_key, id AS source_id, action AS title, actor_name AS author, created_at")
    history=@goal.goal_progress_events.select("'progress-'||id::text AS item_key, id AS source_id, note AS title, actor_name AS author, created_at")
    union="#{logs.to_sql} UNION ALL #{history.to_sql}"
    paginated(union,'title ILIKE :q OR author ILIKE :q',q,page,20).then do |result|
      result[:items]=result[:items].map{|r|{id:r['item_key'],title:r['title'],author:r['author'],created_at:stamp(r['created_at'])}}
      result
    end
  end
  private
  def stamp(value) = value.respond_to?(:iso8601) ? value.iso8601 : Time.parse(value.to_s).iso8601
  def paginated(union,condition,q,page,size)
    clause=ApplicationRecord.sanitize_sql_array([condition,{q:"%#{ActiveRecord::Base.sanitize_sql_like(q.to_s.first(100))}%"}])
    base="FROM (#{union}) entries WHERE #{clause}"
    count=ApplicationRecord.connection.select_value("SELECT COUNT(*) #{base}").to_i
    rows=ApplicationRecord.connection.select_all("SELECT * #{base} ORDER BY created_at DESC,source_id DESC,item_key DESC LIMIT #{size.to_i} OFFSET #{(page.to_i-1)*size.to_i}").to_a
    {items:rows,meta:{page:page,per_page:size,total:count,total_pages:(count/size.to_f).ceil}}
  end
end
