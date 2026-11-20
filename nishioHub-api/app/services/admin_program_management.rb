module AdminProgramManagement
  def self.revision!(record, value)
    unless value.to_s.match?(/\A\d+\z/) && value.to_i == record.lock_version
      raise Administration::Rejected.new('This record changed. Reload the program before saving.', :conflict)
    end
  end
  def self.save!(actor, data, program: nil)
    creating = program.nil?
    Administration.transaction do
      actor.reload
      Administration.authorize!(actor, 'dashboard.read')
      Administration.authorize!(actor, 'dashboard.manage')
      program ||= PlatformProgram.new(created_by: actor)
      program.lock! unless creating
      revision!(program, data['lock_version']) unless creating
      if data.key?('featured')&&![true,false,'true','false'].include?(data['featured'])
        raise Administration::Rejected.new('Featured must be true or false',:unprocessable_entity)
      end
      attributes = data.slice('public_details', 'audience_stages', 'themes', 'featured', 'title', 'description', 'status', 'starts_on', 'ends_on', 'icon', 'category_id', 'capacity', 'objectives', 'target_audience', 'delivery_mode', 'registration_starts_on', 'registration_ends_on', 'evaluation_starts_on', 'evaluation_ends_on')
      attributes['category_id'] = nil if attributes.key?('category_id') && attributes['category_id'].blank?
      if attributes['category_id'].present? && attributes['category_id'].to_s != program.category_id.to_s
        Category.active.find(attributes['category_id'])
      end
      if data.key?('remove_banner')&&![true,false,'true','false'].include?(data['remove_banner'])
        raise Administration::Rejected.new('Remove banner must be true or false',:unprocessable_entity)
      end
      removing=[true,'true'].include?(data['remove_banner'])
      if removing&&data['banner'].present?
        raise Administration::Rejected.new('Choose a replacement banner or remove the existing one, not both',:unprocessable_entity)
      end
      banner_changed=data['banner'].present?||(removing&&program.banner.attached?)
      if data['banner'].present?
        upload=data['banner']
        unless upload.is_a?(ActionDispatch::Http::UploadedFile)&&upload.size<=2.megabytes&&%w[image/jpeg image/png image/webp].include?(Marcel::MimeType.for(upload.tempfile))
          raise Administration::Rejected.new('Upload a JPEG, PNG or WebP image up to 2 MB',:unprocessable_entity)
        end
        program.banner=upload
      elsif removing
        program.banner=nil
      end
      program.update!(attributes)
      program.touch if banner_changed&&!creating
      if data.key?('mentor_ids')
        ids = ids!(data['mentor_ids'], allow_empty: true)
        existing = program.program_mentor_assignments.active.pluck(:user_id)
        new_ids = ids - existing
        eligible = User.with_role('mentor').where(id: new_ids, is_active: true).pluck(:id)
        raise Administration::Rejected.new('Choose active Mentor accounts for new assignments', :unprocessable_entity) unless eligible.size == new_ids.size
        program.program_mentor_assignments.where.not(user_id: ids).update_all(is_active: false, updated_at: Time.current)
        ids.each { |id| program.program_mentor_assignments.find_or_initialize_by(user_id: id).update!(is_active: true) }
        program.touch if existing.sort != ids.sort
      end
      changes=data.except('lock_version','banner')
      changes=changes.merge('banner_changed'=>true,'banner_removed'=>removing) if banner_changed
      Administration.audit!(actor, creating ? 'program.created' : 'program.updated', program, changes)
      # Keep attachment changes until the outer transaction commits and uploads
      # the file. Reloading here clears Active Storage's pending upload.
      program
    end
  end
  def self.ids!(raw, allow_empty: false)
    unless raw.is_a?(Array) && raw.size.between?(allow_empty ? 0 : 1, 100) && raw.all? { |id| id.to_s.match?(/\A[1-9]\d*\z/) }
      raise Administration::Rejected.new('Select up to 100 valid people', :unprocessable_entity)
    end
    raw.map(&:to_i).uniq
  end
  def self.members!(actor, id, user_ids)
    Administration.transaction do
      actor.reload
      Administration.authorize!(actor, 'dashboard.read')
      Administration.authorize!(actor, 'dashboard.manage')
      program = PlatformProgram.lock.find(id)
      raise Administration::Rejected.new('Reactivate this program before adding enrollments', :unprocessable_entity) if program.status == 'archived'
      ids = ids!(user_ids)
      users = User.with_role('mentee').where(id: ids, is_active: true)
      raise Administration::Rejected.new('Choose active Mentee accounts', :unprocessable_entity) unless users.count == ids.size
      current = program.program_memberships.where(is_active: true, user_id: User.with_role('mentee').select(:id)).pluck(:user_id)
      if program.capacity && (current | ids).size > program.capacity
        raise Administration::Rejected.new('Program capacity would be exceeded', :unprocessable_entity)
      end
      ids.each { |user_id| program.program_memberships.find_or_initialize_by(user_id: user_id).update!(is_active: true) }
      Administration.audit!(actor, 'program.enrollments_added', program, { user_ids: ids })
    end
  end
  def self.change_member!(actor, program_id, membership_id, version, attributes)
    Administration.transaction do
      actor.reload
      Administration.authorize!(actor, 'dashboard.read')
      Administration.authorize!(actor, 'dashboard.manage')
      program = PlatformProgram.lock.find(program_id)
      membership = program.program_memberships.where(user_id: User.with_role('mentee').select(:id)).lock.find(membership_id)
      revision!(membership, version)
      if attributes.key?(:progress) && program.status == 'archived'
        raise Administration::Rejected.new('Reactivate this program before updating enrollment progress', :unprocessable_entity)
      end
      membership.update!(attributes)
      Administration.audit!(actor, 'program.enrollment_updated', program, { user_id: membership.user_id }.merge(attributes))
      membership
    end
  end
end
