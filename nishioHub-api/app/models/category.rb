class Category < ApplicationRecord
  IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  IMAGE_MAX_SIZE = 5.megabytes

  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: :parent_id, dependent: :nullify
  has_many :services, dependent: :restrict_with_error
  has_one_attached :image

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :slug, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :description, length: { maximum: 1000 }, allow_blank: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :parent_must_exist
  validate :parent_is_not_self
  validate :image_content_type
  validate :image_size

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:position, :name) }

  private

  def generate_slug
    base = name.to_s.parameterize
    candidate = base
    suffix = 2

    while Category.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end

    self.slug = candidate
  end

  def parent_must_exist
    return if parent_id.blank?

    errors.add(:parent_id, "does not exist") unless Category.exists?(id: parent_id)
  end

  def parent_is_not_self
    return if parent_id.blank? || id.blank?

    errors.add(:parent_id, "cannot be the category itself") if parent_id == id
  end

  def image_content_type
    return unless image.attached?

    unless image.blob.content_type.in?(IMAGE_CONTENT_TYPES)
      errors.add(:image, "must be a PNG, JPEG, or WebP image")
    end
  end

  def image_size
    return unless image.attached?

    errors.add(:image, "must be smaller than 5 MB") if image.blob.byte_size > IMAGE_MAX_SIZE
  end
end
