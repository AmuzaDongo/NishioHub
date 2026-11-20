class GoalProgressEvent < ApplicationRecord
  belongs_to :mentee_goal,optional:true
  belongs_to :mentor_goal,optional:true
  belongs_to :program_goal,optional:true
  validates :progress,numericality:{only_integer:true,greater_than_or_equal_to:0,less_than_or_equal_to:100}
  validates :note,presence:true,length:{maximum:250}
  validate { errors.add(:base,'Choose exactly one goal') unless [mentee_goal_id,mentor_goal_id,program_goal_id].compact.size==1 }
  after_create :notify_progress
  def goal = mentee_goal||mentor_goal||program_goal
  private
  def notify_progress
    return if progress.zero? || program_goal_id
    item=goal
    Notification.deliver(user:item.user,source_key:"goal-progress-#{id}",title:'Goal Progress Update',message:"You've reached #{progress}% of your goal: “#{item.title}”.",category:'learning',topic:'goals',icon:'target',href:mentor_goal_id ? '/mentor/mentorship' : '/my-goals',created_at:created_at)
  end
end
