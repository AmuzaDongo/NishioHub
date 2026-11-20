class MessagingPreference < ApplicationRecord
  belongs_to :user
  validates :notify_messages,:send_read_receipts,:enter_to_send,inclusion:{in:[true,false]}
end
