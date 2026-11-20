module AchievementIdentity
  UUID='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
  PATTERN=/\A(?:(?:award|certificate)-#{UUID}|(?:course|session|program)-[1-9]\d*|badge-(?:#{AchievementCatalog::BADGES.map(&:first).join('|')})-[1-9]\d*)\z/
  def self.valid?(key) = key.is_a?(String)&&key.match?(PATTERN)
end
