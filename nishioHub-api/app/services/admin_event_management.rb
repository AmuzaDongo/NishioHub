module AdminEventManagement
  def self.authorize!(actor)
    actor.reload; Administration.authorize!(actor,'dashboard.read'); Administration.authorize!(actor,'dashboard.manage')
  end
  def self.revision!(record,value)
    raise Administration::Rejected.new('This event or registration changed. Reload it before saving.',:conflict) unless value.to_s.match?(/\A\d+\z/) && value.to_i==record.lock_version
  end
  def self.attributes(data)
    attrs=data.slice('title','description','event_type','status','format','location','meeting_url','capacity','platform_program_id','target_audiences','public_featured','public_recording_url')
    if data.key?('public_details')
      begin
        attrs['public_details']=data['public_details'].is_a?(String) ? JSON.parse(data['public_details']) : data['public_details']
      rescue JSON::ParserError
        raise Administration::Rejected.new('Learning outcomes and FAQs must be valid.',:unprocessable_entity)
      end
    end
    attrs['capacity']=nil if attrs.key?('capacity')&&attrs['capacity'].blank?
    attrs['platform_program_id']=nil if attrs.key?('platform_program_id')&&attrs['platform_program_id'].blank?
    attrs['target_audiences']=attrs['target_audiences'].reject(&:blank?) if attrs['target_audiences'].is_a?(Array)
    %w[starts_at ends_at].each do |key|
      value=data[key];time=Time.iso8601(value.to_s) rescue nil
      valid_date=Date.iso8601(value.to_s.first(10)) rescue nil
      raise Administration::Rejected.new('Choose valid start/end times with explicit timezone offsets',:unprocessable_entity) unless time && valid_date && value.to_s.match?(/(?:Z|[+-]\d{2}:\d{2})\z/)
      attrs[key]=time
    end
    attrs['category']=Event::CATEGORY_MAP.fetch(attrs['event_type'],'talk')
    attrs
  end
  def self.build(actor,data)
    attrs=attributes(data);attrs['status'] ||= 'draft'
    raise Administration::Rejected.new('Choose a future start time',:unprocessable_entity) unless attrs['starts_at']>Time.current
    PlatformProgram.active.find(AdminMenteeQuery.positive_id!(attrs['platform_program_id'])) if attrs['platform_program_id'].present?
    event=Event.new(attrs.merge(organizer:actor));event.type_explicit=true;event
  end
  def self.save!(actor,data,event:nil)
    Administration.transaction do
      authorize!(actor);creating=event.nil?
      if creating
        event=build(actor,data)
      else
        event.lock!;raise ActiveRecord::RecordNotFound if event.deleted_at;revision!(event,data['lock_version'])
        raise Administration::Rejected.new('Cancelled events cannot be edited. Create a new event instead.',:unprocessable_entity) if event.status=='cancelled'
        attrs=attributes(data)
        raise Administration::Rejected.new('Choose a future start time',:unprocessable_entity) if event.starts_at>Time.current && attrs['starts_at']<=Time.current
        raise Administration::Rejected.new('Use the publication action to change event status',:unprocessable_entity) if attrs.key?('status') && attrs['status'] != event.status
        if attrs['platform_program_id'].present?&&attrs['platform_program_id'].to_s!=event.platform_program_id.to_s
          PlatformProgram.active.find(AdminMenteeQuery.positive_id!(attrs['platform_program_id']))
        end
        event.type_explicit=true;event.assign_attributes(attrs)
      end
      if data['banner'].present?
        file=data['banner']
        unless file.is_a?(ActionDispatch::Http::UploadedFile)&&file.size<=2.megabytes&&%w[image/jpeg image/png image/webp].include?(Marcel::MimeType.for(file.tempfile))
          raise Administration::Rejected.new('Upload a JPEG, PNG or WebP image up to 2 MB',:unprocessable_entity)
        end
        event.banner=file
      elsif [true,'true'].include?(data['remove_banner']) then event.banner=nil
      end
      agenda=[]
      if event.persisted? && (event.will_save_change_to_starts_at? || event.will_save_change_to_ends_at?)
        # Preserve subsecond precision when shifting an agenda. Float rounding
        # can otherwise place its first item just outside the event schedule.
        shift=event.starts_at.to_r-event.starts_at_in_database.to_r
        agenda=event.event_agenda_items.lock.to_a
        agenda.each do |item|
          item.event=event;item.starts_at+=shift;item.ends_at+=shift;item.validate!
        end
      end
      event.save!;agenda.each(&:save!);event.touch
      Administration.audit!(actor,creating ? 'event.created' : 'event.updated',event,{title:event.title,status:event.status,event_type:event.event_type})
      event
    end
  end
  def self.change_status!(actor,event,value,version)
    Administration.transaction do
      authorize!(actor);event.lock!;raise ActiveRecord::RecordNotFound if event.deleted_at;revision!(event,version)
      allowed=event.status=='draft' ? %w[published cancelled] : event.status=='published' ? %w[draft cancelled end] : []
      raise Administration::Rejected.new('This event cannot move to that status',:unprocessable_entity) unless allowed.include?(value)
      if value=='end'
        raise Administration::Rejected.new('Only an ongoing published event can be ended',:unprocessable_entity) unless event.starts_at<Time.current&&event.ends_at>Time.current
        event.schedule_override=true;event.update!(ends_at:Time.current)
      else
        raise Administration::Rejected.new('Only future events can change publication or cancellation status',:unprocessable_entity) if event.ends_at<=Time.current || value=='published'&&event.starts_at<=Time.current
        event.update!(status:value)
      end
      Administration.audit!(actor,'event.status_updated',event,{status:value})
      event
    end
  end
  def self.add_attendees!(actor,event,raw)
    Administration.transaction do
      authorize!(actor);event.lock!
      raise Administration::Rejected.new('New event registrations are paused',:forbidden) unless SystemSetting.config['event_registration_enabled']
      raise Administration::Rejected.new('Register attendees for a published event that has not ended',:unprocessable_entity) unless event.status=='published'&&event.ends_at>Time.current
      ids=AdminProgramManagement.ids!(raw)
      raise Administration::Rejected.new('Choose active user accounts',:unprocessable_entity) unless User.where(id:ids,is_active:true).count==ids.size
      existing=event.event_registrations.where(status:'registered').pluck(:user_id)
      raise Administration::Rejected.new('Event capacity would be exceeded',:unprocessable_entity) if event.capacity&&(existing|ids).size>event.capacity
      ids.each do |id|
        r=event.event_registrations.find_or_initialize_by(user_id:id)
        next if r.persisted?&&r.status=='registered'
        r.attendance_explicit=true;r.update!(status:'registered',attended_at:nil,attendance_status:'unrecorded')
      end
      event.touch;Administration.audit!(actor,'event.attendees_added',event,{user_ids:ids})
    end
  end
  def self.registration!(actor,event,id,data)
    Administration.transaction do
      authorize!(actor);event.lock!;raise ActiveRecord::RecordNotFound if event.deleted_at;r=event.event_registrations.lock.find(id);revision!(r,data['lock_version'])
      if data['cancel']==true
        raise Administration::Rejected.new('Attended registrations cannot be cancelled',:unprocessable_entity) if r.attended_at
        r.update!(status:'cancelled')
      else
        value=data['attendance_status']
        unless %w[present absent unrecorded].include?(value)&&event.status=='published'&&event.starts_at<=Time.current&&r.status=='registered'
          raise Administration::Rejected.new('Record attendance once a published event starts',:unprocessable_entity)
        end
        r.attendance_explicit=true;r.update!(attendance_status:value,attended_at:value=='present' ? (r.attended_at||Time.current) : nil)
      end
      event.touch;Administration.audit!(actor,'event.registration_updated',event,{registration_id:r.id,status:r.status,attendance:r.attendance_status})
    end
  end
end
