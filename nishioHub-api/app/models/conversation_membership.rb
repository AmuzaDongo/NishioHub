class ConversationMembership < ApplicationRecord
  belongs_to :conversation
  belongs_to :user
  validates :last_read_message_id, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
