class SessionNote < ApplicationRecord
  belongs_to :booking
  belongs_to :author, class_name: 'User', optional: true
  validates :author_name, presence: true
  validates :body, presence: true, length: { maximum: 5000 }
end
