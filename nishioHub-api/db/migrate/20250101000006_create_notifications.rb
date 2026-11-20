class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications, id: :integer do |t|
      t.string :title
      t.string :message
      t.boolean :read, default: false
    end
  end
end
