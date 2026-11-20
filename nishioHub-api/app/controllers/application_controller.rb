class ApplicationController < ActionController::API
  include ActiveStorage::SetCurrent

  rescue_from ActiveRecord::StaleObjectError, with: ->(_error) { render_error('This record changed. Reload it before saving.', :conflict) }
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_bad_request
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable
  rescue_from ActiveRecord::RecordNotDestroyed, with: :render_unprocessable
  rescue_from Administration::Rejected, with: ->(error) { render_error(error.message, error.status) }

  before_action :enforce_platform_mode
  before_action :enforce_upload_limit

  private

  def enforce_upload_limit
    limit = SystemSetting.config['max_upload_mb'].megabytes
    pending = [params.to_unsafe_h]
    until pending.empty?
      item = pending.pop
      if item.is_a?(Hash)
        pending.concat(item.values)
      elsif item.is_a?(Array)
        pending.concat(item)
      elsif item.is_a?(ActionDispatch::Http::UploadedFile) && item.size > limit
        return render_error("Files must be #{SystemSetting.config['max_upload_mb']} MB or smaller", :unprocessable_entity)
      end
    end
  end

  def enforce_platform_mode
    return if controller_name == 'system_settings' && action_name == 'public_config'
    return if controller_name == 'auth' && action_name.in?(%w[login logout])
    return if controller_name == 'users' && action_name == 'verify_email'
    return unless SystemSetting.config['platform_mode'] == 'maintenance'
    return if current_user&.platform_admin?

    response.headers['Retry-After'] = '300'
    render_error(SystemSetting.config['maintenance_message'], :service_unavailable)
  end

  def render_error(detail, status)
    render json: { detail: detail }, status: status
  end

  def render_not_found(_error = nil)
    render_error("Not found", :not_found)
  end

  def render_bad_request(error)
    render_error(error.message, :bad_request)
  end

  def render_unprocessable(error)
    render_error(error.record.errors.full_messages, :unprocessable_entity)
  end

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = load_current_user
  end

  def load_current_user
    header = request.headers["Authorization"].to_s
    token = header.start_with?("Bearer ") ? header.split(" ", 2).last : nil
    return nil if token.blank?

    payload = JsonWebToken.decode(token)
    email = payload && payload["sub"]
    return nil if email.blank?

    user = User.includes(:role, :additional_roles).find_by(email: email)
    return nil if user && (!user.is_active? || payload["user_id"] != user.id || payload.fetch("auth_version", 0) != user.auth_version)
    if user.nil?
      @auth_error = "User not found"
      @auth_status = :not_found
    end
    user
  rescue JsonWebToken::DecodeError
    nil
  end

  def authenticate_user!
    if current_user
      current_user.update_column(:last_active_at, Time.current) if current_user.last_active_at.nil? || current_user.last_active_at < 1.minute.ago
      return
    end

    render_error(@auth_error || "Invalid token", @auth_status || :unauthorized)
  end

  def require_admin!
    authenticate_user!
    return if performed?

    return if current_user.platform_admin?

    render_error("Administrator access required", :forbidden)
  end

  def require_mentor!
    authenticate_user!
    return if performed?

    return if current_user.has_role?('mentor')

    render_error("Mentor access required", :forbidden)
  end

  def pagination!
    skip = params.fetch(:skip, 0).to_i
    limit = params.fetch(:limit, 10).to_i

    if skip.negative?
      render_error("skip must be greater than or equal to 0", :unprocessable_entity)
      return
    end

    if limit.negative? || limit > 100
      render_error("limit must be between 0 and 100", :unprocessable_entity)
      return
    end

    [skip, limit]
  end

  def payload_params(*keys)
    source = params[:user].present? ? params.require(:user) : params
    source.permit(*keys)
  end
end
