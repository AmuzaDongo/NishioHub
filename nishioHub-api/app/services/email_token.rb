module EmailToken
  ALGORITHM = "HS256"

  def self.secret
    ENV.fetch("EMAIL_TOKEN_SECRET", "email_secret_key")
  end

  def self.encode(email, exp: 30.minutes.from_now)
    JWT.encode({ sub: email, exp: exp.to_i }, secret, ALGORITHM)
  end

  def self.decode(token)
    JWT.decode(token, secret, true, algorithm: ALGORITHM).first["sub"]
  rescue JWT::DecodeError
    nil
  end
end
