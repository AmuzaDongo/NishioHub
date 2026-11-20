class AddPrivateNotifications < ActiveRecord::Migration[8.1]
  def change
    # Legacy global rows remain unassigned and are never returned by private feeds.
    add_reference :notifications, :user, foreign_key: true, type: :integer
    add_column :notifications, :category, :string, default: "system", null: false
    add_column :notifications, :topic, :string, default: "platform", null: false
    add_column :notifications, :icon, :string, default: "bell", null: false
    add_column :notifications, :href, :string, default: "/notifications", null: false
    add_column :notifications, :source_key, :string
    add_timestamps :notifications, default: -> { "CURRENT_TIMESTAMP" }, null: false
    add_index :notifications, [:user_id, :source_key], unique: true
    add_index :notifications, [:user_id, :read, :created_at]
    create_table :notification_preferences do |t|
      t.references :user, null: false, foreign_key: true, type: :integer, index: { unique: true }
      t.boolean :mentorship, null: false, default: true
      t.boolean :learning, null: false, default: true
      t.boolean :events, null: false, default: true
      t.boolean :goals, null: false, default: true
      t.boolean :platform, null: false, default: true
      t.timestamps
    end
  end
end
