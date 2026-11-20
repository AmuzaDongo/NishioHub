require 'csv'
class Api::V1::AdminGoalDetailsController < Api::V1::AdminGoalsController
  def show
    query=AdminGoalQuery.new
    row=query.rows(query.base.where('goal_rows.goal_key = ?',goal.goal_key)).first
    render json:row.merge(summary:GoalDetailsQuery.new(goal).summary,has_cover:goal.cover.attached?,upload_limit_mb:[SystemSetting.config['max_upload_mb'],10].min,capabilities:{manage:current_user.management_permission?('dashboard.manage')})
  end
  def section
    query=GoalDetailsQuery.new(goal)
    case params[:section]
    when 'updates' then result=query.updates(page:page,q:params[:q])
    when 'activity' then result=query.activity(page:page,q:params[:q])
    when 'tasks'
      scope=goal.goal_milestones.where('title ILIKE ?',term).order(Arel.sql('target_date ASC NULLS LAST,id ASC'))
      result={items:scope.limit(20).offset((page-1)*20).as_json(only:[:id,:title,:target_date,:completed,:lock_version]),meta:meta(scope.count)}
    when 'attachments'
      scope=goal.goal_attachments.active.with_attached_file.where('title ILIKE ?',term).order(created_at: :desc,id: :desc)
      result={items:scope.limit(20).offset((page-1)*20).map{|a|GoalDetailsQuery.attachment(a)},meta:meta(scope.count)}
    else return render_error('Choose tasks, updates, attachments or activity',:unprocessable_entity)
    end
    render json:result
  end
  def save_update
    source=object(:update)
    write do
      item=params[:update_id] ? goal.goal_updates.active.lock.find(params[:update_id]) : goal.goal_updates.new(author:current_user,author_name:current_user.full_name)
      AdminGoalManagement.revision!(item,source[:lock_version]) if item.persisted?
      old=item.body;item.update!(body:source[:body]);goal.touch
      Administration.audit!(current_user,'goal.update_saved',goal,{update_id:item.id,previous_body:old,body:item.body})
    end
    head :no_content
  end
  def remove_update
    write do
      item=goal.goal_updates.active.lock.find(params[:update_id]);AdminGoalManagement.revision!(item,params[:lock_version]);item.update!(is_active:false);goal.touch
      Administration.audit!(current_user,'goal.update_removed',goal,{update_id:item.id})
    end
    head :no_content
  end
  def save_attachment
    source=object(:attachment)
    write do
      raise Administration::Rejected.new('Keep at most 100 active attachments per goal',:unprocessable_entity) if goal.goal_attachments.active.count>=100
      item=goal.goal_attachments.new(source.permit(:title,:url).merge(author:current_user,author_name:current_user.full_name))
      item.file=GoalAttachment.upload!(source[:file]) if source[:file].present?
      item.save!;goal.touch
      Administration.audit!(current_user,'goal.attachment_added',goal,{attachment_id:item.id,title:item.title})
    end
    head :no_content
  end
  def remove_attachment
    write do
      item=goal.goal_attachments.active.lock.find(params[:attachment_id]);AdminGoalManagement.revision!(item,params[:lock_version]);item.update!(is_active:false);goal.touch
      Administration.audit!(current_user,'goal.attachment_removed',goal,{attachment_id:item.id,title:item.title})
    end
    head :no_content
  end
  def file
    item=goal.goal_attachments.active.find(params[:attachment_id]);raise ActiveRecord::RecordNotFound unless item.file.attached?
    Administration.audit!(current_user,'goal.attachment_downloaded',goal,{attachment_id:item.id})
    send_data item.file.download,type:item.file.content_type,filename:item.file.filename.to_s,disposition:'attachment'
  end
  def cover
    raise ActiveRecord::RecordNotFound unless goal.cover.attached?
    send_data goal.cover.download,type:goal.cover.content_type,filename:goal.cover.filename.to_s,disposition:'inline'
  end
  def save_cover
    write do
      AdminGoalManagement.revision!(goal,params[:lock_version])
      if [true,'true'].include?(params[:remove_cover])
        goal.cover=nil
      else
        f=params[:file]
        unless f.is_a?(ActionDispatch::Http::UploadedFile)&&f.size<=2.megabytes&&%w[image/jpeg image/png image/webp].include?(Marcel::MimeType.for(f.tempfile))
          raise Administration::Rejected.new('Choose a JPEG, PNG or WebP image up to 2 MB',:unprocessable_entity)
        end
        goal.cover=f
      end
      goal.save!;goal.touch;Administration.audit!(current_user,'goal.cover_updated',goal,{removed:[true,'true'].include?(params[:remove_cover])})
    end
    head :no_content
  end
  def duplicate
    source=object(:goal);copy=nil
    write do
      AdminGoalManagement.revision!(goal,source[:lock_version])
      values=goal.attributes.slice('title','description','icon','category','priority','tracking_status','platform_program_id','user_id').merge(source.permit(:title,:target_date,:user_id,:platform_program_id).to_h).merge('kind'=>goal.goal_kind,'progress'=>0)
      values['target_date']=nil if source[:target_date].blank?
      copy=AdminGoalManagement.save!(current_user,values)
      copy.cover=goal.cover.blob if goal.cover.attached?;copy.save!
      shift=goal.target_date&&copy.target_date ? (copy.target_date-goal.target_date).to_i : nil
      goal.goal_milestones.each{|m|copy.goal_milestones.create!(title:m.title,target_date:shift&&m.target_date ? m.target_date+shift : nil,completed:false)}
      goal.goal_attachments.active.each do |a|
        item=copy.goal_attachments.new(title:a.title,url:a.url,author:current_user,author_name:current_user.full_name)
        item.file=a.file.blob if a.file.attached?;item.save!
      end
      Administration.audit!(current_user,'goal.duplicated',copy,{source:goal.goal_key})
    end
    render json:{id:copy.goal_key},status: :created
  end
  def report
    summary=GoalDetailsQuery.new(goal).summary
    csv=CSV.generate do |out|
      out<<%w[metric value]
      {id:goal.goal_key,title:goal.title,priority:goal.priority,status:goal.display_status,progress:goal.progress,target_date:goal.target_date,created_at:goal.created_at.iso8601}.merge(summary.slice(:completed_at,:days_taken,:total_tasks,:completed_tasks,:task_completion_rate,:updates,:attachments)).each{|k,v|out<<[k,AdminUserQuery.csv_cell(v)]}
      summary[:trend].each{|p|out<<[p[:at],p[:progress]]}
    end
    Administration.audit!(current_user,'goal.report_exported',goal,{})
    send_data csv,type:'text/csv; charset=utf-8',filename:"goal-#{goal.goal_key}-report.csv"
  end
  private
  def goal = @goal ||= AdminGoalManagement.find!(params[:id])
  def page = [[params.fetch(:page,1).to_i,1].max,100000].min
  def meta(total) = {page:page,per_page:20,total:total,total_pages:(total/20.0).ceil}
  def term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(100))}%"
  def write
    Administration.transaction do
      AdminGoalManagement.authorize!(current_user);goal.lock!;raise ActiveRecord::RecordNotFound if goal.archived_at
      yield
    end
  end
end
