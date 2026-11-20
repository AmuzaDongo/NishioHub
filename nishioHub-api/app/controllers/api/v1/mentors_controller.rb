class Api::V1::MentorsController < ApplicationController
  before_action :authenticate_user!, only: %i[me update_me stats create_availability update_availability destroy_availability]
  before_action :require_mentor!, only: %i[me update_me stats create_availability update_availability destroy_availability]
  before_action :set_mentor, only: %i[show availability reviews]

  def index
    scope = User.with_role('mentor').where(is_active:true).joins(:mentor_profile).where(mentor_profiles:{is_published:true})
                .includes(:profile, mentor_profile: :skills, services: :category, mentor_reviews: :mentee)

    if params[:q].present?
      scope = scope.where("users.full_name ILIKE ?", "%#{params[:q]}%")
    end

    if params[:skill].present?
      scope = scope.joins(mentor_profile: :skills).where(skills: { name: params[:skill] })
    end

    if params[:available] == "true"
      scope = scope.joins(:mentor_profile).where(mentor_profiles: { accepting_bookings: true })
    end

    scope = case params[:sort]
            when "rating"
              scope.order(Arel.sql("(SELECT AVG(reviews.rating) FROM reviews WHERE reviews.mentor_id = users.id) DESC NULLS LAST"))
            when "price_low"
              scope.joins(:mentor_profile).order("mentor_profiles.hourly_rate ASC NULLS LAST")
            when "price_high"
              scope.joins(:mentor_profile).order("mentor_profiles.hourly_rate DESC NULLS LAST")
            else
              scope.order(created_at: :desc)
            end

    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [[params.fetch(:per_page, 20).to_i, 1].max, 100].min
    total = scope.count
    mentors = scope.offset((page - 1) * per_page).limit(per_page)

    render json: {
      mentors: mentors.map { |mentor| MentorSerializer.new(mentor).as_json },
      meta: {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: (total.to_f / per_page).ceil
      }
    }, status: :ok
  end

  def show
    render json: MentorSerializer.new(@mentor, include_details: true).as_json, status: :ok
  end

  def me
    render json: MentorSerializer.new(current_user, include_details: true).as_json, status: :ok
  end

  def update_me
    profile = current_user.mentor_profile || current_user.build_mentor_profile
    profile.assign_attributes(mentor_profile_params)

    if profile.save
      sync_skills(profile, params[:skills]) if params.key?(:skills)
      update_location(params[:location]) if params[:location].present?
      render json: MentorSerializer.new(current_user.reload, include_details: true).as_json, status: :ok
    else
      render_error(profile.errors.full_messages, :unprocessable_entity)
    end
  end

  def stats
    bookings = current_user.mentor_bookings
    completed = bookings.where(status: "completed")

    render json: {
      totalEarnings: completed.sum(:total_price).to_f,
      completedSessions: completed.count,
      activeServices: current_user.services.active.count,
      uniqueMentees: bookings.distinct.count(:mentee_id),
      upcomingSessions: bookings.where("scheduled_at >= ?", Time.current).where.not(status: "cancelled").count
    }, status: :ok
  end

  def availability
    slots = @mentor.availability_slots.available.order(:starts_at)
    render json: { availability: slots.map { |slot| AvailabilitySlotSerializer.new(slot).as_json } }, status: :ok
  end

  def create_availability
    slot = current_user.availability_slots.new(availability_params)

    if slot.save
      render json: AvailabilitySlotSerializer.new(slot).as_json, status: :created
    else
      render_error(slot.errors.full_messages, :unprocessable_entity)
    end
  end

  def update_availability
    slot = current_user.availability_slots.find_by(id: params[:slot_id])
    return render_error("Availability slot not found", :not_found) if slot.nil?

    if slot.update(availability_params)
      render json: AvailabilitySlotSerializer.new(slot).as_json, status: :ok
    else
      render_error(slot.errors.full_messages, :unprocessable_entity)
    end
  end

  def destroy_availability
    slot = current_user.availability_slots.find_by(id: params[:slot_id])
    return render_error("Availability slot not found", :not_found) if slot.nil?

    slot.destroy!
    render json: { detail: "Availability slot deleted" }, status: :ok
  end

  def reviews
    reviews = @mentor.mentor_reviews.includes(:mentee).order(created_at: :desc)
    render json: { reviews: reviews.map { |review| ReviewSerializer.new(review).as_json } }, status: :ok
  end

  private

  def set_mentor
    @mentor = User.with_role('mentor').where(is_active:true).joins(:mentor_profile).where(mentor_profiles:{is_published:true})
                  .includes(:profile, :availability_slots, mentor_profile: :skills, services: :category, mentor_reviews: :mentee)
                  .find_by(id: params[:id])
    render_error("Mentor not found", :not_found) if @mentor.nil?
  end

  def mentor_profile_params
    params.permit(
      :title, :years_of_experience, :hourly_rate, :accepting_bookings,
      languages: [],
      education: %i[degree institution year],
      experience: %i[title company period description]
    )
  end

  def availability_params
    params.permit(:starts_at, :ends_at)
  end

  def sync_skills(profile, names)
    names = Array(names).map(&:to_s).map(&:strip).reject(&:blank?).uniq
    profile.skills = names.map { |name| Skill.find_or_create_by!(name: name) }
  end

  def update_location(location)
    profile = current_user.profile
    return if profile.nil?

    city, country = location.to_s.split(",").map(&:strip)
    profile.update(city: city.presence || profile.city, country: country.presence || profile.country)
  end
end
