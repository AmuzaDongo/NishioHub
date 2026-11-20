module AdminGoalManagement
  def self.authorize!(actor)
    actor.reload;Administration.authorize!(actor,'dashboard.read');Administration.authorize!(actor,'dashboard.manage')
  end
  def self.find!(key)
    match=key.to_s.match(/\A(mentee|mentor|program)-([1-9]\d*)\z/)
    raise ActiveRecord::RecordNotFound unless match
    AdminGoalQuery::TYPES.fetch(match[1]).kept.find(match[2])
  end
  def self.revision!(record,value)
    raise Administration::Rejected.new('This goal or milestone changed. Reload it before saving.',:conflict) unless value.to_s.match?(/\A\d+\z/)&&value.to_i==record.lock_version
  end
  def self.save!(actor,data,goal:nil)
    Administration.transaction do
      authorize!(actor);creating=goal.nil?
      if creating
        klass=AdminGoalQuery::TYPES[data['kind']]
        raise Administration::Rejected.new('Choose mentee, mentor or program goal',:unprocessable_entity) unless klass
        goal=klass.new
      else
        goal.lock!;raise ActiveRecord::RecordNotFound if goal.archived_at;revision!(goal,data['lock_version'])
        raise Administration::Rejected.new('Goal type cannot change after creation',:unprocessable_entity) if data.key?('kind')&&data['kind']!=goal.goal_kind
      end
      previous=goal.respond_to?(:user_id) ? goal.user_id : nil
      attrs=data.slice('title','description','progress','target_date','icon','category','tracking_status','priority','platform_program_id')
      attrs['platform_program_id']=nil if attrs.key?('platform_program_id')&&attrs['platform_program_id'].blank?
      if attrs['platform_program_id'].present?&&(creating||attrs['platform_program_id'].to_s!=goal.platform_program_id.to_s)
        PlatformProgram.active.find(AdminMenteeQuery.positive_id!(attrs['platform_program_id']))
      end
      unless goal.is_a?(ProgramGoal)
        uid=data.key?('user_id') ? data['user_id'] : goal.user_id
        user=User.find(AdminMenteeQuery.positive_id!(uid))
        if creating||uid.to_s!=goal.user_id.to_s
          raise Administration::Rejected.new('Choose an active account with the selected goal role',:unprocessable_entity) unless user.is_active?&&user.has_role?(goal.goal_kind)
        end
        attrs['user_id']=uid
      end
      goal.progress_actor=actor;goal.progress_note=data['note'];goal.assign_attributes(attrs);goal.save!
      Administration.audit!(actor,creating ? 'goal.created' : 'goal.updated',goal,{kind:goal.goal_kind,title:goal.title,progress:goal.progress,tracking_status:goal.tracking_status,user_id:goal.try(:user_id),program_id:goal.platform_program_id})
      if goal.respond_to?(:user_id)&&(creating||previous!=goal.user_id)
        Notification.deliver(user:goal.user,source_key:"goal-assigned-#{goal.goal_key}-#{goal.lock_version}",title:'New Goal Assigned',message:"An administrator assigned you a goal: “#{goal.title}”.",category:'learning',topic:'goals',icon:'target',href:goal.goal_kind=='mentor' ? '/mentor/mentorship' : '/my-goals')
      end
      goal
    end
  end
end
