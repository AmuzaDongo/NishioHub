module AdminResourceManagement
  def self.authorize!(actor)
    actor.reload
    Administration.authorize!(actor, 'dashboard.read')
    Administration.authorize!(actor, 'dashboard.manage')
  end
  def self.revision!(record, version)
    raise Administration::Rejected.new('This resource changed. Reload it before saving.', :conflict) unless version.to_s.match?(/\A\d+\z/) && version.to_i == record.lock_version
  end
  def self.status_attributes(status)
    raise Administration::Rejected.new('Choose published, draft or archived status', :unprocessable_entity) unless %w[published draft archived].include?(status)
    { published: status == 'published', archived: status == 'archived' }
  end
  def self.save!(actor, data, resource: nil, copy_file: nil)
    Administration.transaction do
      authorize!(actor); creating = resource.nil?
      resource ||= PlatformResource.new(created_by: actor, published: false)
      raise ActiveRecord::RecordNotFound if resource.deleted_at
      resource.version_actor = actor
      resource.lock! unless creating
      revision!(resource, data['lock_version']) unless creating
      ResourceVersion.capture!(resource, actor) unless creating
      attrs = data.slice('title', 'description', 'resource_type', 'tags', 'url', 'platform_program_id')
      if attrs['platform_program_id'].present? && attrs['platform_program_id'].to_s != resource.platform_program_id.to_s
        PlatformProgram.active.find(AdminMenteeQuery.positive_id!(attrs['platform_program_id']))
      end
      attrs['platform_program_id'] = nil if attrs.key?('platform_program_id') && attrs['platform_program_id'].blank?
      resource.type_explicit = true
      resource.assign_attributes(attrs)
      resource.assign_attributes(status_attributes(data['status'])) if data.key?('status')
      file = data['file']
      if file.present?
        unless file.is_a?(ActionDispatch::Http::UploadedFile) && file.size <= resource.file_limit && PlatformResource::TYPES.include?(Marcel::MimeType.for(file.tempfile, name: file.original_filename))
          raise Administration::Rejected.new('Upload a supported file within the resource and platform size limits', :unprocessable_entity)
        end
        resource.file.attach(file)
      elsif copy_file && ![true, 'true'].include?(data['remove_file'])
        resource.file.attach(copy_file)
      elsif [true, 'true'].include?(data['remove_file'])
        resource.file.detach
      end
      resource.save!; resource.touch
      Administration.audit!(actor, creating ? 'resource.created' : 'resource.updated', resource, { title: resource.title, type: resource.resource_type, published: resource.published, archived: resource.archived })
      resource
    end
  end
end
