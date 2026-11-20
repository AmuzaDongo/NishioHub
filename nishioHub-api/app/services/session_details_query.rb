class SessionDetailsQuery
  def initialize(booking) = @booking = booking
  def feedback
    rows = @booking.session_feedbacks.includes(:user).map { |r| { id: "feedback-#{r.id}", user_id: r.user_id, author: r.user.full_name, rating: r.rating, comment: r.comment, created_at: r.created_at.iso8601 } }
    old = @booking.review
    if old && rows.none? { |r| r[:user_id] == old.mentee_id }
      rows << { id: "review-#{old.id}", user_id: old.mentee_id, author: old.mentee.full_name, rating: old.rating, comment: old.comment, created_at: old.created_at.iso8601 }
    end
    rows.sort_by { |r| r[:created_at] }.reverse
  end
  def summary
    rows = feedback
    accesses = SessionAssetAccess.joins(:session_asset).where(session_assets: { booking_id: @booking.id })
    { rating: rows.empty? ? nil : (rows.sum { |r| r[:rating] } / rows.size.to_f).round(1), feedback_count: rows.size,
      highlights: rows.first(5), recording_views: accesses.where(kind: 'view').count,
      material_downloads: accesses.where(kind: 'download').count, engaged_learners: accesses.distinct.count(:user_id),
      materials: @booking.session_assets.active.where(kind: 'material').count, recordings: @booking.session_assets.active.where(kind: 'recording').count,
      recording_available_at: @booking.session_assets.active.where(kind: 'recording').minimum(:created_at)&.iso8601,
      absent: @booking.booking_participants.where(attended: false).count, unrecorded: @booking.booking_participants.where(attended: nil).count }
  end
  def metadata
    { objectives: @booking.objectives, tags: @booking.session_tags,
      registration_opens_at: @booking.registration_opens_at&.iso8601, registration_closes_at: @booking.registration_closes_at&.iso8601,
      feedback_opens_at: @booking.feedback_opens_at&.iso8601, feedback_closes_at: @booking.feedback_closes_at&.iso8601,
      cover: @booking.cover.attached? ? @booking.cover.url : @booking.service.image_url }
  end
  def self.asset(item)
    { id: item.id, kind: item.kind, title: item.title, description: item.description, url: item.url,
      file: item.file.attached? ? { filename: item.file.filename.to_s, type: item.file.content_type, size: item.file.byte_size } : nil,
      created_at: item.created_at.iso8601, lock_version: item.lock_version,
      views: item.session_asset_accesses.where(kind: 'view').count, downloads: item.session_asset_accesses.where(kind: 'download').count }
  end
end
