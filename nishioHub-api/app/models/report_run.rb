class ReportRun < ApplicationRecord
  belongs_to :user
  belongs_to :report_schedule,optional:true
  has_one_attached :file
  validates :status,inclusion:{in:%w[running complete failed]}
end
