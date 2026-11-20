class Api::V1::MentorshipController < ApplicationController
  before_action :require_mentor!

  def show
    bookings = current_user.mentor_bookings.includes(
      :review, service: [:category, :reviews],
      mentee: [:profile, :mentee_profile],
      mentor: [:profile, { mentor_profile: :skills }, :services, :mentor_reviews]
    ).order(:scheduled_at).to_a
    connected = bookings.reject { |booking| booking.status == "cancelled" }
    assigned = User.where(id: MenteeProfile.where(assigned_mentor_id: current_user.id).select(:user_id)).merge(User.with_role('mentee')).includes(:profile, :mentee_profile).to_a
    grouped = connected.group_by(&:mentee_id)
    mentees = (connected.map(&:mentee) + assigned).uniq(&:id)
    completed = bookings.select { |booking| booking.status == "completed" }
    reviews = current_user.mentor_reviews
    render json: {
      mentor: MentorSerializer.new(current_user).as_json,
      stats: {
        mentees: mentees.size,
        sessions: completed.size,
        hours: (completed.sum(&:duration) / 60.0).round(1),
        active_goals: current_user.mentor_goals.kept.where(completed: false).count,
        completed_goals: current_user.mentor_goals.kept.where(completed: true).count,
        rating: reviews.average(:rating)&.round(1)&.to_f,
        review_count: reviews.size
      },
      mentees: mentees.map do |mentee|
        id = mentee.id
        sessions = grouped.fetch(id, [])
        finished = sessions.count { |session| session.status == "completed" }
        {
          id: id, name: mentee.full_name, avatar: mentee.profile&.profile_picture,
          school: mentee.mentee_profile&.school, grade: mentee.mentee_profile&.grade,
          completed_sessions: finished, total_sessions: sessions.size,
          progress: sessions.empty? ? 0 : (finished * 100.0 / sessions.size).round
        }
      end,
      sessions: bookings.map { |booking| BookingSerializer.new(booking).as_json },
      programmes: current_user.services.active.order(:title).map { |service| ServiceSerializer.new(service).as_json },
      goals: current_user.mentor_goals.kept.order(:created_at).as_json(only: %i[id title completed]),
      resources: current_user.mentorship_resources.order(created_at: :desc).as_json(only: %i[id title url])
    }
  end

  def create_goal
    goal = current_user.mentor_goals.create!(params.require(:goal).permit(:title))
    render json: goal.as_json(only: %i[id title completed]), status: :created
  end

  def update_goal
    goal = current_user.mentor_goals.kept.find(params[:id])
    goal.update!(params.require(:goal).permit(:completed))
    render json: goal.as_json(only: %i[id title completed])
  end

  def create_resource
    resource = current_user.mentorship_resources.create!(params.require(:resource).permit(:title, :url))
    render json: resource.as_json(only: %i[id title url]), status: :created
  end

  def destroy_resource
    current_user.mentorship_resources.find(params[:id]).destroy!
    head :no_content
  end
end
