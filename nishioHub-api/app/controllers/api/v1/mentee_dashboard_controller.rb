class Api::V1::MenteeDashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_mentee!

  def show
    bookings = current_user.mentee_bookings.includes(:review, :service, mentor: [:profile, :mentor_profile]).order(:scheduled_at)
    completed = bookings.select { |booking| booking.status == "completed" }
    upcoming = bookings.select { |booking| booking.status.in?(%w[pending confirmed]) && booking.scheduled_at >= Time.current }
    mentor_booking = upcoming.first || completed.last
    goals = current_user.mentee_goals.kept.order(:created_at)
    completed_goals = goals.count(&:completed)
    milestone = ((completed.size / 5) + 1) * 5

    render json: {
      profile: profile_json,
      mentor: (current_user.mentee_profile&.assigned_mentor || mentor_booking&.mentor)&.then { |mentor| MentorSerializer.new(mentor).as_json },
      next_session: upcoming.first && BookingSerializer.new(upcoming.first).as_json,
      completed_sessions: completed.size,
      upcoming_sessions: upcoming.size,
      milestone: milestone,
      session_progress: (completed.size * 100.0 / milestone).round,
      goal_progress: goals.empty? ? 0 : (completed_goals * 100.0 / goals.size).round,
      goals: goals.as_json(only: %i[id title completed]),
      achievements: MenteeAchievements.new(current_user).badges.select { |badge| badge[:earned] }.map { |badge| badge[:name] },
      learning_areas: Category.active.ordered.limit(3).map { |category| CategorySerializer.new(category).as_json }
    }
  end

  def update_profile
    current_user.with_lock do
      profile = current_user.mentee_profile || current_user.build_mentee_profile
      profile.update!(params.require(:profile).permit(:school, :grade, :location, :bio))
    end
    render json: profile_json
  end

  private

  def require_mentee!
    render_error("Mentee access required", :forbidden) unless current_user.has_role?('mentee')
  end

  def profile_json
    profile = current_user.mentee_profile
    legacy = current_user.profile
    {
      name: current_user.full_name,
      school: profile&.school,
      grade: profile&.grade,
      location: profile&.location || [legacy&.city, legacy&.country].compact.join(", "),
      bio: profile&.bio || legacy&.bio,
      avatar: current_user.avatar_url
    }
  end
end
