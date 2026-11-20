class Conversation < ApplicationRecord
  belongs_to :platform_program,optional:true
  validates :cohort_label,length:{maximum:150}
  belongs_to :creator, class_name: "User"
  has_many :conversation_memberships, dependent: :destroy
  has_many :users, through: :conversation_memberships
  has_many :chat_messages, dependent: :destroy
  validates :kind, inclusion: { in: %w[direct group] }
  validates :title, presence: true, length: { maximum: 150 }, if: -> { kind == "group" }
end
