module MessagingDelivery
  def self.people!(actor,ids)
    people=User.where(id:ids,is_active:true).includes(:account_setting).to_a
    known=ConversationMembership.where(conversation_id:actor.conversation_memberships.select(:conversation_id)).pluck(:user_id)
    unless people.size==ids.size&&people.none?{|u|MessagingBlock.between?(actor.id,u.id)||u.account_setting&.allow_contact_requests==false&&!known.include?(u.id)}
      raise Administration::Rejected.new('One or more recipients are unavailable or are not accepting messages',:unprocessable_entity)
    end
    people
  end
  def self.direct!(actor,recipient)
    User.where(id:[actor.id,recipient.id].sort).order(:id).lock.load
    people!(actor,[recipient.id])
    key=[actor.id,recipient.id].sort.join(':')
    conversation=Conversation.find_or_create_by!(direct_key:key){|c|c.creator=actor;c.kind='direct'}
    [actor,recipient].each{|u|conversation.conversation_memberships.find_or_create_by!(user:u)}
    conversation.conversation_memberships.find_by!(user:actor).update!(deleted_at:nil)
    conversation
  end
end
