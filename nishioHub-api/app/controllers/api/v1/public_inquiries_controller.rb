class Api::V1::PublicInquiriesController < ApplicationController
  before_action :require_admin!,except: %i[create create_event_request create_partnership_request create_program_request my_requests resubmit]
  before_action ->{Administration.authorize!(current_user,'system.manage')},except: %i[create create_event_request create_partnership_request create_program_request my_requests resubmit]
  before_action :require_event_host!,only: %i[create_event_request resubmit]
  before_action :authenticate_user!,only: :my_requests
  before_action {response.headers['Cache-Control']='private, no-store'}
  def create
    source=params.require(:inquiry)
    raise Administration::Rejected.new('Inquiry must be an object',:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    inquiry=PublicInquiry.new(source.permit(:name,:email,:subject,:message,:category))
    raise Administration::Rejected.new('Use the event hosting request form to request an event.',:unprocessable_entity) if inquiry.category=='event_hosting'
    persist_inquiry(inquiry)
  end
  def create_event_request
    source=params.require(:event_request)
    raise Administration::Rejected.new('Event request must be an object',:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    fields=source.permit(:name,:email,:phone_number,:event_type,:title,:description,:preferred_date,:location,:additional_information,:terms_accepted,:submission_key).to_h
    inquiry=PublicInquiry.new(requester:current_user,name:fields['name'],email:fields['email'],subject:fields['title'],message:fields['description'],category:'event_hosting',submission_key:fields['submission_key'],event_details:fields.slice('phone_number','event_type','preferred_date','location','additional_information','terms_accepted').merge('policy_version'=>'2026-11-15','submitted_by_id'=>current_user.id))
    inquiry.event_details['additional_information']||=''
    persist_inquiry(inquiry)
  end
  def create_partnership_request
    source=params.require(:partnership_request)
    raise Administration::Rejected.new('Partnership request must be an object',:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    fields=source.permit(:organization_name,:name,:contact_role,:email,:phone_number,:focus,:message,:terms_accepted,:submission_key,:request_kind,:preferred_at).to_h
    details=fields.slice('organization_name','contact_role','phone_number','focus','terms_accepted','request_kind','preferred_at').merge('policy_version'=>'2026-11-17')
    details['request_kind']||='partnership'
    inquiry=PublicInquiry.new(name:fields['name'],email:fields['email'],subject:"Partnership: #{fields['organization_name']}",message:fields['message'],category:'partnership',submission_key:fields['submission_key'],partnership_details:details)
    persist_inquiry(inquiry)
  end
  def create_program_request
    program=PlatformProgram.active.find(params[:id])
    source=params.require(:inquiry)
    raise Administration::Rejected.new('Inquiry must be an object',:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    interest=source[:interest_type]
    raise Administration::Rejected.new('Choose individual or school interest',:unprocessable_entity) if source.key?(:interest_type)&&!%w[individual school].include?(interest)
    fields=source.permit(:name,:email,:message,:submission_key).to_h
    details={'id'=>program.id,'title'=>program.title}
    details['interest_type']=interest if source.key?(:interest_type)
    inquiry=PublicInquiry.new(fields.merge('category'=>'mentorship','subject'=>"Program inquiry: #{program.title}".first(150),'program_details'=>details))
    persist_inquiry(inquiry)
  end

  def index
    page=params.fetch(:page,'1').to_s
    raise Administration::Rejected.new('Choose a valid page',:unprocessable_entity) unless page.match?(/\A[1-9]\d{0,3}\z/)
    scope=PublicInquiry.includes(:event,:reviewer).order(created_at: :desc,id: :desc)
    render json:{items:scope.offset((page.to_i-1)*20).limit(20).map{|item|EventHostingWorkflow.serialize(item)},total:scope.count}
  end
  def update
    inquiry=PublicInquiry.find(params[:id]);value=params[:reviewed]
    raise Administration::Rejected.new('Use the event request decision actions.',:unprocessable_entity) if inquiry.category=='event_hosting'
    raise Administration::Rejected.new('Reviewed must be true or false',:unprocessable_entity) unless [true,false].include?(value)
    Administration.transaction do
      current_user.reload;raise Administration::Rejected,'Account is inactive' unless current_user.is_active?
      Administration.authorize!(current_user,'system.manage');inquiry.update!(reviewed:value)
      Administration.audit!(current_user,'contact.reviewed',inquiry,{reviewed:value})
    end
    head :no_content
  end

  def decision
    source=params.require(:review)
    raise Administration::Rejected.new('Review must be an object',:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    data=source.permit(:decision,:note,:lock_version,event:%i[starts_at ends_at format location capacity]).to_h
    inquiry=EventHostingWorkflow.review!(current_user,PublicInquiry.find(params[:id]),data)
    render json:EventHostingWorkflow.serialize(inquiry)
  end

  def my_requests
    page=params.fetch(:page,'1').to_s
    raise Administration::Rejected.new('Choose a valid page',:unprocessable_entity) unless page.match?(/\A[1-9]\d{0,3}\z/)
    scope=PublicInquiry.where(category:'event_hosting',requester:current_user).includes(:event,:reviewer).order(created_at: :desc,id: :desc)
    render json:{items:scope.offset((page.to_i-1)*20).limit(20).map{|item|EventHostingWorkflow.serialize(item)},total:scope.count}
  end

  def resubmit
    source=params.require(:event_request)
    raise Administration::Rejected.new('Event request must be an object',:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    inquiry=PublicInquiry.where(category:'event_hosting',requester:current_user).find(params[:id])
    inquiry.with_lock do
      EventHostingWorkflow.revision!(inquiry,source[:lock_version])
      raise Administration::Rejected.new('Only requests awaiting changes can be resubmitted.',:conflict) unless inquiry.status=='changes_requested'
      fields=source.permit(:name,:email,:title,:description,:phone_number,:event_type,:preferred_date,:location,:additional_information,:terms_accepted).to_h
      inquiry.assign_attributes(name:fields['name'],email:fields['email'],subject:fields['title'],message:fields['description'])
      inquiry.event_details=inquiry.event_details.merge(fields.slice('phone_number','event_type','preferred_date','location','additional_information','terms_accepted'))
      inquiry.update!(status:'pending',reviewed:false)
      Administration.audit!(current_user,'event_request.resubmitted',inquiry,{status:'pending'})
      notify_staff(inquiry,"public-inquiry-#{inquiry.id}-resubmitted-#{inquiry.lock_version}",'Event Request Resubmitted')
    end
    render json:EventHostingWorkflow.serialize(inquiry)
  end

  private

  def require_event_host!
    authenticate_user!
    return if performed?
    return if %w[mentor school organization].any?{|role|current_user.has_role?(role)}

    render_error('Only mentors and school/organization accounts can submit event requests.',:forbidden)
  end

  def persist_inquiry(inquiry)
    inquiry.ip_digest=OpenSSL::HMAC.hexdigest('SHA256',Rails.application.secret_key_base,"contact:#{request.remote_ip}")
    PublicInquiry.transaction do
      # Serialize the rate-limit check for concurrent requests from the same origin.
      ApplicationRecord.connection.execute("SELECT pg_advisory_xact_lock(#{inquiry.ip_digest.first(15).to_i(16)})")
      if inquiry.submission_key.present?
        ApplicationRecord.connection.execute("SELECT pg_advisory_xact_lock(#{Digest::SHA256.hexdigest(inquiry.submission_key).first(15).to_i(16)})")
        existing=PublicInquiry.find_by(submission_key:inquiry.submission_key)
        if existing
          inquiry.valid?
          same=%w[name email subject message category event_details partnership_details program_details].all?{|field|existing.public_send(field)==inquiry.public_send(field)}
          raise Administration::Rejected.new('This submission has already been used. Please start a new request.',:conflict) unless same
          render json:{reference:existing.reference,detail:'Your request has been received.'},status: :ok
          return
        end
      end
      raise Administration::Rejected.new('Too many requests. Please try again in an hour.',:too_many_requests) if PublicInquiry.where(ip_digest:inquiry.ip_digest,created_at:1.hour.ago..).count>=5
      inquiry.save!
      notify_staff(inquiry,"public-inquiry-#{inquiry.id}",inquiry.program_details.present? ? 'New Program Inquiry' : {'event_hosting'=>'New Event Hosting Request','partnership'=>'New Partnership Request'}.fetch(inquiry.category,'New Contact Request'))
    end
    render json:{reference:inquiry.reference,detail:'Your request has been received.'},status: :created
  end
  def notify_staff(inquiry,key,title)
    User.with_role('admin').or(User.with_role('super_admin')).where(is_active:true).includes(:role,:additional_roles).find_each do |user|
      next unless user.platform_admin?&&user.management_permission?('system.manage')
      Notification.deliver(user:user,source_key:key,title:title,message:'A contact, partnership or event request is ready to review.',category:'system',topic:'platform',icon:'bell',href:'/admin/inquiries')
    end
  end

end
