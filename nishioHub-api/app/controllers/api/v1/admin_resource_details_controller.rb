class Api::V1::AdminResourceDetailsController < Api::V1::AdminResourcesController
  def show
    r = find_resource; report = ResourceDetailsQuery.new(r)
    render json: serialize(r).merge(report.metadata).merge(summary: report.summary(params[:months].presence || '6'), activity: report.activity,
      capabilities: { manage: current_user.management_permission?('dashboard.manage') })
  end
  def update
    source = object(:details)
    Administration.transaction do
      AdminResourceManagement.authorize!(current_user); r = find_resource.lock!; AdminResourceManagement.revision!(r, source[:lock_version]); r.version_actor = current_user; ResourceVersion.capture!(r, current_user)
      attrs = source.permit(:language, :target_audience, :module_name, :position, :awards, :duration_seconds, :visibility).to_h
      %w[position duration_seconds].each { |k| attrs[k] = nil if attrs.key?(k) && attrs[k].blank? }
      if source.key?(:required)
        raise Administration::Rejected.new('Required must be true or false', :unprocessable_entity) unless [true,false,'true','false'].include?(source[:required])
        attrs['required'] = [true,'true'].include?(source[:required])
      end
      if source.key?(:library_details_json)
        begin
          metadata=JSON.parse(source[:library_details_json].to_s)
          raise JSON::ParserError unless metadata.is_a?(Hash)
        rescue JSON::ParserError
          raise Administration::Rejected.new('Library details must be a JSON object',:unprocessable_entity)
        end
        attrs['library_details']=metadata
      end
      if source.key?(:page_details_json)
        begin
          metadata=JSON.parse(source[:page_details_json].to_s)
          raise JSON::ParserError unless metadata.is_a?(Hash)
        rescue JSON::ParserError
          raise Administration::Rejected.new('Resource page details must be a JSON object',:unprocessable_entity)
        end
        attrs['page_details']=metadata
      end
      r.assign_attributes(attrs)
      if source[:thumbnail].present?
        file = source[:thumbnail]; upload!(file, %w[image/jpeg image/png image/webp], 2.megabytes); r.thumbnail = file
      elsif [true,'true'].include?(source[:remove_thumbnail]) then r.thumbnail = nil
      end
      if source[:captions].present?
        file = source[:captions]
        valid = file.is_a?(ActionDispatch::Http::UploadedFile) && file.size <= 1.megabyte && file.tempfile.read(32).force_encoding(Encoding::UTF_8).sub(/\A\uFEFF/, '').start_with?('WEBVTT')
        file.tempfile.rewind if file.is_a?(ActionDispatch::Http::UploadedFile)
        raise Administration::Rejected.new('Upload a WebVTT caption file up to 1 MB', :unprocessable_entity) unless valid
        r.captions = { io: file.tempfile, filename: file.original_filename, content_type: 'text/vtt', identify: false }
      elsif [true,'true'].include?(source[:remove_captions]) then r.captions = nil
      end
      r.save!; r.touch
      Administration.audit!(current_user, 'resource.details_updated', r, { fields: attrs.keys })
    end
    show
  end
  def section
    r = find_resource; search = params[:q].to_s.first(100); term = "%#{ActiveRecord::Base.sanitize_sql_like(search)}%"
    case params[:section]
    when 'contents'
      scope = r.resource_contents.order(:position, :id); scope = scope.where('title ILIKE :q OR body ILIKE :q', q: term) if search.present?
      total = scope.count; rows = scope.offset((page - 1) * 20).limit(20).map { |c| ResourceDetailsQuery.content(c) }
    when 'feedback'
      scope = r.resource_feedbacks.includes(:user).order(updated_at: :desc); scope = scope.where('comment ILIKE ?', term) if search.present?
      total = scope.count; rows = scope.offset((page - 1) * 20).limit(20).map { |f| { id: f.id, author: f.user.full_name, rating: f.rating, comment: f.comment, created_at: f.updated_at.iso8601 } }
    when 'engagement'
      scope = r.resource_progresses.joins(:user).includes(:user).order(updated_at: :desc); scope = scope.where('users.full_name ILIKE ?', term) if search.present?
      total = scope.count; rows = scope.offset((page - 1) * 20).limit(20).map { |p| { id: p.id, name: p.user.full_name, percent: p.percent, completed_at: p.completed_at&.iso8601, updated_at: p.updated_at.iso8601 } }
    when 'versions'
      scope = r.resource_versions.order(number: :desc); scope = scope.where('actor_name ILIKE ?', term) if search.present?
      total = scope.count; rows = scope.offset((page - 1) * 20).limit(20).map { |v| { id: v.id, number: v.number, actor: v.actor_name, created_at: v.created_at.iso8601, title: v.snapshot['title'], contents: Array(v.snapshot['contents']).size, file: v.file.attached? ? v.file.filename.to_s : nil } }
    when 'audit'
      scope = AdministrationAudit.where(target_type: 'PlatformResource', target_id: r.id).order(created_at: :desc, id: :desc); scope = scope.where('action ILIKE :q OR actor_name ILIKE :q', q: term) if search.present?
      total = scope.count; rows = scope.offset((page - 1) * 20).limit(20).map { |a| { id: a.id, action: a.action, actor: a.actor_name, created_at: a.created_at.iso8601 } }
    else return render_error('Choose contents, feedback, engagement, versions or audit', :unprocessable_entity)
    end
    render json: { items: rows, meta: { page: page, per_page: 20, total: total, total_pages: (total / 20.0).ceil } }
  end
  def supporting_file
    resource=find_resource;content=resource.resource_contents.find(params[:content_id]);raise ActiveRecord::RecordNotFound unless content.file.attached?
    response.headers['Cache-Control']='private, no-store'
    send_data content.file.download,type:content.file.content_type,filename:content.file.filename.to_s,disposition:'attachment'
  end
  def save_content
    source = object(:content)
    Administration.transaction do
      AdminResourceManagement.authorize!(current_user); r = find_resource.lock!; r.version_actor = current_user; ResourceVersion.capture!(r,current_user)
      c = params[:content_id] ? r.resource_contents.lock.find(params[:content_id]) : r.resource_contents.new
      AdminResourceManagement.revision!(c, source[:lock_version]) if c.persisted?
      raise Administration::Rejected.new('Keep at most 100 content sections', :unprocessable_entity) if c.new_record? && r.resource_contents.count >= 100
      attrs = source.permit(:title, :body, :url, :position, :start_seconds).to_h
      attrs['start_seconds'] = nil if attrs.key?('start_seconds') && attrs['start_seconds'].blank?
      if source.key?(:public_listing)
        raise Administration::Rejected.new('Public listing must be true or false',:unprocessable_entity) unless [true,false,'true','false'].include?(source[:public_listing])
        attrs['public_listing']=[true,'true'].include?(source[:public_listing])
      end
      if source[:file].present?
        upload!(source[:file],PlatformResource::DOCUMENT_TYPES+PlatformResource::OTHER_TYPES,[SystemSetting.config['max_upload_mb'].to_i,10].min.megabytes)
        c.file=source[:file]
      elsif [true,'true'].include?(source[:remove_file])
        c.file=nil
      end
      c.update!(attrs); r.touch; ResourceVersion.capture!(r,current_user)
      Administration.audit!(current_user,'resource.content_saved',r,{ content_id:c.id, title:c.title })
    end
    head :no_content
  end
  def remove_content
    Administration.transaction do
      AdminResourceManagement.authorize!(current_user); r=find_resource.lock!; ResourceVersion.capture!(r,current_user); c=r.resource_contents.lock.find(params[:content_id]); AdminResourceManagement.revision!(c,params[:lock_version]); c.destroy!; r.touch; ResourceVersion.capture!(r,current_user)
      Administration.audit!(current_user,'resource.content_removed',r,{content_id:params[:content_id]})
    end
    head :no_content
  end
  def share
    source=object(:share)
    Administration.transaction do
      AdminResourceManagement.authorize!(current_user);r=find_resource.lock!;AdminResourceManagement.revision!(r,source[:lock_version]);ResourceVersion.capture!(r,current_user)
      p=PlatformProgram.active.find(AdminMenteeQuery.positive_id!(source[:program_id]))
      raise Administration::Rejected.new('Keep at most 100 program shares',:unprocessable_entity) if r.resource_program_shares.count>=100 && !r.resource_program_shares.exists?(platform_program:p)
      r.resource_program_shares.find_or_create_by!(platform_program:p);r.touch;ResourceVersion.capture!(r,current_user)
      Administration.audit!(current_user,'resource.shared',r,{program_id:p.id})
    end
    head :no_content
  end
  def unshare
    Administration.transaction do
      AdminResourceManagement.authorize!(current_user);r=find_resource.lock!;AdminResourceManagement.revision!(r,params[:lock_version]);ResourceVersion.capture!(r,current_user)
      r.resource_program_shares.find(params[:share_id]).destroy!;r.reload; r.version_actor=current_user;r.save!;r.touch
      Administration.audit!(current_user,'resource.share_removed',r,{share_id:params[:share_id]})
    end
    head :no_content
  end
  def restore
    Administration.transaction do
      AdminResourceManagement.authorize!(current_user);r=find_resource.lock!;AdminResourceManagement.revision!(r,params[:lock_version]);ResourceVersion.capture!(r,current_user);v=r.resource_versions.find(params[:version_id]);snapshot=v.snapshot
      if snapshot['platform_program_id'].present? && snapshot['platform_program_id']!=r.platform_program_id
        PlatformProgram.active.find(snapshot['platform_program_id'])
      end
      shares=Array(snapshot['shares']); raise Administration::Rejected.new('Restore requires active shared programs',:unprocessable_entity) unless PlatformProgram.active.where(id:shares).count==shares.size
      r.assign_attributes(snapshot.slice(*(ResourceVersion::FIELDS-%w[published archived published_at deleted_at])).merge('library_details'=>snapshot['library_details']||{},'page_details'=>snapshot['page_details']||{}));r.published=false;r.archived=false;r.version_actor=current_user;r.type_explicit=true
      r.resource_contents.destroy_all;r.resource_program_shares.destroy_all
      Array(snapshot['contents']).each do |attrs|
        content=r.resource_contents.new(attrs.except('file_blob_id'))
        if attrs['file_blob_id']
          blob=v.content_files.blobs.find_by(id:attrs['file_blob_id'])
          raise Administration::Rejected.new('A supporting file from this version is unavailable.',:unprocessable_entity) unless blob
          content.file=blob
        end
        content.save!
      end
      shares.each{|p|r.resource_program_shares.create!(platform_program_id:p)}
      %w[file thumbnail captions].each{|key|r.public_send("#{key}=",v.public_send(key).attached? ? v.public_send(key).blob : nil)}
      r.save!;r.touch;Administration.audit!(current_user,'resource.version_restored',r,{version:v.number})
    end
    show
  end
  def duplicate
    copy=nil
    Administration.transaction do
      AdminResourceManagement.authorize!(current_user);source=find_resource.lock!;values=data;values['status']='draft'
      copy=AdminResourceManagement.save!(current_user,values,copy_file:source.file.attached? ? source.file.blob : nil)
      copy.version_actor=current_user;copy.assign_attributes(source.attributes.slice('page_details','library_details','language','target_audience','module_name','position','required','awards','duration_seconds','visibility'))
      source.resource_program_shares.each{|s|copy.resource_program_shares.create!(platform_program_id:s.platform_program_id)}
      source.resource_contents.order(:position,:id).each{|c|item=copy.resource_contents.new(c.attributes.slice('title','body','url','position','start_seconds','public_listing'));item.file=c.file.blob if c.file.attached?;item.save!}
      %w[thumbnail captions].each{|key|copy.public_send("#{key}=",source.public_send(key).blob) if source.public_send(key).attached?}
      copy.save!;copy.touch;Administration.audit!(current_user,'resource.duplicated',copy,{source_id:source.id})
    end
    render json:serialize(copy),status: :created
  end
  def destroy
    Administration.transaction do
      AdminResourceManagement.authorize!(current_user);r=find_resource.lock!;AdminResourceManagement.revision!(r,params[:lock_version]);ResourceVersion.capture!(r,current_user);r.version_actor=current_user;r.update!(deleted_at:Time.current,published:false,archived:true)
      Administration.audit!(current_user,'resource.deleted',r,{title:r.title})
    end
    head :no_content
  end
  def captions
    r=find_resource;raise ActiveRecord::RecordNotFound unless r.captions.attached?
    send_data r.captions.download,type:'text/vtt',filename:r.captions.filename.to_s,disposition:'attachment'
  end
  private
  def find_resource = PlatformResource.kept.find(params[:id])
  def object(key)
    value=params.require(key);raise Administration::Rejected.new("#{key} must be an object",:unprocessable_entity) unless value.is_a?(ActionController::Parameters);value
  end
  def upload!(file,types,limit)
    raise Administration::Rejected.new('Upload a supported image up to 2 MB',:unprocessable_entity) unless file.is_a?(ActionDispatch::Http::UploadedFile)&&file.size<=limit&&types.include?(Marcel::MimeType.for(file.tempfile,name:file.original_filename))
  end
end
