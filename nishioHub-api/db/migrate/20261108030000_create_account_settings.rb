class CreateAccountSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :auth_version, :integer, default: 0, null: false
    create_table :account_settings do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :appearance, default: "light", null: false
      t.boolean :show_online_status, default: true, null: false
      t.boolean :allow_contact_requests, default: true, null: false
      t.string :learning_format, default: "mixed", null: false
      t.integer :weekly_learning_minutes, default: 120, null: false
      t.string :session_preference, default: "online", null: false
      t.string :mentorship_focus, limit: 200, default: "", null: false
      t.timestamps
    end
  end
end
