class EventAgendaItem < ApplicationRecord
  belongs_to :event
  validates :title, presence:true, length:{maximum:200}
  validates :description, length:{maximum:2000}
  validates :starts_at, :ends_at, presence:true
  validate do
    if starts_at && ends_at
      errors.add(:ends_at,'must be after the start') if ends_at<=starts_at
      errors.add(:base,'Agenda times must fall within the event schedule') if starts_at<event.starts_at || ends_at>event.ends_at
    end
  end
end
