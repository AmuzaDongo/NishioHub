class PublicInquiry < ApplicationRecord
  has_secure_token :reference
  belongs_to :requester,class_name:'User',optional:true
  belongs_to :reviewer,class_name:'User',optional:true
  belongs_to :event,optional:true
  validates :status,inclusion:{in:%w[pending approved rejected changes_requested]}
  validates :review_note,length:{maximum:2000}
  CATEGORIES=%w[general support billing mentorship feedback other partnership event_hosting].freeze
  EVENT_TYPES=%w[workshop webinar mentorship career_talk community_event].freeze
  before_validation {self.email=email.to_s.strip.downcase;self.name=name.to_s.strip;self.subject=subject.to_s.strip}
  validates :name,length:{minimum:2,maximum:150}
  validates :email,format:{with:URI::MailTo::EMAIL_REGEXP},length:{maximum:254}
  validates :subject,length:{minimum:5,maximum:150}
  validates :message,length:{minimum:10,maximum:1000}
  validates :category,inclusion:{in:CATEGORIES}
  validates :reviewed,inclusion:{in:[true,false]}
  validates :submission_key, format: {with:/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i}, if: -> {category=='event_hosting'||partnership_details.present?||program_details.present?}
  validate :validate_event_details, if: -> {category=='event_hosting'}

  PARTNERSHIP_FOCUSES=%w[schools universities businesses ngos government community].freeze
  validate :validate_partnership_details, if: -> {partnership_details.present?}

  private

  def validate_partnership_details
    unless partnership_details.is_a?(Hash)
      errors.add(:partnership_details,'must be an object')
      return
    end
    details=partnership_details
    errors.add(:category,'must be partnership') unless category=='partnership'
    %w[organization_name contact_role].each do |field|
      details[field]=details[field].to_s.strip
      errors.add(field,'must contain 2–120 characters') unless details[field].length.between?(2,120)
    end
    details['phone_number']=ApplicationPhoneNumber.normalize(details['phone_number'])
    phone=details['phone_number']
    code,length=ApplicationPhoneNumber::COUNTRY_LENGTHS.find{|prefix,_|phone.start_with?("+#{prefix}")}
    errors.add(:phone_number,'is invalid') unless phone.match?(ApplicationPhoneNumber::FORMAT)&&(!code||phone.length==1+code.length+length)
    errors.add(:focus,'is invalid') unless PARTNERSHIP_FOCUSES.include?(details['focus'])
    errors.add(:message,'must contain 20–500 characters') unless message.to_s.strip.length.between?(20,500)
    errors.add(:terms_accepted,'must be accepted') unless details['terms_accepted']==true
    errors.add(:request_kind,'is invalid') unless %w[partnership meeting].include?(details['request_kind'])
    if details['request_kind']=='meeting'
      begin
        value=details['preferred_at'].to_s
        raise ArgumentError unless value.match?(/(?:Z|[+-]\d{2}:\d{2})\z/)
        preferred=Time.iso8601(value)
        errors.add(:preferred_at,'must be in the future') if (new_record?||will_save_change_to_partnership_details?)&&preferred<=Time.current
      rescue ArgumentError
        errors.add(:preferred_at,'must be a valid date and time with timezone')
      end
    end
  end

  def validate_event_details
    unless event_details.is_a?(Hash)
      errors.add(:event_details,'must be an object')
      return
    end
    event_details['phone_number']=ApplicationPhoneNumber.normalize(event_details['phone_number'])
    errors.add(:phone_number,'is invalid') unless event_details['phone_number'].match?(ApplicationPhoneNumber::FORMAT)
    code,length=ApplicationPhoneNumber::COUNTRY_LENGTHS.find{|prefix,_|event_details['phone_number'].start_with?("+#{prefix}")}
    errors.add(:phone_number,'has an invalid length') if code&&event_details['phone_number'].length!=1+code.length+length
    errors.add(:event_type,'is invalid') unless EVENT_TYPES.include?(event_details['event_type'])
    errors.add(:location,'must contain 2–150 characters') unless event_details['location'].is_a?(String)&&event_details['location'].strip.length.between?(2,150)
    errors.add(:description,'must contain 20–500 characters') unless message.to_s.strip.length.between?(20,500)
    errors.add(:additional_information,'must contain at most 300 characters') unless event_details['additional_information'].is_a?(String)&&event_details['additional_information'].length<=300
    errors.add(:terms_accepted,'must be accepted') unless event_details['terms_accepted']==true
    begin
      value=event_details['preferred_date']
      date=Date.iso8601(value.to_s)
      errors.add(:preferred_date,'must be today or later') if (new_record?||will_save_change_to_event_details?)&&date<Time.current.in_time_zone(SystemSetting.config.fetch('timezone')).to_date
      errors.add(:preferred_date,'must use YYYY-MM-DD') unless value.to_s==date.iso8601
    rescue Date::Error
      errors.add(:preferred_date,'is invalid')
    end
  end
end
