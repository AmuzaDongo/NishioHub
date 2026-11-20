class Profile < ApplicationRecord
  belongs_to :user

  validates :phone_number, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :gender, presence: true, length: { maximum: 10 }
  validates :birth_date, :address, :city, :country, presence: true
  validates :address, length: { maximum: 255 }
  validates :city, :country, length: { maximum: 100 }
end
