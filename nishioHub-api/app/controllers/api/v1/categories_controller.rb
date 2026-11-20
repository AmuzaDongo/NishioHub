class Api::V1::CategoriesController < ApplicationController
  before_action :authenticate_user!, only: %i[create update destroy upload_image destroy_image]
  before_action :require_admin!, only: %i[create update destroy upload_image destroy_image]
  before_action :set_category, only: %i[show update destroy upload_image destroy_image]

  def index
    scope = Category.includes(:services, image_attachment: :blob)

    scope = scope.where(is_active: true) unless include_inactive?

    if params[:parent_id].present?
      scope = if params[:parent_id] == "null"
                scope.where(parent_id: nil)
              else
                scope.where(parent_id: params[:parent_id])
              end
    end

    if params[:q].present?
      scope = scope.where(
        "categories.name ILIKE :q OR categories.description ILIKE :q",
        q: "%#{params[:q]}%"
      )
    end

    scope = case params[:sort]
            when "name" then scope.order(:name)
            when "newest" then scope.order(created_at: :desc)
            else scope.ordered
            end

    skip = [params.fetch(:skip, 0).to_i, 0].max
    limit = [[params.fetch(:limit, 100).to_i, 1].max, 100].min
    categories = scope.offset(skip).limit(limit)

    render json: categories.map { |category| CategorySerializer.new(category).as_json }, status: :ok
  end

  def show
    return render_error("Category not found", :not_found) if !@category.is_active && !admin?

    render json: CategorySerializer.new(@category).as_json, status: :ok
  end

  def show_by_slug
    category = Category.includes(:services, image_attachment: :blob).find_by(slug: params[:slug])
    return render_error("Category not found", :not_found) if category.nil?
    return render_error("Category not found", :not_found) if !category.is_active && !admin?

    render json: CategorySerializer.new(category).as_json, status: :ok
  end

  def create
    category = Category.new(category_params)

    if category.save
      render json: CategorySerializer.new(category).as_json, status: :created
    else
      render_error(category.errors.full_messages, :unprocessable_entity)
    end
  end

  def update
    if @category.update(category_params)
      render json: CategorySerializer.new(@category).as_json, status: :ok
    else
      render_error(@category.errors.full_messages, :unprocessable_entity)
    end
  end

  def destroy
    if @category.services.exists?
      count = @category.services.count
      return render_error("Category is in use by #{count} service(s)", :unprocessable_entity)
    end

    @category.image.purge if @category.image.attached?
    @category.destroy!
    render json: { detail: "Category deleted" }, status: :ok
  end

  def upload_image
    file = params[:image]

    return render_error("Image is required", :unprocessable_entity) if file.blank?

    unless file.respond_to?(:content_type) && Category::IMAGE_CONTENT_TYPES.include?(file.content_type)
      return render_error("Image must be a PNG, JPEG, or WebP image", :unprocessable_entity)
    end

    if file.size > Category::IMAGE_MAX_SIZE
      return render_error("Image must be smaller than 5 MB", :unprocessable_entity)
    end

    @category.image.purge if @category.image.attached?
    @category.image.attach(file)

    render json: CategorySerializer.new(@category.reload).as_json, status: :ok
  end

  def destroy_image
    @category.image.purge if @category.image.attached?
    head :no_content
  end

  private

  def set_category
    @category = Category.includes(:services, image_attachment: :blob).find_by(id: params[:id]) ||
                Category.includes(:services, image_attachment: :blob).find_by(slug: params[:id])
    return if @category

    render_error("Category not found", :not_found)
  end

  def category_params
    source = params[:category].present? ? params.require(:category) : params
    source.permit(
      :name, :slug, :description, :position, :is_active, :parent_id, :image_alt,
      topics: []
    )
  end

  def include_inactive?
    params[:include_inactive] == "true" && admin?
  end

  def admin?
    current_user&.platform_admin?
  end
end
