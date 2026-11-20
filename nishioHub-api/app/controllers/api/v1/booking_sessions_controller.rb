class Api::V1::BookingSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :find_session!
  before_action { response.headers['Cache-Control'] = 'private, no-store' }
  def show
    own = @booking.session_feedbacks.find_by(user: current_user)
    old = @booking.review if @booking.mentee_id == current_user.id
    feedback = own || old
    now = Time.current
    render json: { title: @booking.session_title || @booking.service.title, objectives: @booking.objectives, tags: @booking.session_tags,
      assets: @booking.session_assets.active.with_attached_file.order(:kind, :created_at).map { |a| SessionDetailsQuery.asset(a).except(:views, :downloads) },
      feedback: feedback && { rating: feedback.rating, comment: feedback.comment },
      can_feedback: @booking.status == 'completed' && @booking.booking_participants.exists?(user: current_user) && (!@booking.feedback_opens_at || now >= @booking.feedback_opens_at) && (!@booking.feedback_closes_at || now <= @booking.feedback_closes_at) }
  end
  def asset_access
    asset = @booking.session_assets.active.find(params[:asset_id]); raise ActiveRecord::RecordNotFound if asset.url.blank?
    log_access(asset)
    render json: { url: asset.url }
  end
  def asset_file
    asset = @booking.session_assets.active.find(params[:asset_id]); raise ActiveRecord::RecordNotFound unless asset.file.attached?
    bytes = asset.file.download; log_access(asset)
    send_data bytes, filename: asset.file.filename.to_s, type: asset.file.content_type, disposition: 'attachment'
  end
  def feedback
    @booking.with_lock do
      now = Time.current
      unless @booking.status == 'completed' && @booking.booking_participants.exists?(user: current_user) && (!@booking.feedback_opens_at || now >= @booking.feedback_opens_at) && (!@booking.feedback_closes_at || now <= @booking.feedback_closes_at)
        return render_error('Feedback is available to registered learners after completion and during the feedback period', :forbidden)
      end
      source = params.require(:feedback)
      return render_error('Feedback must be an object', :unprocessable_entity) unless source.is_a?(ActionController::Parameters)
      item = @booking.session_feedbacks.find_or_initialize_by(user: current_user)
      item.update!(source.permit(:rating, :comment))
      Administration.audit!(current_user, 'session.feedback_saved', @booking, { rating: item.rating })
      render json: { rating: item.rating, comment: item.comment }
    end
  end
  private
  def find_session!
    @booking = Booking.where('mentor_id = :id OR mentee_id = :id OR bookings.id IN (SELECT booking_id FROM booking_participants WHERE user_id = :id)', id: current_user.id).find(params[:id])
  end
  def log_access(asset)
    return if current_user.platform_admin? || !@booking.booking_participants.exists?(user: current_user)
    SessionAssetAccess.create!(session_asset: asset, user: current_user, kind: asset.kind == 'recording' ? 'view' : 'download')
  end
end
