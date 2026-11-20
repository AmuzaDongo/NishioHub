class CreateSessionDetails < ActiveRecord::Migration[8.1]
  def change
    change_table :bookings do |t|
      t.jsonb :objectives, default: [], null: false
      t.jsonb :session_tags, default: [], null: false
      t.datetime :registration_opens_at
      t.datetime :registration_closes_at
      t.datetime :feedback_opens_at
      t.datetime :feedback_closes_at
    end
    create_table :session_assets do |t|
      t.references :booking, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.string :title, null: false, limit: 200
      t.text :description
      t.string :url, limit: 2048
      t.boolean :is_active, default: true, null: false
      t.integer :lock_version, default: 0, null: false
      t.timestamps
    end
    create_table :session_asset_accesses do |t|
      t.references :session_asset, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :kind, null: false
      t.timestamps
    end
    create_table :session_feedbacks do |t|
      t.references :booking, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :rating, null: false
      t.text :comment, null: false
      t.timestamps
    end
    add_index :session_feedbacks, [:booking_id, :user_id], unique: true
    add_check_constraint :session_feedbacks, 'rating BETWEEN 1 AND 5', name: 'session_feedback_rating_range'
    create_table :session_notes do |t|
      t.references :booking, null: false, foreign_key: { on_delete: :cascade }
      t.references :author, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :author_name, null: false
      t.text :body, null: false
      t.integer :lock_version, default: 0, null: false
      t.timestamps
    end
  end
end
