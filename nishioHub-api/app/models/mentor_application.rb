class MentorApplication < ApplicationRecord
  POLICY_VERSION='2026-11-15'.freeze
  DOCUMENTS=%w[identity_document curriculum_vitae qualification_document].freeze
  UPLOADS=(DOCUMENTS+['profile_photo']).freeze
  GENDERS=%w[male female other prefer_not_to_say].freeze
  QUALIFICATIONS=%w[secondary certificate diploma bachelors masters doctorate other].freeze
  EXPERIENCE_RANGES={'0-1'=>0..1,'2-5'=>2..5,'6-10'=>6..10,'10+'=>10..80}.freeze
  LEARNERS=%w[primary secondary university early_career].freeze
  TYPES=%w[application/pdf image/jpeg image/png].freeze
  belongs_to :user
  belongs_to :reviewed_by,class_name:'User',optional:true
  has_one_attached :profile_photo
  has_one_attached :identity_document
  has_one_attached :curriculum_vitae
  has_one_attached :qualification_document
  validates :user_id,uniqueness:true
  validates :status,inclusion:{in:%w[draft submitted changes_requested approved rejected]}
  validates :headline,length:{maximum:150}
  validates :background,length:{maximum:2000}
  validates :expertise,:motivation,:references_text,:review_note,length:{maximum:2000}
  validates :full_name,length:{maximum:100}
  validates :location,:organization,length:{maximum:150}
  validates :contact_email,length:{maximum:100},format:{with:URI::MailTo::EMAIL_REGEXP},allow_blank:true
  before_validation { self.phone_number=ApplicationPhoneNumber.normalize(phone_number) }
  validates :phone_number,format:{with:ApplicationPhoneNumber::FORMAT,message:'must include a country code, e.g. +256 772 345 678'},allow_blank:true
  validates :gender,inclusion:{in:GENDERS},allow_blank:true
  validates :highest_qualification,inclusion:{in:QUALIFICATIONS},allow_blank:true
  validates :experience_range,inclusion:{in:EXPERIENCE_RANGES.keys},allow_blank:true
  validates :form_version,inclusion:{in:[1,2]}
  validates :terms_accepted,inclusion:{in:[true,false]}
  validates :years_of_experience,numericality:{only_integer:true,greater_than_or_equal_to:0,less_than_or_equal_to:80}
  validates :conduct_accepted,:safeguarding_accepted,inclusion:{in:[true,false]}
  validate do
    if profile_photo.attached?
      errors.add(:profile_photo,'must be a JPEG or PNG up to 2 MB') unless %w[image/jpeg image/png].include?(profile_photo.content_type)&&profile_photo.byte_size<=2.megabytes
    end
    if form_version>=2&&EXPERIENCE_RANGES.key?(experience_range)&&!EXPERIENCE_RANGES.fetch(experience_range).cover?(years_of_experience)
      errors.add(:years_of_experience,'must match the selected experience range')
    end
    if date_of_birth && (date_of_birth>Time.current.in_time_zone(SystemSetting.config['timezone']).to_date || date_of_birth<130.years.ago.to_date)
      errors.add(:date_of_birth,'must be a valid birth date in the past')
    end
    unless expertise_tags.is_a?(Array)&&expertise_tags.size<=12&&expertise_tags.uniq==expertise_tags&&expertise_tags.all?{|v|v.is_a?(String)&&v.strip.present?&&v.length<=60}
      errors.add(:expertise_tags,'must contain up to 12 distinct areas of expertise')
    end
    unless target_learners.is_a?(Array)&&target_learners.uniq==target_learners&&(target_learners-LEARNERS).empty?
      errors.add(:target_learners,'must contain supported learner groups')
    end
    DOCUMENTS.each do |kind|
      attachment=public_send(kind)
      next unless attachment.attached?
      errors.add(kind,'must be a PDF, JPEG or PNG up to 5 MB') unless TYPES.include?(attachment.blob.content_type)&&attachment.blob.byte_size<=5.megabytes
    end
  end
  def editable? = status.in?(%w[draft changes_requested])
  def submission_errors
    errors=[]
    required=form_version>=2 ? %w[full_name contact_email phone_number location gender date_of_birth highest_qualification headline experience_range background references_text] : %w[headline background expertise motivation references_text]
    required.each{|key|errors<<"#{key.humanize} is required" if public_send(key).blank?}
    if form_version>=2
      errors<<'Profile photo is required' unless profile_photo.attached?
      errors<<'Choose at least one area of expertise' if expertise_tags.empty?
      errors<<'Choose at least one target learner group' if target_learners.empty?
      errors<<'Short bio must contain 100–300 words' unless background.to_s.split.size.between?(100,300)
      errors<<'Accept the Terms of Service' unless terms_accepted
    end
    DOCUMENTS.each{|key|errors<<"#{key.humanize} is required" unless public_send(key).attached?}
    errors<<'Accept the Code of Conduct and Child Safeguarding Policy' unless conduct_accepted&&safeguarding_accepted
    errors
  end
end
