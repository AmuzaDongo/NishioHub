class SystemSetting < ApplicationRecord
  DEFAULTS = {
    'platform_name' => 'NishioHub', 'tagline' => 'Discover. Learn. Grow.',
    'organization_name' => 'NishioHub Limited', 'support_email' => 'support@nishiohub.com', 'support_phone' => '',
    'timezone' => 'Africa/Kampala', 'language' => 'en-UG', 'date_format' => 'medium', 'currency' => 'UGX',
    'platform_mode' => 'live', 'registration_enabled' => true, 'require_email_verification' => false,
    'matching_enabled' => true, 'public_events_enabled' => false, 'notifications_enabled' => true,
    'learning_enrollment_enabled' => true, 'event_registration_enabled' => true,
    'default_registration_role' => 'mentee', 'access_token_minutes' => 60, 'refresh_token_days' => 7,
    'password_min_length' => 8, 'max_upload_mb' => 10,
    'maintenance_message' => 'NishioHub is undergoing maintenance. Please check back shortly.',
    'allowed_meeting_hosts' => [], 'support_url' => '',
    'about_story_video_url' => '', 'about_team' => []
  }.freeze
  ENUMS = { 'timezone' => %w[Africa/Kampala Africa/Nairobi Africa/Kigali UTC],
    'language' => %w[en-UG en-US en-GB], 'currency' => %w[UGX USD KES TZS RWF EUR GBP],
    'date_format' => %w[medium day_first iso], 'platform_mode' => %w[live staging maintenance],
    'default_registration_role' => %w[mentee mentor] }.freeze
  LIMITS = { 'access_token_minutes' => 5..240, 'refresh_token_days' => 1..30,
    'password_min_length' => 8..64, 'max_upload_mb' => 1..20 }.freeze
  belongs_to :updated_by, class_name: 'User', optional: true
  has_one_attached :logo
  has_one_attached :favicon
  validates :key, inclusion: { in: ['platform'] }, uniqueness: true
  validate :validate_values

  def self.current
    find_by(key: 'platform') || create_or_find_by!(key: 'platform')
  end

  def self.config
    current.config
  end

  def config
    DEFAULTS.merge(values)
  end

  def self.mail_configured?
    Rails.env.test? || ENV['SMTP_ADDRESS'].present? && ENV['MAIL_FROM'].present?
  end

  private

  def public_about_url?(value)
    return false unless value.is_a?(String) && value.length <= 2048
    uri = URI.parse(value) rescue nil
    uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil?
  end

  def validate_values
    unless values.is_a?(Hash)
      errors.add(:values, 'must be an object')
      return
    end
    errors.add(:values, "contains unknown fields: #{(values.keys - DEFAULTS.keys).join(', ')}") if (values.keys - DEFAULTS.keys).any?
    data = config
    DEFAULTS.each do |key, default|
      value = data[key]
      if [true, false].include?(default)
        errors.add(key, 'must be true or false') unless [true, false].include?(value)
      elsif default.is_a?(String)
        errors.add(key, 'must be text') unless value.is_a?(String)
      end
    end
    ENUMS.each { |key, allowed| errors.add(key, 'is not supported') unless allowed.include?(data[key]) }
    LIMITS.each { |key, range| errors.add(key, "must be an integer between #{range.first} and #{range.last}") unless data[key].is_a?(Integer) && range.cover?(data[key]) }
    %w[platform_name organization_name support_email maintenance_message].each { |key| errors.add(key, "can't be blank") if data[key].blank? }
    %w[platform_name organization_name tagline support_email support_phone].each { |key| errors.add(key, 'is too long (maximum 150)') if data[key].to_s.length > 150 }
    errors.add(:maintenance_message, 'is too long (maximum 500)') if data['maintenance_message'].to_s.length > 500
    errors.add(:support_email, 'is invalid') unless data['support_email'].to_s.match?(URI::MailTo::EMAIL_REGEXP)
    hosts = data['allowed_meeting_hosts']
    unless hosts.is_a?(Array) && hosts.size <= 20 && hosts.all? { |host| host.is_a?(String) && host.match?(/\A[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\.[a-z]{2,}\z/) }
      errors.add(:allowed_meeting_hosts, 'must contain up to 20 host names, without URLs or wildcards')
    end
    if data['support_url'].present?
      uri = URI.parse(data['support_url'].to_s) rescue nil
      errors.add(:support_url, 'must be an HTTP or HTTPS URL') unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil? && data['support_url'].to_s.length <= 2048
    end
    video = data['about_story_video_url']
    unless video == '' || (public_about_url?(video) && URI.parse(video).path.match?(/\.(mp4|webm)\z/i))
      errors.add(:about_story_video_url, 'must be an HTTPS MP4 or WebM video URL, or blank')
    end
    team = data['about_team']
    valid_team = team.is_a?(Array) && team.length <= 20 && team.all? do |member|
      member.is_a?(Hash) && (member.keys - %w[name title bio photo_url published]).empty? &&
        member['name'].is_a?(String) && member['name'].strip.length.between?(2,100) &&
        member['title'].is_a?(String) && member['title'].strip.length.between?(2,150) &&
        member['bio'].is_a?(String) && member['bio'].length <= 500 &&
        [true,false].include?(member['published']) &&
        (member['photo_url'] == '' || public_about_url?(member['photo_url']))
    end
    errors.add(:about_team, 'must contain up to 20 team members with name, title, bio, HTTPS photo URL and publication status') unless valid_team
    if data['require_email_verification'] == true && !self.class.mail_configured?
      errors.add(:require_email_verification, 'needs SMTP_ADDRESS and MAIL_FROM configured on the server')
    end
  end
end
