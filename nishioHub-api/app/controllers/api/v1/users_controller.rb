class Api::V1::UsersController < ApplicationController
  before_action :authenticate_user!, only: %i[index me]

  def index
    render json: [UserWithProfileSerializer.new(current_user).as_json], status: :ok
  end

  def me
    render json: UserSerializer.new(current_user).as_json, status: :ok
  end

  def verify_email
    email = EmailToken.decode(params[:token].to_s)
    return render_error("Invalid or expired token", :bad_request) if email.blank?

    user = User.find_by(email: email)
    return render_error("User not found", :not_found) if user.nil?

    user.update!(is_verified: true)
    render json: { detail: "Email verified. You can now sign in to NishioHub." }, status: :ok
  end
end
