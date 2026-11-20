class Api::V1::ReviewsController < ApplicationController
  def index
    scope = Review.includes(:service, :mentor, mentee: :profile).order(created_at: :desc)
    scope = scope.where(mentor_id: params[:mentor_id]) if params[:mentor_id].present?
    scope = scope.where(service_id: params[:service_id]) if params[:service_id].present?

    render json: { reviews: scope.map { |review| ReviewSerializer.new(review).as_json } }, status: :ok
  end
end
