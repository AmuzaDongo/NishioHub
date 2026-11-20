class EventSuggestion < ApplicationRecord
  belongs_to :user
  validates :title, presence: true, length: { maximum: 160 }
  validates :description, presence: true, length: { maximum: 2000 }
  validates :category, inclusion: { in: Event::CATEGORIES }
end
