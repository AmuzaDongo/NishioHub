class Api::V1::AuthController < ApplicationController
  def register
    config = SystemSetting.config
    return render_error('New registrations are currently closed', :forbidden) unless config['registration_enabled']
    data = payload_params(:full_name, :email, :phone_number, :password, :role_id)
    email = data[:email].to_s.strip.downcase
    full_name = data[:full_name].to_s.strip
    phone_number = data[:phone_number].to_s.strip
    password = data[:password].to_s

    return render_error("Email already registered", :bad_request) if User.exists?(email: email)
    return render_error("full_name already taken", :bad_request) if User.exists?(full_name: full_name)
    return render_error("Phone number already registered", :bad_request) if User.exists?(phone_number: phone_number)

    role = resolve_role(data[:role_id])
    return render_error("Invalid role_id", :bad_request) if role == :invalid

    unless password.length >= config['password_min_length'] && password.bytesize <= 72
      return render_error("Password must contain at least #{config['password_min_length']} characters and at most 72 bytes", :unprocessable_entity)
    end

    user = User.new(full_name: full_name, email: email, phone_number: phone_number, role: role)
    user.password = password

    if user.save
      if config['require_email_verification']
        PlatformMailer.with(user: user, base_url: ENV.fetch('API_PUBLIC_URL', request.base_url)).verification.deliver_now
      end
      render json: UserSerializer.new(user).as_json.merge(verification_required: config['require_email_verification']), status: :ok
    else
      render_error(user.errors.full_messages, :unprocessable_entity)
    end
  rescue Net::SMTPError, IOError, SystemCallError, Timeout::Error
    render_error('Account created, but email delivery is unavailable. Use Resend Verification on the sign-in page.', :service_unavailable)
  end

  def resend_verification
    user = User.find_by(email: params[:email].to_s.strip.downcase)
    return render_error('Invalid credentials', :unauthorized) unless user&.is_active? && user.authenticate(params[:password])
    return render_error('Email delivery is not configured', :unprocessable_entity) unless SystemSetting.mail_configured?
    return render json: { detail: 'Email is already verified' } if user.is_verified?

    PlatformMailer.with(user: user, base_url: ENV.fetch('API_PUBLIC_URL', request.base_url)).verification.deliver_now
    render json: { detail: 'Verification email sent. The link is valid for 30 minutes.' }
  rescue Net::SMTPError, IOError, SystemCallError, Timeout::Error
    render_error('Email delivery is unavailable. Please try again later.', :service_unavailable)
  end

  def login
    email = (params[:username].presence || params[:email].presence).to_s.strip.downcase
    password = params[:password].to_s
    user = User.find_by(email: email)

    unless user && user.is_active? && user.authenticate(password)
      return render_error("Invalid credentials", :unauthorized)
    end

    config = SystemSetting.config
    if config['platform_mode'] == 'maintenance' && !user.platform_admin?
      return render_error(config['maintenance_message'], :service_unavailable)
    end
    if config['require_email_verification'] && !user.is_verified? && !user.platform_admin?
      return render_error('Verify your email before signing in', :forbidden)
    end

    access = JsonWebToken.encode({ sub: user.email, user_id: user.id, auth_version: user.auth_version }, exp: SystemSetting.config['access_token_minutes'].minutes.from_now)
    refresh = RefreshToken.issue_for(user)

    render json: {
      access_token: access,
      refresh_token: refresh.token,
      token_type: "bearer"
    }, status: :ok
  end

  def refresh
    token = refresh_token_param
    return render_error("Invalid token", :unauthorized) if token.blank?

    payload = JsonWebToken.decode(token)
    email = payload["sub"]
    return render_error("Invalid token", :unauthorized) if email.blank?

    record = RefreshToken.find_by(token: token)
    return render_error("Invalid token", :unauthorized) if record.nil? || record.expired?

    user = User.find_by(id: record.user_id)
    return render_error("Invalid token", :unauthorized) if user.nil? || !user.is_active? || payload["user_id"] != user.id || payload.fetch("auth_version", 0) != user.auth_version

    access = JsonWebToken.encode({ sub: user.email, user_id: user.id, auth_version: user.auth_version }, exp: SystemSetting.config['access_token_minutes'].minutes.from_now)
    render json: { access_token: access, token_type: "bearer" }, status: :ok
  rescue JsonWebToken::DecodeError
    render_error("Invalid token", :unauthorized)
  end

  def logout
    token = refresh_token_param
    record = RefreshToken.find_by(token: token)
    return render_error("Token not found", :not_found) if record.nil?

    record.update!(revoked: true)
    render json: { detail: "Logged out successfully" }, status: :ok
  end

  private

  def resolve_role(role_id)
    return Role.find_or_create_by!(name: SystemSetting.config['default_registration_role']) if role_id.blank? || role_id.to_i.zero?

    role = Role.find_by(id: role_id)
    role&.name.in?(%w[mentor mentee]) ? role : :invalid
  end

  def refresh_token_param
    params[:refresh_token].presence || params.dig(:auth, :refresh_token).presence
  end
end
