class Api::V1::AdminMentorApplicationsController < ApplicationController
  before_action :require_admin!
  before_action -> {Administration.authorize!(current_user,'users.read')}
  before_action {response.headers['Cache-Control']='private, no-store'}
  def index
    page=params.fetch(:page,'1').to_s
    raise Administration::Rejected.new('Choose a valid page',:unprocessable_entity) unless page.match?(/\A[1-9]\d{0,3}\z/)
    scope=MentorApplication.where.not(status:'draft').joins(:user).includes(:user).order(submitted_at: :desc,id: :desc)
    if params[:status].present?&&params[:status]!='all'
      raise Administration::Rejected.new('Choose a valid status',:unprocessable_entity) unless %w[submitted changes_requested approved rejected].include?(params[:status])
      scope=scope.where(status:params[:status])
    end
    if params[:q].present?
      term="%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(150))}%"
      scope=scope.where('users.full_name ILIKE :q OR users.email ILIKE :q',q:term)
    end
    total=scope.count
    render json:{items:scope.limit(15).offset((page.to_i-1)*15).map{|r|{id:r.id,name:r.user.full_name,email:r.user.email,headline:r.headline,status:r.status,submitted_at:r.submitted_at}},total:total,page:page.to_i,total_pages:(total/15.0).ceil,can_review:current_user.management_permission?('users.update')}
  end
  def show
    raise ActiveRecord::RecordNotFound if record.status=='draft'
    render json:serialized
  end
  def document
    raise ActiveRecord::RecordNotFound if record.status=='draft'
    kind=params[:kind].to_s
    raise ActiveRecord::RecordNotFound unless MentorApplication::UPLOADS.include?(kind)
    attachment=record.public_send(kind);raise ActiveRecord::RecordNotFound unless attachment.attached?
    Administration.audit!(current_user,'mentor_application.document_downloaded',record,{document_kind:kind})
    response.headers['X-Content-Type-Options']='nosniff'
    send_data attachment.download,type:attachment.content_type,filename:attachment.filename.to_s,disposition:'attachment'
  end
  def review
    Administration.transaction do
      current_user.reload;Administration.authorize!(current_user,'users.read');Administration.authorize!(current_user,'users.update')
      raise Administration::Rejected,'Account is inactive' unless current_user.is_active?
      record.lock!;record.user.reload
      Administration.manage_user!(current_user,record.user)
      raise Administration::Rejected.new('This application changed. Reload before reviewing.',:conflict) unless params[:lock_version].to_s.match?(/\A\d+\z/)&&params[:lock_version].to_i==record.lock_version
      raise Administration::Rejected.new('Only submitted applications can be reviewed',:unprocessable_entity) unless record.status=='submitted'
      status=params[:decision].to_s
      raise Administration::Rejected.new('Choose approve, request changes or reject',:unprocessable_entity) unless %w[approved changes_requested rejected].include?(status)
      note=params[:note].to_s.strip
      raise Administration::Rejected.new('Explain the requested changes or rejection',:unprocessable_entity) if status!='approved'&&note.blank?
      if status=='approved'
        raise Administration::Rejected.new('The applicant account is inactive',:unprocessable_entity) unless record.user.is_active?
        raise Administration::Rejected.new('The application is incomplete',:unprocessable_entity) if record.submission_errors.any?
        mentor_role=Role.all.find{|r|r.canonical_name=='mentor'}||Role.create!(name:'mentor')
        record.user.additional_roles<<mentor_role unless record.user.has_role?('mentor')
        profile=record.user.mentor_profile||record.user.build_mentor_profile(currency:'USD',timezone:SystemSetting.config['timezone'],languages:[],education:[],experience:[],accepting_bookings:false,is_published:false)
        profile.assign_attributes(title:record.headline,bio:record.background,years_of_experience:record.years_of_experience,is_verified:true)
        profile.avatar=record.profile_photo.blob if record.profile_photo.attached?
        profile.save!
        if record.form_version>=2
          profile.skills=record.expertise_tags.map{|name|Skill.find_or_create_by!(name:name)}
        end
      end
      record.update!(status:status,review_note:note,reviewed_by:current_user,reviewed_at:Time.current)
      Administration.audit!(current_user,"mentor_application.#{status}",record,{status:status})
      Notification.deliver(user:record.user,source_key:"mentor-application-review-#{record.id}-#{record.lock_version}",title:status=='approved' ? 'Mentor Application Approved' : 'Mentor Application Update',message:status=='approved' ? 'Your mentor application has been approved. Complete your mentor profile and availability to begin.' : 'Your mentor application has been reviewed. Open your application to see the decision and feedback.',category:'system',topic:'platform',icon:'users',href:'/mentor/application')
    end
    render json:serialized
  end
  private
  def record = @record||=MentorApplication.includes(user:[:role,:additional_roles]).find(params[:id])
  def serialized
    MentorApplicationSerializer.new(record).as_json.merge(applicant:{id:record.user.id,name:record.user.full_name,email:record.user.email},reviewer:record.reviewed_by&.full_name,can_review:current_user.management_permission?('users.update')&&current_user.id!=record.user_id&&(!record.user.platform_admin?||current_user.super_admin?))
  end
end
