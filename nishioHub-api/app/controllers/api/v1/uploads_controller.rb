class Api::V1::UploadsController < ApplicationController
  def create
    file = params[:file]
    return render_error("File is required", :unprocessable_entity) if file.blank?

    filename = File.basename(file.original_filename.to_s)
    return render_error("Invalid filename", :bad_request) if filename.blank?

    directory = Rails.root.join("public/uploads")
    FileUtils.mkdir_p(directory)
    File.open(directory.join(filename), "wb") { |handle| handle.write(file.read) }

    render json: { filename: filename }, status: :ok
  end
end
