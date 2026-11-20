class Api::V1::EventContentController < ApplicationController
  before_action :authenticate_user!
  before_action :access!
  def show
    render json:{agenda:@event.event_agenda_items.order(:starts_at,:id).as_json(only:[:id,:title,:description,:starts_at,:ends_at]),speakers:@event.event_speakers.order(:name).as_json(only:[:id,:name,:title,:bio,:avatar_url,:role]),materials:@event.event_materials.active.with_attached_file.map{|m|EventDetailsQuery.material(m)},feedback:@event.event_feedbacks.find_by(user:current_user)&.as_json(only:[:rating,:comment,:lock_version]),can_feedback:@registration&.attended_at.present?&&@event.ends_at<=Time.current&&@event.status=='published'}
  end
  def file
    m=@event.event_materials.active.find(params[:item_id]);raise ActiveRecord::RecordNotFound unless m.file.attached?
    send_data m.file.download,type:m.file.content_type,filename:m.file.filename.to_s,disposition:'attachment'
  end
  def feedback
    source=params.require(:feedback)
    raise Administration::Rejected.new('Feedback must be an object',:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    @event.with_lock do
      @registration.reload
      raise Administration::Rejected.new('Feedback is available to confirmed attendees after a published event ends',:forbidden) unless @event.deleted_at.nil?&&@event.status=='published'&&@event.ends_at<=Time.current&&@registration.status=='registered'&&@registration.attended_at.present?
      row=@event.event_feedbacks.find_or_initialize_by(user:current_user)
      AdminEventManagement.revision!(row,source[:lock_version]) if row.persisted?
      row.update!(source.permit(:rating,:comment));render json:row.as_json(only:[:rating,:comment,:lock_version])
    end
  end
  private
  def access!
    @event=Event.kept.find(params[:id]);@registration=@event.event_registrations.find_by(user:current_user,status:'registered')
    raise ActiveRecord::RecordNotFound unless @event.status=='published'&&@registration
  end
end
