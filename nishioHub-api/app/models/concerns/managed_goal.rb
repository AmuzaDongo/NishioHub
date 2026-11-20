module ManagedGoal
  extend ActiveSupport::Concern
  CATEGORIES=%w[learning career project personal other].freeze
  TRACKING=%w[on_track in_progress at_risk].freeze
  included do
    attr_accessor :progress_note,:progress_actor
    has_one_attached :cover
    has_many :goal_updates,dependent: :destroy
    has_many :goal_attachments,dependent: :destroy
    validates :priority,inclusion:{in:%w[low medium high]}
    validate do
      if cover.attached? && (!%w[image/jpeg image/png image/webp].include?(cover.blob.content_type)||cover.byte_size>2.megabytes)
        errors.add(:cover,'must be a JPEG, PNG or WebP up to 2 MB')
      end
    end
    before_save do
      if progress==100
        self.completed_at=Time.current if (new_record? || will_save_change_to_progress?) && completed_at.nil?
      else
        self.completed_at=nil
      end
    end
    scope :kept, -> {where(archived_at:nil)}
    validates :title,presence:true,length:{maximum:200}
    validates :description,length:{maximum:2000}
    validates :progress,numericality:{only_integer:true,greater_than_or_equal_to:0,less_than_or_equal_to:100}
    validates :completed,inclusion:{in:[true,false]}
    validates :category,inclusion:{in:CATEGORIES}
    validates :tracking_status,inclusion:{in:TRACKING}
    validates :icon,inclusion:{in:%w[target code laptop graduation trophy]}
    validates :progress_note,length:{maximum:250},allow_nil:true
    validate do
      raw=target_date_before_type_cast
      valid=raw.blank? || raw.is_a?(Date) || raw.is_a?(Time) || raw.is_a?(String)&&raw.match?(/\A\d{4}-\d{2}-\d{2}\z/)&&(Date.iso8601(raw) rescue nil)
      errors.add(:target_date,'must be a valid ISO date') unless valid
    end
    before_validation do
      if progress_changed?
        self.completed=progress==100
      elsif completed_changed?
        self.progress=completed ? 100 : 0
      end
    end
    after_create { record_goal_progress('Goal created') }
    after_update { record_goal_progress(progress==100 ? 'Goal completed' : 'Progress updated') if saved_change_to_progress? || progress_note.present? }
  end
  def goal_kind = self.class.name.delete_suffix('Goal').underscore
  def goal_key = "#{goal_kind}-#{id}"
  def display_status
    return 'completed' if progress==100
    return 'at_risk' if target_date && target_date<Time.current.in_time_zone(SystemSetting.config['timezone']).to_date
    tracking_status
  end
  def record_goal_progress(note)
    goal_progress_events.create!(progress:progress,note:progress_note.presence||note,actor_name:progress_actor&.full_name||(respond_to?(:user) ? user&.full_name : 'Program Team'))
  end
end
