class EventSpeaker < ApplicationRecord
  belongs_to :event
  validates :name, presence:true, length:{maximum:160}
  validates :title, length:{maximum:200}
  validates :role,presence:true,length:{maximum:60}
  validates :bio, length:{maximum:2000}
  validates :avatar_url, length:{maximum:2048}
  validate do
    if avatar_url.present?
      uri=URI.parse(avatar_url) rescue nil
      errors.add(:avatar_url,'must be an HTTP(S) URL without credentials') unless uri.is_a?(URI::HTTP)&&uri.host.present?&&uri.userinfo.nil?
    end
  end
end
