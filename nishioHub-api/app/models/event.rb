class Event < ApplicationRecord
  PUBLIC_AUDIENCES = %w[primary secondary university early_career professionals].freeze
  validate :valid_public_details
  validates :public_featured, inclusion: { in: [true, false] }
  validate do
    unless target_audiences.is_a?(Array) && target_audiences.uniq == target_audiences && (target_audiences - PUBLIC_AUDIENCES).empty?
      errors.add(:target_audiences, 'must contain distinct supported audience tags')
    end
    if public_recording_url.present?
      uri = URI.parse(public_recording_url) rescue nil
      unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? && public_recording_url.length <= 2048 && !public_recording_url.match?(/\s/)
        errors.add(:public_recording_url, 'must be a public HTTPS URL without credentials')
      end
    end
  end
  EVENT_TYPES = %w[webinar workshop conference networking launch training talk challenge mentorship other].freeze
  CATEGORY_MAP = { 'webinar'=>'talk', 'workshop'=>'workshop', 'conference'=>'talk', 'networking'=>'mentorship', 'launch'=>'workshop', 'training'=>'workshop', 'talk'=>'talk', 'challenge'=>'challenge', 'mentorship'=>'mentorship', 'other'=>'talk' }.freeze
  attr_accessor :type_explicit, :schedule_override
  belongs_to :platform_program, optional: true
  scope :kept, -> { where(deleted_at: nil) }
  has_one :hosting_request,class_name:'PublicInquiry',foreign_key: :event_id,dependent: :nullify
  has_many :event_agenda_items, dependent: :destroy
  has_many :event_speakers, dependent: :destroy
  has_many :event_materials, dependent: :destroy
  has_many :event_feedbacks, dependent: :destroy
  has_one_attached :banner
  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :status, inclusion: { in: %w[draft published cancelled] }
  validates :format, inclusion: { in: %w[online on_site hybrid] }
  before_validation { self.format = 'online' if new_record? && !type_explicit && meeting_url.present? }
  before_validation { self.event_type = category if !type_explicit && (new_record? || will_save_change_to_category?) }
  validate do
    if persisted? && capacity && capacity < event_registrations.where(status: 'registered').count
      errors.add(:capacity, 'cannot be below registered attendees')
    end
    if persisted? && starts_at_in_database && starts_at_in_database <= Time.current && !schedule_override
      errors.add(:starts_at, 'cannot be changed after the event starts') if starts_at && starts_at.to_i != starts_at_in_database.to_i
      errors.add(:ends_at, 'cannot be changed after the event starts') if ends_at && ends_at_in_database && ends_at.to_i != ends_at_in_database.to_i
    end
    if banner.attached?
      errors.add(:banner, 'must be a JPEG, PNG or WebP up to 2 MB') unless %w[image/jpeg image/png image/webp].include?(banner.blob.content_type) && banner.blob.byte_size <= 2.megabytes
    end
    if meeting_url.present?
      uri = URI.parse(meeting_url) rescue nil
      errors.add(:meeting_url, 'must be an HTTP(S) URL without credentials') unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?
    end
  end
  after_update :notify_event_changes
  CATEGORIES = %w[workshop talk challenge mentorship].freeze
  belongs_to :organizer, class_name: "User"
  has_many :event_registrations, dependent: :destroy
  validates :title, presence: true, length: { maximum: 160 }
  validates :description, presence: true, length: { maximum: 2000 }
  validates :location, presence: true, length: { maximum: 200 }
  validates :category, inclusion: { in: CATEGORIES }
  validates :starts_at, :ends_at, presence: true
  validates :capacity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 5000 }, allow_nil: true
  validates :meeting_url, length: { maximum: 2048 }, format: { with: /\Ahttps?:\/\/[^\s]+\z/i }, allow_blank: true
  validate :end_after_start
  validate :meeting_host_allowed

  def image_path
    return banner.url if banner.attached?
    { "workshop" => "/images/event-coding.png", "talk" => "/images/event-career.png",
      "challenge" => "/images/learning-robotics.png", "mentorship" => "/images/event-mentorship.png" }[category]
  end

  def display_status
    return "scheduled" if status == "draft"
    return "cancelled" if status == "cancelled"
    return "completed" if ends_at <= Time.current
    starts_at > Time.current ? "upcoming" : "ongoing"
  end

  private

  def valid_public_details
    unless public_details.is_a?(Hash)&&(public_details.keys-%w[objectives faqs]).empty?
      errors.add(:public_details,'must contain learning outcomes and FAQs only')
      return
    end
    objectives=public_details.fetch('objectives',[]);faqs=public_details.fetch('faqs',[])
    unless objectives.is_a?(Array)&&objectives.size<=10&&objectives.all?{|value|value.is_a?(String)&&value.strip.length.between?(1,200)}
      errors.add(:public_details,'must contain at most 10 learning outcomes of 1–200 characters')
    end
    unless faqs.is_a?(Array)&&faqs.size<=8&&faqs.all?{|value|value.is_a?(Hash)&&(value.keys-%w[question answer]).empty?&&value['question'].is_a?(String)&&value['question'].strip.length.between?(1,200)&&value['answer'].is_a?(String)&&value['answer'].strip.length.between?(1,1000)}
      errors.add(:public_details,'must contain at most 8 FAQs with a question and answer')
    end
  end

  def notify_event_changes
    return unless saved_change_to_status? || saved_change_to_starts_at? || saved_change_to_ends_at?
    return unless status == 'cancelled' || status == 'published'
    event_registrations.where(status: 'registered').includes(:user).each do |r|
      Notification.deliver(user: r.user, source_key: "event-#{id}-update-#{lock_version}", title: status == 'cancelled' ? 'Event Cancelled' : 'Event Updated',
        message: "#{title} #{status == 'cancelled' ? 'has been cancelled.' : 'has updated event details. Check the event for its schedule.'}", category: 'events', topic: 'events', icon: 'calendar', href: "/events?event=#{id}")
    end
    request=hosting_request
    if request&.requester&.is_active?
      title=status=='cancelled' ? 'Your Event Was Cancelled' : saved_change_to_status? ? 'Your Event Is Published' : 'Your Event Was Updated'
      Notification.deliver(user:request.requester,source_key:"hosted-event-#{id}-#{lock_version}",title:title,message:"#{self.title}: check the event for the latest details.",category:'events',topic:'events',icon:'calendar',href:'/host-an-event#my-event-requests')
    end
  end
  def meeting_host_allowed
    return if meeting_url.blank?
    hosts = SystemSetting.config['allowed_meeting_hosts']
    return if hosts.empty?

    host = URI.parse(meeting_url).host.to_s.downcase rescue ''
    errors.add(:meeting_url, 'must use an approved meeting provider') unless hosts.any? { |allowed| host == allowed || host.end_with?(".#{allowed}") }
  end

  def end_after_start
    errors.add(:ends_at, "must be after the start time") if starts_at && ends_at && ends_at <= starts_at
  end
end
