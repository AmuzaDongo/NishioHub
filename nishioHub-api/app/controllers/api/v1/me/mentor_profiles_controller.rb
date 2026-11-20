class Api::V1::Me::MentorProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_mentor!

  ALLOWED_KEYS = %w[
    name headline title bio about hourly_rate currency languages
    years_of_experience timezone skills accepting_bookings is_published
  ].freeze
  AVATAR_TYPES = %w[image/jpeg image/png image/webp].freeze
  AVATAR_MAX_SIZE = 5.megabytes

  def show
    render_profile(ensure_profile)
  end

  def update
    profile = ensure_profile
    raw = raw_payload
    unknown = raw.keys - ALLOWED_KEYS
    return render_error("Unknown fields: #{unknown.join(', ')}", :unprocessable_entity) if unknown.any?

    payload = raw.slice(*ALLOWED_KEYS)

    ActiveRecord::Base.transaction do
      user_attrs={}
      user_attrs[:full_name]=payload['name'] if payload.key?('name')
      user_attrs[:bio]=payload['bio'] if payload.key?('bio')
      user_attrs[:bio]=payload['about'] if payload.key?('about')
      current_user.update!(user_attrs) if user_attrs.present?
      profile.assign_attributes(profile_attributes(payload))
      profile.save!
      sync_skills(profile, payload["skills"]) if payload.key?("skills")
    end

    render_profile(profile)
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages, :unprocessable_entity)
  end

  def avatar
    profile = ensure_profile
    file = params[:avatar]

    return render_error("Avatar is required", :unprocessable_entity) if file.blank?

    unless file.respond_to?(:content_type) && AVATAR_TYPES.include?(file.content_type)
      return render_error("Avatar must be a JPEG, PNG, or WebP image", :unprocessable_entity)
    end

    if file.size > AVATAR_MAX_SIZE
      return render_error("Avatar must be smaller than 5 MB", :unprocessable_entity)
    end

    profile.avatar.purge if profile.avatar.attached?
    profile.avatar.attach(file)

    render_profile(profile)
  end

  def destroy_avatar
    profile = ensure_profile
    profile.avatar.purge if profile.avatar.attached?
    head :no_content
  end

  private

  def ensure_profile
    current_user.mentor_profile || current_user.create_mentor_profile!(
      title: "Mentor",
      bio: "",
      currency: "USD",
      timezone: "UTC",
      languages: [],
      education: [],
      experience: [],
      years_of_experience: 0,
      accepting_bookings: true,
      is_verified: false,
      is_published: true
    )
  end

  def render_profile(profile)
    loaded = MentorProfile.includes(
      :skills,
      user: [:profile, :services, :mentor_reviews, :availability_slots]
    ).find(profile.id)

    render json: MentorSelfSerializer.new(loaded).as_json, status: :ok
  end

  def raw_payload
    flat = params.to_unsafe_h.except("controller", "action", "format", "mentor_profile")
    nested = params[:mentor_profile].present? ? params[:mentor_profile].to_unsafe_h : {}
    flat.merge(nested)
  end

  def profile_attributes(payload)
    attributes = {}

    attributes[:title] = payload["headline"] if payload.key?("headline")
    attributes[:title] = payload["title"] if payload.key?("title")
    attributes[:bio] = payload["bio"] if payload.key?("bio")
    attributes[:bio] = payload["about"] if payload.key?("about")
    attributes[:hourly_rate] = payload["hourly_rate"] if payload.key?("hourly_rate")
    attributes[:currency] = payload["currency"] if payload.key?("currency")
    attributes[:languages] = payload["languages"] if payload.key?("languages")
    attributes[:years_of_experience] = payload["years_of_experience"] if payload.key?("years_of_experience")
    attributes[:timezone] = payload["timezone"] if payload.key?("timezone")
    attributes[:accepting_bookings] = payload["accepting_bookings"] if payload.key?("accepting_bookings")
    attributes[:is_published] = payload["is_published"] if payload.key?("is_published")

    attributes
  end

  def sync_skills(profile, names)
    names = Array(names).map(&:to_s).map(&:strip).reject(&:blank?).uniq
    profile.skills = names.map { |name| Skill.find_or_create_by!(name: name) }
  end
end
