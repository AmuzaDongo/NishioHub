class SavedReport < ApplicationRecord
  include ReportSpecification
  validates :kind, exclusion: { in: ['overview'] }
end
