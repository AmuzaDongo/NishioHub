class IntegrationLog < ApplicationRecord
  belongs_to :actor,class_name:'User',optional:true
  validates :outcome,inclusion:{in:%w[success warning error]}
end
