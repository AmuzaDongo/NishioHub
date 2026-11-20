class Api::V1::MentorApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action {response.headers['Cache-Control']='private, no-store'}
  def show
    current_user.with_lock { @record=MentorApplication.find_or_create_by!(user:current_user) do |application|
      application.assign_attributes(form_version:2,full_name:current_user.full_name,contact_email:current_user.email,phone_number:ApplicationPhoneNumber.prefill(current_user.phone_number),location:current_user.location.to_s)
    end }
    render_record
  end
  def update
    record.with_lock do
      editable!;revision!
      source=params.require(:application)
      %w[expertise_tags target_learners].each do |field|
        return render_error("#{field.humanize} must be a list",:unprocessable_entity) if source.key?(field)&&!source[field].is_a?(Array)
      end
      attributes=source.permit(:headline,:background,:expertise,:years_of_experience,:motivation,:references_text,:conduct_accepted,:safeguarding_accepted,:full_name,:contact_email,:phone_number,:location,:gender,:date_of_birth,:highest_qualification,:organization,:experience_range,:terms_accepted,expertise_tags:[],target_learners:[]).to_h
      record.form_version=2 if (attributes.keys & %w[full_name contact_email phone_number location gender date_of_birth highest_qualification experience_range expertise_tags target_learners terms_accepted]).any?
      if attributes.key?('date_of_birth')
        raw=attributes['date_of_birth']
        begin
          attributes['date_of_birth']=raw.present? ? Date.iso8601(raw) : nil
        rescue Date::Error,ArgumentError,TypeError
          return render_error('Choose a valid date of birth',:unprocessable_entity)
        end
      end
      attributes['expertise']=attributes['expertise_tags'].join(', ') if attributes['expertise_tags'].is_a?(Array)
      if MentorApplication::EXPERIENCE_RANGES.key?(attributes['experience_range'])
        range=MentorApplication::EXPERIENCE_RANGES.fetch(attributes['experience_range'])
        attributes['years_of_experience']=range.cover?(record.years_of_experience) ? record.years_of_experience : range.first
      end
      record.assign_attributes(attributes)
      record.save!
    end
    render_record
  end
  def upload
    kind=params[:kind].to_s;document_kind!(kind)
    file=params[:file]
    limit=kind=='profile_photo' ? 2.megabytes : 5.megabytes
    types=kind=='profile_photo' ? %w[image/jpeg image/png] : MentorApplication::TYPES
    unless file.is_a?(ActionDispatch::Http::UploadedFile)&&file.size<=limit&&types.include?(file.content_type)&&Marcel::MimeType.for(file.tempfile)==file.content_type
      return render_error(kind=='profile_photo' ? 'Choose a JPEG or PNG photo up to 2 MB' : 'Choose a PDF, JPEG or PNG document up to 5 MB',:unprocessable_entity)
    end
    record.with_lock do
      editable!;revision!
      record.public_send("#{kind}=",file)
      record.updated_at=Time.current
      record.save!
    end
    render_record
  end
  def remove_document
    document_kind!(params[:kind])
    old=nil
    record.with_lock do
      editable!;revision!
      attachment=record.public_send(params[:kind]);old=attachment.blob if attachment.attached?
      attachment.detach
      record.update!(updated_at:Time.current)
    end
    old&.purge_later
    render_record
  end
  def document
    document_kind!(params[:kind]);attachment=record.public_send(params[:kind])
    raise ActiveRecord::RecordNotFound unless attachment.attached?
    response.headers['X-Content-Type-Options']='nosniff'
    send_data attachment.download,type:attachment.content_type,filename:attachment.filename.to_s,disposition:'attachment'
  end
  def submit
    Administration.transaction do
      current_user.reload
      raise Administration::Rejected,'Account is inactive' unless current_user.is_active?
      record.lock!;editable!;revision!
      raise Administration::Rejected.new('Your mentor profile is already verified',:unprocessable_entity) if current_user.mentor_profile&.is_verified?
      problems=record.submission_errors
      return render_error(problems,:unprocessable_entity) if problems.any?
      raise Administration::Rejected.new('Review and accept the current policies before submitting',:unprocessable_entity) unless params[:policy_version]==MentorApplication::POLICY_VERSION
      record.update!(status:'submitted',submitted_at:Time.current,consented_at:Time.current,policy_version:MentorApplication::POLICY_VERSION,reviewed_by:nil,reviewed_at:nil,review_note:'')
      Administration.audit!(current_user,'mentor_application.submitted',record,{status:'submitted'})
      User.where(is_active:true).includes(:role,:additional_roles).find_each do |admin|
        next unless admin.platform_admin?&&admin.management_permission?('users.read')
        Notification.deliver(user:admin,source_key:"mentor-application-#{record.id}-#{record.lock_version}",title:'Mentor Application Submitted',message:'A mentor application is ready for review.',category:'system',topic:'platform',icon:'users',href:'/admin/mentor-applications')
      end
    end
    render_record
  end
  private
  def record = @record||=current_user.mentor_application||raise(ActiveRecord::RecordNotFound)
  def render_record
    # Attachment callbacks touch the parent revision; reload only after the upload transaction commits.
    record.reload
    render json:MentorApplicationSerializer.new(record).as_json.merge(profile_verified:!!current_user.mentor_profile&.is_verified?)
  end
  def document_kind!(kind)
    raise Administration::Rejected.new('Choose a valid document',:unprocessable_entity) unless MentorApplication::UPLOADS.include?(kind)
  end
  def editable!
    raise Administration::Rejected.new('This application is locked while under review or after a decision',:unprocessable_entity) unless record.editable?
  end
  def revision!
    raise Administration::Rejected.new('Your application changed. Reload before saving.',:conflict) unless params[:lock_version].to_s.match?(/\A\d+\z/)&&params[:lock_version].to_i==record.lock_version
  end
end
