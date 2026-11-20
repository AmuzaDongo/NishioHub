class SessionAssetAccess < ApplicationRecord
  belongs_to :session_asset
  belongs_to :user, optional: true
  validates :kind, inclusion: { in: %w[view download] }
end
