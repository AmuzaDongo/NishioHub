require 'csv'
class Api::V1::AdminEventDetailsController < Api::V1::AdminEventsController
  def show
    render json:serialize(event).merge(summary:EventDetailsQuery.new(event).summary,upload_limit_mb:[SystemSetting.config['max_upload_mb'],10].min,capabilities:{manage:current_user.management_permission?('dashboard.manage')})
  end
  def section
    term="%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(100))}%"
    case params[:section]
    when 'agenda'
      scope=event.event_agenda_items.where('title ILIKE ?',term).order(:starts_at,:id)
    when 'speakers'
      scope=event.event_speakers.where('name ILIKE :q OR title ILIKE :q',q:term).order(:name,:id)
    when 'materials'
      scope=event.event_materials.active.with_attached_file.where('title ILIKE ?',term).order(:created_at,:id)
    when 'feedback'
      scope=event.event_feedbacks.includes(:user).joins(:user).where('event_feedbacks.comment ILIKE :q OR users.full_name ILIKE :q',q:term).order(created_at: :desc,id: :desc)
    else return render_error('Choose agenda, speakers, materials or feedback',:unprocessable_entity)
    end
    total=scope.count;items=scope.offset((page-1)*20).limit(20).map do |r|
      case r
      when EventMaterial then EventDetailsQuery.material(r)
      when EventFeedback then {id:r.id,author:r.user.full_name,rating:r.rating,comment:r.comment,created_at:r.created_at.iso8601}
      else r.as_json(except:[:event_id])
      end
    end
    render json:{items:items,meta:{page:page,per_page:20,total:total,total_pages:(total/20.0).ceil}}
  end
  def save_item
    source=object(:item)
    Administration.transaction do
      AdminEventManagement.authorize!(current_user);event.lock!
      raise ActiveRecord::RecordNotFound if event.deleted_at
      raise Administration::Rejected.new('Cancelled events cannot be edited',:unprocessable_entity) if event.status=='cancelled'
      scope,fields,limit=item_scope
      item=params[:item_id] ? scope.lock.find(params[:item_id]) : scope.new
      AdminEventManagement.revision!(item,source[:lock_version]) if item.persisted?
      raise Administration::Rejected.new("Keep at most #{limit} items in this section",:unprocessable_entity) if item.new_record?&&scope.count>=limit
      attrs=source.permit(*fields).to_h
      if item.is_a?(EventAgendaItem)
        %w[starts_at ends_at].each do |key|
          value=attrs[key];parsed=Time.iso8601(value.to_s) rescue nil
          valid=Date.iso8601(value.to_s.first(10)) rescue nil
          raise Administration::Rejected.new('Use valid agenda times with timezone offsets',:unprocessable_entity) unless parsed&&valid&&value.to_s.match?(/(?:Z|[+-]\d{2}:\d{2})\z/)
          attrs[key]=parsed
        end
      end
      item.assign_attributes(attrs)
      item.file=nil if item.is_a?(EventMaterial) && attrs['url'].present? && source[:file].blank?
      if item.is_a?(EventMaterial)&&source[:file].present?
        f=source[:file]
        raise Administration::Rejected.new('Upload a supported file within the platform limit',:unprocessable_entity) unless f.is_a?(ActionDispatch::Http::UploadedFile)&&f.size<=[SystemSetting.config['max_upload_mb'],10].min.megabytes&&EventMaterial::TYPES.include?(Marcel::MimeType.for(f.tempfile,name:f.original_filename))
        item.file=f
      end
      item.save!;event.touch;Administration.audit!(current_user,'event.content_saved',event,{section:params[:section],item_id:item.id,title:item.try(:title)||item.try(:name)})
    end
    head :no_content
  end
  def remove_item
    Administration.transaction do
      AdminEventManagement.authorize!(current_user);event.lock!;raise ActiveRecord::RecordNotFound if event.deleted_at;raise Administration::Rejected.new('Cancelled events cannot be edited',:unprocessable_entity) if event.status=='cancelled';scope,=item_scope;item=scope.lock.find(params[:item_id]);AdminEventManagement.revision!(item,params[:lock_version])
      item.is_a?(EventMaterial) ? item.update!(is_active:false) : item.destroy!
      event.touch;Administration.audit!(current_user,'event.content_removed',event,{section:params[:section],item_id:params[:item_id]})
    end
    head :no_content
  end
  def file
    m=event.event_materials.active.find(params[:item_id]);raise ActiveRecord::RecordNotFound unless m.file.attached?
    send_data m.file.download,type:m.file.content_type,filename:m.file.filename.to_s,disposition:'attachment'
  end
  def announcement
    source=object(:announcement);body=source[:message];key=source[:request_key]
    unless body.is_a?(String)&&body.strip.length.between?(1,2000)&&key.is_a?(String)&&key.match?(/\A[a-zA-Z0-9-]{16,64}\z/)
      return render_error('Write 1–2000 characters and include a valid request key',:unprocessable_entity)
    end
    result=nil
    Administration.transaction do
      AdminEventManagement.authorize!(current_user);event.lock!
      raise ActiveRecord::RecordNotFound if event.deleted_at
      digest=Digest::SHA256.hexdigest(body.strip)
      prior=AdministrationAudit.where(target_type:'Event',target_id:event.id,action:'event.announcement_sent').where("changeset ->> 'request_key' = ?",key).first
      if prior
        raise Administration::Rejected.new('This request key was used for a different announcement',:conflict) unless prior.changeset['digest']==digest
        result=prior.changeset.slice('delivered','skipped')
      else
        raise Administration::Rejected.new('Platform notifications are disabled',:unprocessable_entity) unless SystemSetting.config['notifications_enabled']
        recipients=User.where(is_active:true,id:event.event_registrations.where(status:'registered').select(:user_id));delivered=0
        recipients.find_each do |u|
          delivered+=1 if Notification.deliver(user:u,source_key:"event-#{event.id}-announcement-#{key}",title:"Event Announcement: #{event.title}",message:body.strip,category:'events',topic:'events',icon:'megaphone',href:"/events?event=#{event.id}")
        end
        result={delivered:delivered,skipped:recipients.count-delivered}
        Administration.audit!(current_user,'event.announcement_sent',event,result.merge(request_key:key,digest:digest))
      end
    end
    render json:result
  end
  def duplicate
    source=object(:event);copy=nil
    Administration.transaction do
      AdminEventManagement.authorize!(current_user);event.lock!;raise ActiveRecord::RecordNotFound if event.deleted_at;AdminEventManagement.revision!(event,source[:lock_version])
      data=event.attributes.slice('title','description','event_type','format','location','meeting_url','capacity','platform_program_id').merge(source.permit(:title,:starts_at,:ends_at).to_h).merge('status'=>'draft')
      copy=AdminEventManagement.save!(current_user,data)
      copy.banner=event.banner.blob if event.banner.attached?
      copy.save!
      shift=copy.starts_at-event.starts_at
      event.event_agenda_items.each do |a|
        attrs=a.attributes.slice('title','description').merge(starts_at:a.starts_at+shift,ends_at:a.ends_at+shift)
        copy.event_agenda_items.create!(attrs)
      end
      event.event_speakers.each{|s|copy.event_speakers.create!(s.attributes.slice('name','title','bio','avatar_url'))}
      event.event_materials.active.each do |m|
        n=copy.event_materials.new(m.attributes.slice('title','description','url'));n.file=m.file.blob if m.file.attached?;n.save!
      end
      Administration.audit!(current_user,'event.duplicated',copy,{source_id:event.id})
    end
    render json:{id:copy.id},status: :created
  end
  def destroy
    Administration.transaction do
      AdminEventManagement.authorize!(current_user);event.lock!;raise ActiveRecord::RecordNotFound if event.deleted_at;AdminEventManagement.revision!(event,params[:lock_version])
      raise Administration::Rejected.new('Cancel a published event before deleting it',:unprocessable_entity) if event.status=='published'&&event.ends_at>Time.current
      event.update!(deleted_at:Time.current);Administration.audit!(current_user,'event.deleted',event,{title:event.title})
    end
    head :no_content
  end
  def report
    summary=EventDetailsQuery.new(event).summary
    csv=CSV.generate do |out|
      out<<%w[metric value]
      {title:event.title,event_type:event.event_type,publication:event.status,starts_at:event.starts_at.iso8601,ends_at:event.ends_at.iso8601,location:event.location,capacity:event.capacity,generated_at:Time.current.iso8601}.merge(summary.slice(:registered,:attended,:no_show,:unrecorded,:cancelled,:attendance_rate,:rating,:feedback_count,:materials,:speakers)).each{|k,v|out<<[k,AdminUserQuery.csv_cell(v)]}
      summary[:ratings].each{|r|out<<["rating_#{r[:rating]}",r[:count]]}
      summary[:trend].each{|r|out<<["registrations_at_#{r[:at]}",r[:registrations]]}
    end
    Administration.audit!(current_user,'event.report_exported',event,{})
    send_data csv,type:'text/csv; charset=utf-8',filename:"event-#{event.id}-report.csv"
  end
  private
  def object(key)
    source=params.require(key)
    raise Administration::Rejected.new("#{key} must be an object",:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    source
  end
  def item_scope
    case params[:section]
    when 'agenda' then [event.event_agenda_items,[:title,:description,:starts_at,:ends_at],100]
    when 'speakers' then [event.event_speakers,[:name,:title,:bio,:avatar_url,:role],50]
    when 'materials' then [event.event_materials.active,[:title,:description,:url],100]
    else raise Administration::Rejected.new('Choose agenda, speakers or materials',:unprocessable_entity)
    end
  end
end
