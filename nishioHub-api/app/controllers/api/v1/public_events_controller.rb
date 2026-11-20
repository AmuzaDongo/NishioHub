class Api::V1::PublicEventsController < ApplicationController
  before_action {response.headers['Cache-Control']='private, no-store'}
  def index
    query=PublicEventQuery.new(params);events=query.rows
    counts=EventRegistration.where(event_id:events.map(&:id),status:'registered').group(:event_id).count
    registrations=current_user ? current_user.event_registrations.where(event_id:events.map(&:id)).index_by(&:event_id) : {}
    render json:{items:events.map{|event|serialize(event,counts[event.id]||0,registrations[event.id])},meta:query.meta,facets:query.facets,
      enabled:SystemSetting.config['public_events_enabled'],registration_enabled:SystemSetting.config['event_registration_enabled'],timezone:SystemSetting.config['timezone'],
      can_create:!!(current_user&.platform_admin?&&current_user.management_permission?('dashboard.read')&&current_user.management_permission?('dashboard.manage'))}
  end
  def show
    event=PublicEventQuery.new.visible.includes(:organizer).with_attached_banner.find(params[:id])
    registration=current_user&.event_registrations&.find_by(event:event)
    registered=registration&.status=='registered'
    related=PublicEventQuery.new.visible.where.not(id:event.id).where('starts_at > ?',Time.current)
      .order(Arel.sql(Event.sanitize_sql_array(['CASE WHEN event_type = ? THEN 0 ELSE 1 END',event.event_type])),:starts_at,:id).with_attached_banner.includes(:organizer).limit(2).to_a
    counts=EventRegistration.where(event_id:related.map(&:id),status:'registered').group(:event_id).count
    own=current_user ? current_user.event_registrations.where(event_id:related.map(&:id)).index_by(&:event_id) : {}
    render json:serialize(event,event.event_registrations.where(status:'registered').count,registration).merge(
      timezone:SystemSetting.config['timezone'],objectives:event.public_details.fetch('objectives',[]),faqs:event.public_details.fetch('faqs',[]),
      agenda:event.event_agenda_items.order(:starts_at,:id).as_json(only:%i[id title description starts_at ends_at]),
      speakers:event.event_speakers.order(:id).as_json(only:%i[id name title bio avatar_url role]),
      resources_locked:!registered,materials_count:event.event_materials.active.count,
      materials:registered ? event.event_materials.active.with_attached_file.map{|material|EventDetailsQuery.material(material).except(:lock_version)} : [],
      related_events:related.map{|item|serialize(item,counts.fetch(item.id,0),own[item.id])})
  end
  def calendar
    event=PublicEventQuery.new.visible.find(params[:id])
    registration=current_user&.event_registrations&.find_by(event:event,status:'registered')
    send_data EventCalendarDocument.new(registration,event:event).render,type:'text/calendar; charset=utf-8',filename:"nishiohub-event-#{event.id}.ics",disposition:'attachment'
  end
  private
  def serialize(event,count,registration)
    registered=!!(registration&.status=='registered');places=event.capacity&&[event.capacity-count,0].max
    {id:event.id,title:event.title,description:event.description,type:PublicEventQuery::TYPES.find{|_,v|v[:values].include?(event.event_type)}&.first||'community',event_type:event.event_type,
      starts_at:event.starts_at.iso8601,ends_at:event.ends_at.iso8601,format:event.format,location:event.location,display_status:event.display_status,
      image:event.banner.attached? ? rails_storage_proxy_path(event.banner.blob,only_path:true) : event.image_path,
      target_audiences:event.target_audiences,featured:event.public_featured,available_places:places,capacity:event.capacity,
      can_register:SystemSetting.config['event_registration_enabled']&&event.ends_at>Time.current&&(registered||places.nil?||places>0),registered:registered,
      can_cancel:!!(registered&&registration.attended_at.nil?&&event.ends_at>Time.current),
      reminder_minutes:registered ? registration.reminder_minutes : nil,
      meeting_url:registered&&event.ends_at>Time.current ? event.meeting_url : nil,
      recording_url:event.ends_at<=Time.current ? event.public_recording_url.presence : nil,organizer:event.organizer.full_name}
  end
end
