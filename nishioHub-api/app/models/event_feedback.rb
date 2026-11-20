class EventFeedback < ApplicationRecord
  belongs_to :event
  belongs_to :user
  validates :user_id, uniqueness:{scope: :event_id}
  validates :rating, numericality:{only_integer:true,in:1..5}
  validates :comment, length:{maximum:2000}
end
