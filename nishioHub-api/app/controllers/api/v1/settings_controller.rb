class Api::V1::SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action { response.headers["Cache-Control"] = "no-store" }

  def show
    render json: workspace
  end

  def update_profile
    source=params.require(:profile)
    return render_error('Profile must be an object', :unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    mentor_keys=%w[title years_of_experience hourly_rate languages skills]
    return render_error('Mentor access required for professional fields', :forbidden) if !current_user.has_role?('mentor') && (source.keys & mentor_keys).any?
    %w[languages skills].each do |key|
      if source.key?(key) && !(source[key].is_a?(Array) && source[key].size<=50 && source[key].all? { |v| v.is_a?(String) && v.strip.present? && v.length<=100 })
        return render_error("#{key} must contain up to 50 nonempty strings of at most 100 characters", :unprocessable_entity)
      end
    end
    data=source.permit(:full_name,:email,:phone_number,:school,:grade,:bio,:location,:website,:current_password,:title,:years_of_experience,:hourly_rate,languages:[],skills:[])
    tokens = nil
    current_user.with_lock do
      email = data.key?(:email) ? data[:email].to_s.strip.downcase : current_user.email
      changing_email = email != current_user.email
      if changing_email && !current_user.authenticate(data[:current_password])
        return render_error("Enter your current password to change your email", :unprocessable_entity)
      end
      current_user.assign_attributes(data.slice(:full_name, :phone_number, :location, :website).to_h.transform_values { |value| value.to_s.strip })
      current_user.bio=data[:bio] if data.key?(:bio)
      current_user.email = email
      current_user.is_verified = false if changing_email
      current_user.auth_version += 1 if changing_email
      current_user.save!
      if current_user.has_role?('mentee')
        profile=current_user.mentee_profile || current_user.build_mentee_profile
        profile.assign_attributes(data.slice(:school,:grade,:bio))
        if profile.school.blank? || profile.grade.blank?
          profile.errors.add(:base,'School and class / level are required')
          raise ActiveRecord::RecordInvalid,profile
        end
        profile.save!
      end
      if current_user.has_role?('mentor') && ((data.keys & (mentor_keys+['bio'])).any?)
        professional=current_user.mentor_profile || current_user.build_mentor_profile(title:'Mentor',years_of_experience:0,currency:'USD',timezone:'Africa/Kampala')
        professional.assign_attributes(data.slice(:bio,:title,:years_of_experience,:hourly_rate,:languages))
        professional.save!
        professional.skills=data[:skills].map(&:strip).uniq.map { |name| Skill.find_or_create_by!(name:name) } if data.key?(:skills)
      end
      current_user.profile.update!(bio:data[:bio]) if data.key?(:bio) && current_user.profile
      current_user.profile&.update!(phone_number: current_user.phone_number)
      tokens = rotate_session if changing_email
    end
    render json: workspace.merge(tokens ? { session: tokens } : {})
  end

  def update_preferences
    data = params.require(:preferences).permit(:appearance, :show_online_status, :allow_contact_requests, :learning_format, :weekly_learning_minutes, :session_preference, :mentorship_focus)
    %w[show_online_status allow_contact_requests].each do |key|
      if data.key?(key) && ![true, false].include?(data[key])
        return render_error("#{key} must be true or false", :unprocessable_entity)
      end
    end
    settings.update!(data)
    render json: workspace
  end

  def password
    data = params.require(:password_change).permit(:current_password, :new_password, :password_confirmation)
    current_user.with_lock do
      return render_error("Current password is incorrect", :unprocessable_entity) unless current_user.authenticate(data[:current_password])
      password = data[:new_password].to_s
      return render_error("Use at least #{SystemSetting.config['password_min_length']} characters and at most 72 bytes for your new password", :unprocessable_entity) unless password.length >= SystemSetting.config['password_min_length'] && password.bytesize <= 72
      return render_error("New passwords do not match", :unprocessable_entity) unless password == data[:password_confirmation]
      return render_error("Choose a password different from your current password", :unprocessable_entity) if current_user.authenticate(password)

      current_user.password = password
      current_user.auth_version += 1
      current_user.save!
      render json: { session: rotate_session }
    end
  end

  def avatar
    file = params[:avatar]
    unless file.is_a?(ActionDispatch::Http::UploadedFile) && file.content_type.in?(%w[image/jpeg image/png image/webp]) && file.size <= 5.megabytes
      return render_error("Choose a JPEG, PNG, or WebP image up to 5 MB", :unprocessable_entity)
    end
    # Identify the bytes as well as the declared content type.
    detected = Marcel::MimeType.for(file.tempfile)
    unless detected.in?(%w[image/jpeg image/png image/webp])
      return render_error("This file is not a supported image", :unprocessable_entity)
    end
    current_user.avatar.attach(file)
    render json: workspace
  end

  def remove_avatar
    current_user.with_lock do
      current_user.avatar=nil
      current_user.save!
      if current_user.mentor_profile&.avatar&.attached?
        current_user.mentor_profile.update!(avatar:nil)
      end
      current_user.profile&.update!(profile_picture:nil)
    end
    render json:workspace
  end

  def export
    data = {
      exported_at: Time.current.iso8601,
      account: UserSerializer.new(current_user).as_json,
      mentor_profile: current_user.mentor_profile&.attributes,
      profile: current_user.profile&.attributes&.except("user_id"),
      mentee_profile: current_user.mentee_profile&.attributes&.except("user_id"),
      preferences: preference_json, notifications: current_user.notifications.as_json,
      notification_preferences: notification_json,
      goals: current_user.mentee_goals.as_json(include: [:goal_milestones, :goal_progress_events]), mentor_goals: current_user.mentor_goals.as_json(include: [:goal_milestones, :goal_progress_events]),
      enrollments: current_user.learning_enrollments.as_json(include: [:learning_lesson_completions, :learning_certificate]),
      services: current_user.services.as_json,
      availability: current_user.availability_slots.as_json,
      resources: current_user.mentorship_resources.as_json,
      organized_events: current_user.organized_events.as_json,
      authored_reviews: current_user.given_reviews.as_json,
      event_registrations: current_user.event_registrations.as_json,
      event_suggestions: current_user.event_suggestions.as_json,
      bookings: current_user.mentee_bookings.or(current_user.mentor_bookings).as_json,
      authored_messages: current_user.chat_messages.as_json(only: %i[id conversation_id content created_at])
    }
    send_data JSON.pretty_generate(data), filename: "nishiohub-my-data-#{Date.current}.json", type: "application/json", disposition: "attachment"
  end

  def deactivate
    data = params.require(:account).permit(:current_password, :confirmation)
    Administration.transaction do
      current_user.lock!
      return render_error("Current password is incorrect", :unprocessable_entity) unless current_user.authenticate(data[:current_password])
      return render_error("Type DEACTIVATE to confirm", :unprocessable_entity) unless data[:confirmation] == "DEACTIVATE"

      Administration.ensure_super_admin_remains!(current_user, roles: current_user.effective_roles, active: false)
      current_user.update!(is_active: false, auth_version: current_user.auth_version + 1)
      current_user.refresh_tokens.update_all(revoked: true)
    end
    render json: { detail: "Account deactivated. Contact support to request reactivation." }
  end

  private

  def settings
    @settings ||= current_user.account_setting || AccountSetting.create_or_find_by!(user: current_user)
  end

  def preference_json
    settings.as_json(only: %i[appearance show_online_status allow_contact_requests learning_format weekly_learning_minutes session_preference mentorship_focus])
  end

  def notification_json
    preference = current_user.notification_preference || NotificationPreference.create_or_find_by!(user: current_user)
    preference.as_json(only: NotificationPreference::TOPICS)
  end

  def workspace
    mentee = current_user.mentee_profile
    { user: UserSerializer.new(current_user).as_json,
      profile: { school: mentee&.school.to_s, grade: mentee&.grade.to_s, bio: current_user.bio || (current_user.has_role?('mentee') ? mentee&.bio : nil) || (current_user.has_role?('mentor') ? current_user.mentor_profile&.bio : nil) || current_user.profile&.bio || "" },
      professional: current_user.has_role?('mentor') ? {title:current_user.mentor_profile&.title || 'Mentor',years_of_experience:current_user.mentor_profile&.years_of_experience || 0,hourly_rate:current_user.mentor_profile&.hourly_rate&.to_f,languages:current_user.mentor_profile&.languages || [],skills:current_user.mentor_profile&.skills&.map(&:name) || [],currency:current_user.mentor_profile&.currency || 'USD'} : nil,
      preferences: preference_json, notifications: notification_json }
  end

  def rotate_session
    current_user.refresh_tokens.update_all(revoked: true)
    { access_token: JsonWebToken.encode({ sub: current_user.email, user_id: current_user.id, auth_version: current_user.auth_version }, exp: SystemSetting.config['access_token_minutes'].minutes.from_now),
      refresh_token: RefreshToken.issue_for(current_user).token }
  end
end
