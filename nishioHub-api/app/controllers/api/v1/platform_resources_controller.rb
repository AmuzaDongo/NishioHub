class Api::V1::PlatformResourcesController < ApplicationController
  before_action :authenticate_user!
  def access
    resource = PlatformResource.accessible_to(current_user).find(params[:id])
    raise ActiveRecord::RecordNotFound if resource.url.blank?
    resource.track_access!(current_user, 'link')
    head :no_content
  end
  def file
    resource = PlatformResource.accessible_to(current_user).find(params[:id])
    raise ActiveRecord::RecordNotFound unless resource.file.attached?
    response.headers['Cache-Control'] = 'private, no-store'
    bytes = resource.file.download
    resource.track_access!(current_user, params[:preview]=='true' ? 'view' : 'download')
    send_data bytes, filename: resource.file.filename.to_s, type: resource.file.content_type, disposition: 'attachment'
  end
  def details
    r=PlatformResource.accessible_to(current_user).find(params[:id]);p=r.resource_progresses.find_by(user:current_user);f=r.resource_feedbacks.find_by(user:current_user)
    response.headers['Cache-Control']='private, no-store'
    render json:{id:r.id,title:r.title,description:r.description,resource_type:r.resource_type,tags:r.tags,url:r.url,file:r.file.attached? ? {filename:r.file.filename.to_s,type:r.file.content_type,size:r.file.byte_size} : nil,
      contents:r.resource_contents.order(:position,:id).map{|c|ResourceDetailsQuery.content(c)},language:r.language,duration_seconds:r.duration_seconds,captions:r.captions.attached?,
      progress:p && {percent:p.percent,lock_version:p.lock_version},feedback:f && {rating:f.rating,comment:f.comment},can_participate:!current_user.platform_admin?}
  end
  def progress
    return render_error('Use learner access to record learning progress',:forbidden) if current_user.platform_admin?
    r=PlatformResource.accessible_to(current_user).find(params[:id]);source=params.require(:progress)
    return render_error('Progress must be an object',:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    r.with_lock do
      p=r.resource_progresses.find_or_initialize_by(user:current_user)
      AdminResourceManagement.revision!(p,source[:lock_version])
      p.update!(source.permit(:percent))
      render json:{percent:p.percent,lock_version:p.lock_version,completed_at:p.completed_at&.iso8601}
    end
  end
  def feedback
    return render_error('Use learner access to submit feedback',:forbidden) if current_user.platform_admin?
    r=PlatformResource.accessible_to(current_user).find(params[:id]);source=params.require(:feedback)
    return render_error('Feedback must be an object',:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    r.with_lock do
      return render_error('Open or start the resource before leaving feedback',:forbidden) unless r.resource_progresses.where(user:current_user).where('percent > 0').exists?
      f=r.resource_feedbacks.find_or_initialize_by(user:current_user);f.update!(source.permit(:rating,:comment))
      render json:{rating:f.rating,comment:f.comment}
    end
  end
  def content_access
    r=PlatformResource.accessible_to(current_user).find(params[:id]);c=r.resource_contents.find(params[:content_id]);raise ActiveRecord::RecordNotFound if c.url.blank?
    r.track_access!(current_user,'link');head :no_content
  end
  def supporting_file
    resource=PlatformResource.accessible_to(current_user).find(params[:id]);content=resource.resource_contents.find(params[:content_id])
    raise ActiveRecord::RecordNotFound unless content.file.attached?
    response.headers['Cache-Control']='private, no-store'
    bytes=content.file.download;resource.track_access!(current_user,'download')
    send_data bytes,type:content.file.content_type,filename:content.file.filename.to_s,disposition:'attachment'
  end
  def captions
    r=PlatformResource.accessible_to(current_user).find(params[:id]);raise ActiveRecord::RecordNotFound unless r.captions.attached?
    response.headers['Cache-Control']='private, no-store'
    send_data r.captions.download,type:'text/vtt',filename:r.captions.filename.to_s,disposition:'attachment'
  end

end
