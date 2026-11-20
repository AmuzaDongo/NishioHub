class Role < ApplicationRecord
  BUILT_INS = %w[admin superadmin mentor mentee moderator organization founder user].freeze
  has_many :users, dependent: :nullify
  has_many :user_role_assignments, dependent: :restrict_with_error
  validates :name, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :description, length: { maximum: 300 }
  validate :permissions_are_known
  validate :protected_name_is_unchanged
  before_destroy :protect_builtin

  def canonical_name
    name.to_s.downcase.gsub(/[ _-]/, '')
  end

  def administrative?
    canonical_name.in?(%w[admin superadmin])
  end

  def builtin?
    BUILT_INS.include?(canonical_name)
  end

  def effective_permissions
    return Administration::PERMISSIONS.keys if canonical_name == 'superadmin'
    return permissions if permissions.is_a?(Array)
    canonical_name == 'admin' ? Administration::PERMISSIONS.keys : []
  end

  private

  def permissions_are_known
    return if permissions.nil?
    unless permissions.is_a?(Array) && permissions.all? { |permission| Administration::PERMISSIONS.key?(permission) }
      errors.add(:permissions, 'must contain only known administration permissions')
    end
  end

  def protected_name_is_unchanged
    return unless persisted? && will_save_change_to_name?
    old_name = name_in_database.to_s.downcase.gsub(/[ _-]/, '')
    errors.add(:name, 'cannot rename a built-in role') if BUILT_INS.include?(old_name)
    errors.add(:name, 'is reserved') if administrative?
  end

  def protect_builtin
    return unless builtin?
    errors.add(:base, 'Built-in roles cannot be deleted')
    throw :abort
  end
end
