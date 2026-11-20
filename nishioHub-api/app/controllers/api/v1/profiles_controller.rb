class Api::V1::ProfilesController < ApplicationController
  before_action :set_profile, only: %i[show update destroy upload_image]

  def index
    skip, limit = pagination!
    return if performed?

    profiles = Profile.order(:id).offset(skip).limit(limit)
    render json: profiles.map { |profile| ProfileSerializer.new(profile).as_json }, status: :ok
  end

  def create
    profile = Profile.new(profile_params)

    if profile.save
      render json: ProfileSerializer.new(profile).as_json, status: :created
    else
      render_error(profile.errors.full_messages, :unprocessable_entity)
    end
  end

  def show
    render json: ProfileSerializer.new(@profile).as_json, status: :ok
  end

  def update
    if @profile.update(profile_params)
      render json: ProfileSerializer.new(@profile).as_json, status: :ok
    else
      render_error(@profile.errors.full_messages, :unprocessable_entity)
    end
  end

  def destroy
    @profile.destroy!
    render json: { detail: "Profile deleted" }, status: :ok
  end

  def upload_image
    file = params[:file]
    return render_error("File must be an image", :bad_request) if file.blank?

    unless file.respond_to?(:content_type) && file.content_type.to_s.start_with?("image/")
      return render_error("File must be an image", :bad_request)
    end

    directory = Rails.root.join("public/media/profiles")
    FileUtils.mkdir_p(directory)
    extension = File.extname(file.original_filename.to_s)
    filename = "#{SecureRandom.hex}#{extension}"
    File.open(directory.join(filename), "wb") { |handle| handle.write(file.read) }

    @profile.update!(profile_picture: "media/profiles/#{filename}")
    render json: ProfileSerializer.new(@profile).as_json, status: :ok
  end

  private

  def set_profile
    @profile = Profile.find_by(id: params[:id])
    return if @profile

    render_error("Profile not found", :not_found)
  end

  def profile_params
    source = params[:profile].present? ? params.require(:profile) : params
    source.permit(
      :phone_number, :gender, :birth_date, :address, :city, :country,
      :profile_picture, :bio, :user_id
    )
  end
end
