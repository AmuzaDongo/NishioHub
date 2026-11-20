class MentorshipResource < ApplicationRecord
  belongs_to :user
  validates :title, presence: true, length: { maximum: 200 }
  validates :url, presence: true, length: { maximum: 2000 }, format: { with: /\Ahttps?:\/\/[^\s]+\z/i }
end
