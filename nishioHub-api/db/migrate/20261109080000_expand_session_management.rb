class ExpandSessionManagement < ActiveRecord::Migration[8.1]
  def up
    change_table :bookings do |t|
      t.references :session_category, foreign_key: { to_table: :categories }
      t.string :session_title, limit: 100
      t.text :session_description
      t.string :format, default: 'online', null: false
      t.string :location, limit: 500
      t.string :meeting_url, limit: 2048
    end
    create_table :booking_participants do |t|
      t.references :booking, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.boolean :attended
      t.datetime :recorded_at
      t.timestamps
    end
    add_index :booking_participants, [:booking_id, :user_id], unique: true
    execute <<~SQL
      INSERT INTO booking_participants (booking_id, user_id, created_at, updated_at)
      SELECT id, mentee_id, created_at, updated_at FROM bookings
    SQL
  end
  def down
    drop_table :booking_participants
    remove_reference :bookings, :session_category, foreign_key: { to_table: :categories }
    %i[session_title session_description format location meeting_url].each { |column| remove_column :bookings, column }
  end
end
