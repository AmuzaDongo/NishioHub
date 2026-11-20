class Api::V1::BookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_booking, only: %i[show update review]

  def index
    scope = Booking.includes(
      :review,
      service: [:category, :reviews],
      mentor: [:profile, { mentor_profile: :skills }, :services, :mentor_reviews],
      mentee: :profile
    ).where("mentee_id = :id OR mentor_id = :id OR bookings.id IN (SELECT booking_id FROM booking_participants WHERE user_id = :id)", id: current_user.id)

    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(mentor_id: current_user.id) if params[:role] == "mentor"
    scope = scope.where("mentee_id = :id OR bookings.id IN (SELECT booking_id FROM booking_participants WHERE user_id = :id)", id: current_user.id) if params[:role] == "mentee"
    scope = scope.order(scheduled_at: :desc)

    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [[params.fetch(:per_page, 50).to_i, 1].max, 100].min
    total = scope.count
    bookings = scope.offset((page - 1) * per_page).limit(per_page)

    render json: {
      bookings: bookings.map { |booking| BookingSerializer.new(booking).as_json },
      meta: {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: (total.to_f / per_page).ceil
      }
    }, status: :ok
  end

  def show
    return render_error("Booking not found", :not_found) unless participant?

    render json: BookingSerializer.new(@booking).as_json, status: :ok
  end

  def create
    return render_error('New mentorship bookings are paused', :forbidden) unless SystemSetting.config['matching_enabled']
    unless current_user.has_role?('mentee')
      return render_error("Mentee access required", :forbidden)
    end

    service = Service.active.includes(:mentor).find_by(id: params[:service_id])
    return render_error("Service not found", :not_found) if service.nil?
    return render_error("You cannot book your own service", :forbidden) if service.mentor_id == current_user.id

    mentor_profile = service.mentor.mentor_profile
    unless mentor_profile&.accepting_bookings
      return render_error("This mentor is not accepting bookings", :unprocessable_entity)
    end

    scheduled_at = parse_scheduled_at(params[:scheduled_at])
    return render_error("scheduled_at is invalid", :unprocessable_entity) if scheduled_at.nil?

    slot = nil
    if params[:availability_slot_id].present?
      slot = service.mentor.availability_slots.find_by(id: params[:availability_slot_id], is_booked: false)
      return render_error("Availability slot not found", :not_found) if slot.nil?

      scheduled_at = slot.starts_at
    end

    return render_error("scheduled_at must be in the future", :unprocessable_entity) if scheduled_at <= Time.current

    booking = Booking.new(
      service: service,
      mentee: current_user,
      mentor: service.mentor,
      status: "pending",
      scheduled_at: scheduled_at,
      duration: service.duration,
      total_price: service.price,
      payment_status: "pending"
    )

    Booking.transaction do
      User.where(id: [service.mentor_id, current_user.id]).order(:id).lock.load
      if BookingSchedule.conflict?(mentor_id: service.mentor_id, mentee_id: current_user.id, starts_at: scheduled_at, duration: service.duration)
        return render_error('The mentor or mentee already has a session at this time', :unprocessable_entity)
      end
      booking.save!
      slot&.update!(is_booked: true)
    end

    render json: BookingSerializer.new(booking).as_json, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages, :unprocessable_entity)
  end

  def update
    return render_error("Booking not found", :not_found) unless participant?

    new_status = params[:status].to_s
    return render_error("Invalid status", :unprocessable_entity) unless Booking::STATUSES.include?(new_status)
    return render_error("You cannot change this booking to #{new_status}", :forbidden) unless allowed_transition?(new_status)

    @booking.update!(status: new_status)
    render json: BookingSerializer.new(@booking).as_json, status: :ok
  end

  def review
    return render_error("Only the mentee can review this booking", :forbidden) unless @booking.mentee_id == current_user.id
    return render_error("Only completed sessions can be reviewed", :unprocessable_entity) unless @booking.status == "completed"
    return render_error("This booking has already been reviewed", :unprocessable_entity) if @booking.review.present?

    review = @booking.build_review(
      service: @booking.service,
      mentor: @booking.mentor,
      mentee: current_user,
      rating: params[:rating],
      comment: params[:comment]
    )

    if review.save
      render json: ReviewSerializer.new(review).as_json, status: :created
    else
      render_error(review.errors.full_messages, :unprocessable_entity)
    end
  end

  private

  def set_booking
    @booking = Booking.includes(
      :review,
      service: [:category, :reviews],
      mentor: [:profile, { mentor_profile: :skills }, :services, :mentor_reviews],
      mentee: :profile
    ).find_by(id: params[:id])
    render_error("Booking not found", :not_found) if @booking.nil?
  end

  def participant?
    @booking.present? && ([@booking.mentee_id, @booking.mentor_id].include?(current_user.id) || @booking.booking_participants.exists?(user_id: current_user.id))
  end

  def parse_scheduled_at(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def allowed_transition?(new_status)
    return false unless [@booking.mentee_id, @booking.mentor_id].include?(current_user.id)
    return false if @booking.booking_participants.count > 1 && @booking.mentor_id != current_user.id
    return false if new_status == 'completed' && @booking.booking_participants.count > 1 && @booking.scheduled_at + @booking.duration.minutes > Time.current
    return false if @booking.status == new_status

    case @booking.status
    when "pending"
      (new_status == "confirmed" && @booking.mentor_id == current_user.id) ||
        (new_status == "cancelled" && participant?)
    when "confirmed"
      (new_status == "completed" && @booking.mentor_id == current_user.id) ||
        (new_status == "cancelled" && participant?)
    else
      false
    end
  end
end
