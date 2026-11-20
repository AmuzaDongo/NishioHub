class Api::V1::ResourceCommentsController < ApplicationController
  before_action :authenticate_user!,except: :index
  before_action :require_admin!,only:%i[moderation review]
  before_action ->{Administration.authorize!(current_user,'dashboard.read')},only:%i[moderation review]
  before_action {response.headers['Cache-Control']='private, no-store'}
  def index
    response.headers['Cache-Control']='no-store'
    resource=public_resource
    scope=resource.resource_comments.where(status:'approved').joins(:user).where(users:{is_active:true}).order(created_at: :desc,id: :desc)
    render json:{items:scope.offset((page-1)*10).limit(10).map(&:public_json),total:scope.count,page:page}
  end
  def mine
    public_resource
    render json:{items:current_user.resource_comments.where(platform_resource_id:params[:id]).order(created_at: :desc,id: :desc).limit(20).map{|c|c.public_json.merge(status:c.status)}}
  end
  def create
    resource=public_resource;source=params.require(:comment)
    raise Administration::Rejected.new('Comment must be an object',:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    fields=source.permit(:body,:display_name,:submission_key).to_h
    current_user.with_lock do
      existing=current_user.resource_comments.find_by(platform_resource:resource,submission_key:fields['submission_key']) if fields['submission_key'].present?
      if existing
        raise Administration::Rejected.new('This submission key was already used for another comment.',:conflict) unless existing.body==fields['body'].to_s.strip&&existing.display_name==fields['display_name'].to_s.strip
        return render json:existing.public_json.merge(status:existing.status),status: :ok
      end
      raise Administration::Rejected.new('You have posted too many comments. Please try again in an hour.',:too_many_requests) if current_user.resource_comments.where(created_at:1.hour.ago..).count>=10
      comment=current_user.resource_comments.create!(fields.merge('platform_resource'=>resource,'status'=>'pending'))
      render json:comment.public_json.merge(status:comment.status),status: :created
    end
  end
  def destroy
    current_user.resource_comments.where(platform_resource_id:params[:id]).find(params[:comment_id]).destroy!
    head :no_content
  end
  def moderation
    resource=PlatformResource.kept.find(params[:id]);scope=resource.resource_comments.order(created_at: :desc,id: :desc)
    status=params[:status].to_s
    raise Administration::Rejected.new('Choose pending, approved, rejected or all comments',:unprocessable_entity) unless %w[pending approved rejected all].include?(status)
    scope=scope.where(status:status) unless status=='all'
    render json:{items:scope.offset((page-1)*20).limit(20).map{|c|c.public_json.merge(status:c.status,lock_version:c.lock_version,reviewed_at:c.reviewed_at)},total:scope.count,page:page}
  end
  def review
    source=params.require(:review)
    raise Administration::Rejected.new('Review must be an object',:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    raise Administration::Rejected.new('Choose approved or rejected',:unprocessable_entity) unless %w[approved rejected].include?(source[:status])
    Administration.transaction do
      AdminResourceManagement.authorize!(current_user)
      resource=PlatformResource.kept.find(params[:id]);comment=resource.resource_comments.lock.find(params[:comment_id]);AdminResourceManagement.revision!(comment,source[:lock_version])
      comment.update!(status:source[:status],reviewed_at:Time.current)
      Administration.audit!(current_user,'resource.comment_reviewed',resource,{comment_id:comment.id,status:comment.status})
    end
    head :no_content
  end
  private
  def public_resource = PlatformResource.kept.where(published:true,archived:false,visibility:'platform').find(params[:id])
  def page
    value=params.fetch(:page,'1').to_s
    raise Administration::Rejected.new('Choose a valid page',:unprocessable_entity) unless value.match?(/\A[1-9]\d{0,3}\z/)
    value.to_i
  end
end
