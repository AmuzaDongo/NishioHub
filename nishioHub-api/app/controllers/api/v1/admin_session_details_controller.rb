require 'csv'
class Api::V1::AdminSessionDetailsController < Api::V1::AdminSessionsController
  def show
    booking = Booking.find(params[:id]); query = SessionDetailsQuery.new(booking)
    render json: serialize(booking).merge(query.metadata).merge(summary: query.summary,
      capabilities: { manage: current_user.management_permission?('dashboard.manage'), schedule: current_user.management_permission?('dashboard.manage') && SystemSetting.config['matching_enabled'] })
  end
  def update
    source = object(:details)
    %i[objectives tags].each do |key|
      raise Administration::Rejected.new("#{key} must be an array", :unprocessable_entity) if source.key?(key) && !source[key].is_a?(Array)
    end
    Administration.transaction do
      AdminSessionManagement.authorize!(current_user)
      booking = Booking.lock.find(params[:id]); AdminSessionManagement.revision!(booking, source[:updated_at])
      attrs = source.permit(:session_title, :session_description, objectives: [], tags: []).to_h
      attrs['session_tags'] = attrs.delete('tags') if attrs.key?('tags')
      attrs['objectives'] = [] if source[:clear_objectives] == 'true'
      attrs['session_tags'] = [] if source[:clear_tags] == 'true'
      %w[registration_opens_at registration_closes_at feedback_opens_at feedback_closes_at].each do |key|
        next unless source.key?(key)
        value = source[key]
        if value.present?
          parsed = Time.iso8601(value.to_s) rescue nil
          raise Administration::Rejected.new('Use valid dates and times with timezone offsets', :unprocessable_entity) unless parsed && value.to_s.match?(/(?:Z|[+-]\d{2}:\d{2})\z/)
          attrs[key] = parsed
        else
          attrs[key] = nil
        end
      end
      if source[:cover].present?
        file = source[:cover]; validate_upload!(file, %w[image/jpeg image/png image/webp], 2.megabytes)
        booking.cover.attach(file)
      elsif source[:remove_cover] == true || source[:remove_cover] == 'true'
        booking.cover.detach
      end
      booking.update!(attrs); booking.touch
      Administration.audit!(current_user, 'session.details_updated', booking, { fields: attrs.keys, cover_changed: source[:cover].present? || [true, 'true'].include?(source[:remove_cover]) })
    end
    show
  end
  def section
    booking = Booking.find(params[:id]); q = params[:q].to_s.first(100); term = "%#{ActiveRecord::Base.sanitize_sql_like(q)}%"
    case params[:section]
    when 'materials', 'recordings', 'engagement'
      scope = booking.session_assets
      scope = scope.active.where(kind: params[:section] == 'materials' ? 'material' : 'recording') unless params[:section] == 'engagement'
      scope = scope.where('title ILIKE ?', term) if q.present?
      total = scope.count
      rows = scope.with_attached_file.order(created_at: :desc).offset((page - 1) * 20).limit(20).map { |a| SessionDetailsQuery.asset(a).merge(active: a.is_active) }
    when 'feedback'
      values = SessionDetailsQuery.new(booking).feedback
      values = values.select { |v| "#{v[:author]} #{v[:comment]}".downcase.include?(q.downcase) } if q.present?
      total = values.size; rows = values.slice((page - 1) * 20, 20) || []
    when 'notes'
      scope = booking.session_notes.includes(:author)
      scope = scope.where('body ILIKE ?', term) if q.present?
      total = scope.count
      rows = scope.order(created_at: :desc).offset((page - 1) * 20).limit(20).map { |n| { id: n.id, body: n.body, author: n.author_name, created_at: n.created_at.iso8601, updated_at: n.updated_at.iso8601, lock_version: n.lock_version } }
    when 'audit'
      scope = AdministrationAudit.where(target_type: 'Booking', target_id: booking.id)
      scope = scope.where('action ILIKE :q OR actor_name ILIKE :q', q: term) if q.present?
      total = scope.count
      rows = scope.order(created_at: :desc, id: :desc).offset((page - 1) * 20).limit(20).map { |a| { id: a.id, action: a.action, actor: a.actor_name, created_at: a.created_at.iso8601 } }
    else
      return render_error('Choose materials, recordings, engagement, feedback, notes or audit', :unprocessable_entity)
    end
    render json: { items: rows, meta: meta(total, 20) }
  end
  def add_asset
    source = object(:asset); kind = source[:kind]
    Administration.transaction do
      AdminSessionManagement.authorize!(current_user); booking = Booking.lock.find(params[:id])
      raise Administration::Rejected.new('Keep at most 100 active assets per session', :unprocessable_entity) if booking.session_assets.active.count >= 100
      asset = booking.session_assets.new(source.permit(:kind, :title, :description, :url))
      if source[:file].present?
        validate_upload!(source[:file], kind == 'recording' ? SessionAsset::RECORDING_TYPES : SessionAsset::MATERIAL_TYPES, [SystemSetting.config['max_upload_mb'].to_i, kind == 'recording' ? 100 : 10].min.megabytes)
        asset.file.attach(source[:file])
      end
      asset.save!; booking.touch
      Administration.audit!(current_user, 'session.asset_added', booking, { asset_id: asset.id, kind: asset.kind, title: asset.title })
      render json: SessionDetailsQuery.asset(asset), status: :created
    end
  end
  def remove_asset
    Administration.transaction do
      AdminSessionManagement.authorize!(current_user); booking = Booking.lock.find(params[:id])
      asset = booking.session_assets.active.lock.find(params[:asset_id]); item_revision!(asset, params[:lock_version])
      asset.update!(is_active: false); booking.touch
      Administration.audit!(current_user, 'session.asset_removed', booking, { asset_id: asset.id, title: asset.title })
    end
    head :no_content
  end
  def asset_access
    booking = Booking.find(params[:id]); asset = booking.session_assets.active.find(params[:asset_id])
    raise ActiveRecord::RecordNotFound if asset.url.blank?
    render json: { url: asset.url }
  end
  def asset_file
    asset = Booking.find(params[:id]).session_assets.active.find(params[:asset_id])
    raise ActiveRecord::RecordNotFound unless asset.file.attached?
    send_data asset.file.download, filename: asset.file.filename.to_s, type: asset.file.content_type, disposition: 'attachment'
  end
  def materials_archive
    assets = Booking.find(params[:id]).session_assets.active.where(kind: 'material').with_attached_file.to_a
    raise Administration::Rejected.new('No materials have been added yet', :unprocessable_entity) if assets.empty?
    send_data SessionMaterialArchive.build(assets), filename: "session-#{params[:id]}-materials.tar.gz", type: 'application/gzip', disposition: 'attachment'
  end
  def export_attendees
    booking = Booking.find(params[:id])
    csv = CSV.generate do |out|
      out << %w[user_id name registered_at attendance recorded_at]
      booking.booking_participants.includes(:user).order(:id).each do |p|
        out << [p.user_id, p.user.full_name, p.created_at.iso8601, p.attended.nil? ? 'unrecorded' : p.attended ? 'present' : 'absent', p.recorded_at&.iso8601].map { |v| AdminUserQuery.csv_cell(v) }
      end
    end
    Administration.audit!(current_user, 'session.attendees_exported', booking, { count: booking.booking_participants.count })
    send_data csv, type: 'text/csv; charset=utf-8', filename: "session-#{booking.id}-attendees.csv", disposition: 'attachment'
  end
  def save_note
    source = object(:note)
    Administration.transaction do
      AdminSessionManagement.authorize!(current_user); booking = Booking.lock.find(params[:id])
      note = params[:note_id] ? booking.session_notes.lock.find(params[:note_id]) : booking.session_notes.new(author: current_user, author_name: current_user.full_name)
      item_revision!(note, source[:lock_version]) if note.persisted?
      note.update!(body: source[:body]); booking.touch
      Administration.audit!(current_user, 'session.note_saved', booking, { note_id: note.id })
    end
    head :no_content
  end
  def remove_note
    Administration.transaction do
      AdminSessionManagement.authorize!(current_user); booking = Booking.lock.find(params[:id]); note = booking.session_notes.lock.find(params[:note_id])
      item_revision!(note, params[:lock_version]); note.destroy!; booking.touch
      Administration.audit!(current_user, 'session.note_deleted', booking, { note_id: params[:note_id] })
    end
    head :no_content
  end
  def follow_up
    source = object(:follow_up); text = source[:message]; key = source[:request_key]
    unless text.is_a?(String) && text.strip.length.between?(1, 2000) && key.is_a?(String) && key.match?(/\A[a-zA-Z0-9-]{16,64}\z/)
      return render_error('Write a message of 1–2000 characters and include a valid request key', :unprocessable_entity)
    end
    result = nil
    Administration.transaction do
      AdminSessionManagement.authorize!(current_user); booking = Booking.lock.find(params[:id])
      prior = AdministrationAudit.where(target_type: 'Booking', target_id: booking.id, action: 'session.follow_up_sent').where("changeset ->> 'request_key' = ?", key).first
      if prior
        result = prior.changeset.slice('delivered', 'skipped')
      else
        raise Administration::Rejected.new('Platform notifications are disabled', :unprocessable_entity) unless SystemSetting.config['notifications_enabled']
        recipients = User.where(id: booking.booking_participants.select(:user_id), is_active: true)
        delivered = 0
        recipients.each do |u|
          note = Notification.deliver(user: u, source_key: "session-#{booking.id}-followup-#{key}", title: "Session Follow-up: #{booking.session_title || booking.service.title}", message: text.strip, category: 'mentorship', topic: 'mentorship', icon: 'users', href: '/bookings')
          delivered += 1 if note
        end
        result = { delivered: delivered, skipped: booking.booking_participants.count - delivered }
        Administration.audit!(current_user, 'session.follow_up_sent', booking, result.merge(request_key: key))
      end
    end
    render json: result
  end
  def duplicate
    result = nil
    Administration.transaction do
      AdminSessionManagement.authorize!(current_user); source = Booking.lock.find(params[:id])
      result = AdminSessionManagement.save!(current_user, data)
      result.update!(objectives: source.objectives, session_tags: source.session_tags)
      if source.cover.attached?
        result.cover.attach(source.cover.blob)
      elsif source.service.image_url.present?
        result.service.update!(image_url: source.service.image_url)
      end
      source.session_assets.active.where(kind: 'material').with_attached_file.each do |old|
        item = result.session_assets.new(kind: 'material', title: old.title, description: old.description, url: old.url)
        item.file.attach(old.file.blob) if old.file.attached?
        item.save!
      end
      Administration.audit!(current_user, 'session.duplicated', result, { source_id: source.id })
    end
    render json: serialize(result.reload), status: :created
  end
  private
  def item_revision!(item, value)
    raise Administration::Rejected.new('This item changed. Reload details before saving.', :conflict) unless value.to_s.match?(/\A\d+\z/) && value.to_i == item.lock_version
  end
  def validate_upload!(file, types, limit)
    unless file.is_a?(ActionDispatch::Http::UploadedFile) && file.size <= limit && types.include?(Marcel::MimeType.for(file.tempfile, name: file.original_filename))
      raise Administration::Rejected.new('Choose a supported file within the upload limit', :unprocessable_entity)
    end
  end
end
