class ResourceComment < ApplicationRecord
  belongs_to :platform_resource
  belongs_to :user
  before_validation {self.body=body.to_s.strip;self.display_name=display_name.to_s.strip}
  validates :body,length:{minimum:2,maximum:1000}
  validates :display_name,length:{minimum:2,maximum:50}
  validates :status,inclusion:{in:%w[pending approved rejected]}
  validates :submission_key,format:{with:/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i}
  def public_json = as_json(only:%i[id display_name body created_at])
end
