class MessageBroadcast < ApplicationRecord
  belongs_to :sender,class_name:'User'
  validates :client_nonce,presence:true,length:{maximum:100}
  validates :title,length:{maximum:150}
  validates :content,presence:true,length:{maximum:4800}
end
