class Api::V1::AdminMenteeDetailsController < ApplicationController
  before_action :require_admin!
  before_action -> { Administration.authorize!(current_user, 'users.read') }
  before_action { response.headers['Cache-Control'] = 'private, no-store' }
  before_action :set_mentee
  def show
    render json: AdminMenteeDetails.new(@mentee, current_user).call
  end
  def section
    page = [[params.fetch(:page, 1).to_i, 1].max, 10000].min
    render json: AdminMenteeDetails.new(@mentee, current_user).section(params[:section].to_s, page, params[:q].to_s.first(150).strip)
  end
  def avatar
    file = params[:avatar]
    unless file.is_a?(ActionDispatch::Http::UploadedFile) && file.size <= 5.megabytes && Marcel::MimeType.for(file.tempfile).in?(%w[image/jpeg image/png image/webp])
      return render_error('Choose a JPEG, PNG or WebP image up to 5 MB', :unprocessable_entity)
    end
    mutate_avatar { @mentee.avatar.attach(file) }
    render json: AdminMenteeQuery.rows(AdminMenteeQuery.base.where(users: { id: @mentee.id }), current_user).first
  end
  def certificate
    Administration.authorize!(current_user, 'users.export')
    cert = LearningCertificate.joins(:learning_enrollment).where(learning_enrollments: { user_id: @mentee.id }).find_by!(identifier: params[:certificate_id])
    raise ActiveRecord::RecordNotFound unless cert.learning_enrollment.course_complete?
    send_data LearningCertificateDocument.new(cert).svg, type: 'image/svg+xml', disposition: 'attachment', filename: "nishiohub-certificate-#{cert.identifier}.svg"
  end
  private
  def set_mentee = @mentee = AdminMenteeManagement.find!(params[:id])
  def mutate_avatar
    Administration.transaction do
      current_user.reload
      Administration.authorize!(current_user, 'users.read')
      Administration.authorize!(current_user, 'users.update')
      @mentee.lock!
      Administration.manage_user!(current_user, @mentee)
      AdminUserManagement.revision!(@mentee, params[:lock_version])
      yield
      @mentee.touch
      Administration.audit!(current_user, 'mentee.avatar_updated', @mentee, { avatar_changed: true })
    end
  end
end
