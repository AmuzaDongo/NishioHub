class Api::V1::NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    render json: current_user.notifications.order(created_at: :desc, id: :desc).limit(100).map { |notification| NotificationSerializer.new(notification).as_json }
  end

  def workspace
    SyncUserNotifications.new(current_user).call if current_user.has_role?('mentee')
    scope = current_user.notifications
    counts = scope.group(:category).count
    filtered = scope
    filtered = filtered.where(category: params[:category]) if Notification::CATEGORIES.include?(params[:category])
    if params[:q].present?
      search = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(200))}%"
      filtered = filtered.where("title ILIKE :q OR message ILIKE :q", q: search)
    end
    filtered = filtered.where(read: false) if params[:unread] == "true"
    page = [[params.fetch(:page, 1).to_i, 1].max, 10000].min
    total = filtered.count
    notifications = filtered.order(created_at: :desc, id: :desc).offset((page - 1) * 30).limit(30)
    render json: {
      name: current_user.full_name, avatar: current_user.avatar_url,
      notifications: notifications.map { |notification| NotificationSerializer.new(notification).as_json },
      counts: { all: counts.values.sum, mentorship: counts.fetch("mentorship", 0), learning: counts.fetch("learning", 0),
        events: counts.fetch("events", 0), system: counts.fetch("system", 0), unread: scope.where(read: false).count },
      preferences: preferences_json,
      meta: { page: page, total: total, total_pages: (total / 30.0).ceil }
    }
  end

  def unread_count
    SyncUserNotifications.new(current_user).call if current_user.has_role?('mentee')
    render json: { unread: current_user.notifications.where(read: false).count }
  end

  def create
    return render_error('New notifications are paused', :forbidden) unless SystemSetting.config['notifications_enabled']
    notification = current_user.notifications.create!(params.permit(:title, :message))
    render json: NotificationSerializer.new(notification).as_json, status: :created
  end

  def update
    notification = current_user.notifications.find(params[:id])
    notification.update!(params.require(:notification).permit(:read))
    render json: NotificationSerializer.new(notification).as_json
  end

  def read_all
    current_user.notifications.where(read: false).update_all(read: true, updated_at: Time.current)
    render json: { unread: 0 }
  end

  def preferences
    render json: preferences_json
  end

  def update_preferences
    current_user.with_lock do
      preference = current_user.notification_preference || current_user.build_notification_preference
      preference.update!(params.require(:preferences).permit(*NotificationPreference::TOPICS))
    end
    render json: preferences_json
  end

  private

  def preferences_json
    preference = current_user.notification_preference
    NotificationPreference::TOPICS.index_with { |topic| preference ? preference.public_send(topic) : true }
  end
end
