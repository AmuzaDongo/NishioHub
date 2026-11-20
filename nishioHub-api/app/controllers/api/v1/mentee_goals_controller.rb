class Api::V1::MenteeGoalsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_mentee!
  before_action :set_goal, only: %i[update destroy create_milestone update_milestone destroy_milestone]

  def index
    goals = current_user.mentee_goals.kept.includes(:goal_milestones).order(:created_at)
    events = GoalProgressEvent.joins(:mentee_goal).where(mentee_goals: { user_id: current_user.id, archived_at: nil })
      .includes(:mentee_goal).order(created_at: :desc, id: :desc).limit(100)
    render json: {
      name: current_user.full_name,
      avatar: current_user.profile&.profile_picture,
      vision: current_user.mentee_profile&.vision,
      goals: goals.map { |goal| goal_json(goal) },
      history: events.map do |event|
        { id: event.id, goal_id: event.mentee_goal_id, goal_title: event.mentee_goal.title,
          progress: event.progress, note: event.note, created_at: event.created_at.iso8601 }
      end
    }
  end

  def create
    goal = current_user.mentee_goals.create!(goal_params)
    render json: goal_json(goal), status: :created
  end

  def update
    @goal.update!(goal_params)
    render json: goal_json(@goal)
  end

  def destroy
    @goal.destroy!
    head :no_content
  end

  def update_vision
    profile = current_user.mentee_profile || current_user.build_mentee_profile
    profile.update!(params.require(:profile).permit(:vision))
    render json: { vision: profile.vision }
  end

  def create_milestone
    milestone = @goal.goal_milestones.create!(milestone_params)
    render json: milestone_json(milestone), status: :created
  end

  def update_milestone
    milestone = @goal.goal_milestones.find(params[:milestone_id])
    milestone.update!(milestone_params)
    render json: milestone_json(milestone)
  end

  def destroy_milestone
    @goal.goal_milestones.find(params[:milestone_id]).destroy!
    head :no_content
  end

  private

  def require_mentee!
    render_error("Mentee access required", :forbidden) unless current_user.has_role?('mentee')
  end

  def set_goal
    @goal = current_user.mentee_goals.kept.find(params[:id])
  end

  def goal_params
    params.require(:goal).permit(:title, :description, :progress, :target_date, :icon, :completed)
  end

  def milestone_params
    params.require(:milestone).permit(:title, :target_date, :completed)
  end

  def goal_json(goal)
    goal.as_json(only: %i[id title description progress target_date icon completed]).merge(
      "milestones" => goal.goal_milestones.sort_by { |milestone| [milestone.target_date || Date.new(9999), milestone.id] }
        .map { |milestone| milestone_json(milestone) }
    )
  end

  def milestone_json(milestone)
    milestone.as_json(only: %i[id title target_date completed mentee_goal_id])
  end
end
