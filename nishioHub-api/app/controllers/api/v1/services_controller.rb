class Api::V1::ServicesController < ApplicationController
  before_action :authenticate_user!, only: %i[create update destroy]
  before_action :require_mentor!, only: %i[create update destroy]
  before_action :set_service, only: %i[show update destroy]

  def index
    scope = Service.active.includes(:category, :reviews, mentor: [:profile, { mentor_profile: :skills }, :services, :mentor_reviews])

    if params[:q].present?
      scope = scope.where("services.title ILIKE :q OR services.description ILIKE :q", q: "%#{params[:q]}%")
    end
    scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
    scope = scope.where(mentor_id: params[:mentor_id]) if params[:mentor_id].present?
    scope = scope.where("price >= ?", params[:min_price]) if params[:min_price].present?
    scope = scope.where("price <= ?", params[:max_price]) if params[:max_price].present?

    scope = case params[:sort]
            when "price-low" then scope.order(price: :asc)
            when "price-high" then scope.order(price: :desc)
            when "rating"
              scope.order(Arel.sql("(SELECT AVG(reviews.rating) FROM reviews WHERE reviews.service_id = services.id) DESC NULLS LAST"))
            when "newest" then scope.order(created_at: :desc)
            else scope.order(created_at: :desc)
            end

    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [[params.fetch(:per_page, 50).to_i, 1].max, 100].min
    total = scope.count
    services = scope.offset((page - 1) * per_page).limit(per_page)

    render json: {
      services: services.map { |service| ServiceSerializer.new(service).as_json },
      meta: {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: (total.to_f / per_page).ceil
      }
    }, status: :ok
  end

  def show
    render json: ServiceSerializer.new(@service).as_json, status: :ok
  end

  def create
    service = current_user.services.new(service_params)

    if service.save
      render json: ServiceSerializer.new(service).as_json, status: :created
    else
      render_error(service.errors.full_messages, :unprocessable_entity)
    end
  end

  def update
    return render_error("You can only edit your own services", :forbidden) unless @service.mentor_id == current_user.id

    if @service.update(service_params)
      render json: ServiceSerializer.new(@service).as_json, status: :ok
    else
      render_error(@service.errors.full_messages, :unprocessable_entity)
    end
  end

  def destroy
    return render_error("You can only delete your own services", :forbidden) unless @service.mentor_id == current_user.id

    @service.update!(is_active: false)
    render json: { detail: "Service deleted" }, status: :ok
  end

  private

  def set_service
    @service = Service.includes(:category, :reviews, mentor: [:profile, { mentor_profile: :skills }, :services, :mentor_reviews]).find_by(id: params[:id])
    render_error("Service not found", :not_found) if @service.nil?
  end

  def service_params
    params.permit(:title, :description, :category_id, :price, :duration, :image_url, tags: [])
  end
end
