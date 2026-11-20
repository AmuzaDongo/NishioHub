class ResourceProgramShare < ApplicationRecord
  belongs_to :platform_resource
  belongs_to :platform_program
  validates :platform_program_id, uniqueness: { scope: :platform_resource_id }
end
