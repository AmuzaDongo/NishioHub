class Api::V1::ProgramBannersController < ApplicationController
  rescue_from ActiveStorage::FileNotFoundError,with: :render_not_found
  def show
    response.headers['Cache-Control']='private, no-store'
    response.headers['X-Content-Type-Options']='nosniff'
    program=PlatformProgram.find(params[:id])
    staff=current_user&.platform_admin?&&current_user.management_permission?('dashboard.read')
    raise ActiveRecord::RecordNotFound unless program.status=='active'||staff
    raise ActiveRecord::RecordNotFound unless program.banner.attached?

    send_data program.banner.download,type:program.banner.content_type,filename:program.banner.filename.to_s,disposition:'inline'
  end
end
