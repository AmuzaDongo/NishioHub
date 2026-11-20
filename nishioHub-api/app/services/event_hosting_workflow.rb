module EventHostingWorkflow
  FIELDS=%w[name email subject category message reviewed created_at event_details partnership_details program_details id reference status review_note reviewed_at lock_version requester_id event_id].freeze
  TYPES={'workshop'=>'workshop','webinar'=>'webinar','mentorship'=>'mentorship','career_talk'=>'talk','community_event'=>'networking'}.freeze

  def self.serialize(inquiry)
    event=inquiry.event
    inquiry.as_json(only:FIELDS).merge('reviewed_by'=>inquiry.reviewer&.full_name,'event'=>event&&event.deleted_at.nil? ? event.as_json(only:%i[id title status starts_at ends_at location format]) : nil)
  end

  def self.revision!(inquiry,value)
    raise Administration::Rejected.new('This request changed. Reload it before continuing.',:conflict) unless value.to_s.match?(/\A\d+\z/)&&value.to_i==inquiry.lock_version
  end

  def self.review!(actor,inquiry,data)
    Administration.transaction do
      actor.reload
      raise Administration::Rejected,'Account is inactive' unless actor.is_active?
      Administration.authorize!(actor,'system.manage')
      inquiry.lock!;revision!(inquiry,data['lock_version'])
      raise Administration::Rejected.new('Only pending event requests can be decided.',:conflict) unless inquiry.category=='event_hosting'&&inquiry.status=='pending'
      decision=data['decision'];note=data['note'].to_s.strip
      raise Administration::Rejected.new('Choose approve, reject, or request changes.',:unprocessable_entity) unless %w[approved rejected changes_requested].include?(decision)
      raise Administration::Rejected.new('Include feedback explaining the decision.',:unprocessable_entity) if decision!='approved'&&note.blank?
      raise Administration::Rejected.new('Feedback must be at most 2000 characters.',:unprocessable_entity) if note.length>2000
      if decision=='approved'
        AdminEventManagement.authorize!(actor)
        owner=inquiry.requester
        raise Administration::Rejected.new('This request needs an active mentor or school/organization account before approval.',:unprocessable_entity) unless owner&.is_active?&&%w[mentor school organization].any?{|role|owner.has_role?(role)}
        schedule=data['event']
        raise Administration::Rejected.new('Provide the event schedule before approving.',:unprocessable_entity) unless schedule.is_a?(Hash)
        attributes=schedule.slice('starts_at','ends_at','format','location','capacity')
        attributes.merge!('title'=>inquiry.subject,'description'=>inquiry.message,'status'=>'draft','event_type'=>TYPES.fetch(inquiry.event_details['event_type']))
        attributes['location']=inquiry.event_details['location'] if attributes['location'].blank?
        attributes['format']||=attributes['event_type']=='webinar' ? 'online' : 'on_site'
        event=AdminEventManagement.build(actor,attributes);event.organizer=owner;event.save!
        inquiry.event=event
        Administration.audit!(actor,'event.created_from_request',event,{request_id:inquiry.id,status:'draft'})
      end
      inquiry.update!(status:decision,review_note:note,reviewer:actor,reviewed_at:Time.current,reviewed:true)
      Administration.audit!(actor,'event_request.reviewed',inquiry,{status:decision,note:note,event_id:inquiry.event_id})
      owner=inquiry.requester
      if owner&.is_active?
        title={'approved'=>'Event Request Approved','rejected'=>'Event Request Rejected','changes_requested'=>'Changes Requested for Your Event'}.fetch(decision)
        message=decision=='approved' ? "#{inquiry.subject} was approved. A draft event has been created; staff will finalize it before publishing." : "#{inquiry.subject}: #{note}"
        Notification.deliver(user:owner,source_key:"event-request-#{inquiry.id}-decision-#{inquiry.lock_version}",title:title,message:message,category:'events',topic:'events',icon:'calendar',href:'/host-an-event#my-event-requests')
      end
      inquiry
    end
  end
end
