class Api::V1::ActivitiesController < ApplicationController
  before_action :authenticate_user!

  def index
    return render_error("Mentee access required", :forbidden) unless current_user.has_role?('mentee')

    entries = MenteeActivityFeed.new(current_user).entries
    render json: {
      name: current_user.full_name,
      avatar: current_user.avatar_url,
      activities: entries,
      stats: {
        total: entries.size,
        completed: entries.count { |entry| entry[:status] == "completed" },
        in_progress: entries.count { |entry| entry[:status] == "in_progress" },
        upcoming: entries.count { |entry| entry[:status] == "upcoming" }
      }
    }
  end
end
