class NotificationSerializer
  def initialize(notification)
    @notification = notification
  end

  def as_json(*)
    @notification.as_json(only: %i[id title message read category topic icon href created_at])
  end
end
