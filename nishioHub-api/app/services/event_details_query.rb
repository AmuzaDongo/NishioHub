class EventDetailsQuery
  def initialize(event) = @event=event
  def self.material(m)
    {id:m.id,title:m.title,description:m.description,url:m.url,lock_version:m.lock_version,file:m.file.attached? ? {filename:m.file.filename.to_s,type:m.file.content_type,size:m.file.byte_size} : nil}
  end
  def summary
    active=@event.event_registrations.where(status:'registered');registered=active.count
    attended=active.where(attendance_status:'present').count;absent=active.where(attendance_status:'absent').count
    ratings=@event.event_feedbacks.group(:rating).count;total=ratings.values.sum
    finish=Time.current
    first=[active.minimum(:created_at)||@event.created_at,finish-6.days].min
    elapsed=[(finish-first).to_i,1].max
    trend=(0..6).map do |i|
      at=first+elapsed*i/6.0
      {at:at.iso8601,registrations:active.where('created_at <= ?',at).count}
    end
    prior=Event.kept.where(status:'published',event_type:@event.event_type,platform_program_id:@event.platform_program_id).where('starts_at < ?',@event.starts_at).order(starts_at: :desc).first
    {registered:registered,attended:attended,no_show:absent,unrecorded:active.where(attendance_status:'unrecorded').count,cancelled:@event.event_registrations.where(status:'cancelled').count,
     attendance_rate:registered.zero? ? nil : (attended*100.0/registered).round(1),rating:total.zero? ? nil : (ratings.sum{|r,n|r*n}/total.to_f).round(1),feedback_count:total,ratings:(5).downto(1).map{|r|{rating:r,count:ratings.fetch(r,0)}},
     materials:@event.event_materials.active.count,speakers:@event.event_speakers.count,agenda_count:@event.event_agenda_items.count,
     agenda:@event.event_agenda_items.order(:starts_at,:id).limit(7).as_json(only:[:id,:title,:description,:starts_at,:ends_at,:lock_version]),trend:trend,
     growth:prior ? AdminReportingPeriod.change(registered,prior.event_registrations.where(status:'registered').count) : nil}
  end
end
