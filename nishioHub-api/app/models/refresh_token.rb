class RefreshToken < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  def expired?
    revoked? || Time.current >= expires_at
  end

  def self.issue_for(user)
    expires_at = SystemSetting.config['refresh_token_days'].days.from_now
    token = JsonWebToken.encode({ sub: user.email, user_id: user.id, auth_version: user.auth_version, jti: SecureRandom.uuid }, exp: expires_at)
    create!(token: token, user: user, expires_at: expires_at)
  end
end
