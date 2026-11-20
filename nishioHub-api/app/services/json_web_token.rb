module JsonWebToken
  class DecodeError < StandardError; end

  ALGORITHM = "HS256"

  def self.secret
    ENV.fetch("SECRET_KEY", "dev-secret-change-me")
  end

  def self.encode(payload, exp: 60.minutes.from_now)
    JWT.encode(payload.merge(exp: exp.to_i), secret, ALGORITHM)
  end

  def self.decode(token)
    JWT.decode(token, secret, true, algorithm: ALGORITHM).first
  rescue JWT::DecodeError => e
    raise DecodeError, e.message
  end
end
