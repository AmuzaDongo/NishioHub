class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :organizer, null: false, foreign_key: { to_table: :users }, type: :integer
      t.string :title, limit: 160, null: false
      t.text :description, null: false
      t.string :category, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :location, limit: 200, null: false
      t.string :meeting_url, limit: 2048
      t.integer :capacity
      t.timestamps
    end
    add_index :events, :starts_at
    create_table :event_registrations do |t|
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true, type: :integer
      t.string :status, null: false, default: "registered"
      t.datetime :attended_at
      t.integer :reminder_minutes, null: false, default: 15
      t.timestamps
    end
    add_index :event_registrations, [:event_id, :user_id], unique: true
    create_table :event_suggestions do |t|
      t.references :user, null: false, foreign_key: true, type: :integer
      t.string :title, limit: 160, null: false
      t.text :description, null: false
      t.string :category, null: false
      t.timestamps
    end
  end
end
