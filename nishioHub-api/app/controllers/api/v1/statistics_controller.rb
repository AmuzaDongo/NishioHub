class Api::V1::StatisticsController < ApplicationController
  before_action :require_admin!
  def show
    Administration.authorize!(current_user, 'dashboard.read')
    render json: { total_users: User.count }
  end
end
