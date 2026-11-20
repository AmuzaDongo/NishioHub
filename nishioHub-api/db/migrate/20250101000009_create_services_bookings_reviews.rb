class CreateServicesBookingsReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :services, id: :integer do |t|
      t.integer :mentor_id, null: false
      t.integer :category_id, null: false
      t.string :title, limit: 100, null: false
      t.text :description, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :duration, null: false
      t.jsonb :tags, default: [], null: false
      t.string :image_url, limit: 255
      t.boolean :is_active, default: true, null: false
      t.timestamps
    end
    add_index :services, :mentor_id
    add_index :services, :category_id
    add_index :services, :is_active
    add_index :services, :price
    add_foreign_key :services, :users, column: :mentor_id
    add_foreign_key :services, :categories

    create_table :availability_slots, id: :integer do |t|
      t.integer :mentor_id, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.boolean :is_booked, default: false, null: false
      t.timestamps
    end
    add_index :availability_slots, [:mentor_id, :starts_at], unique: true
    add_foreign_key :availability_slots, :users, column: :mentor_id

    create_table :bookings, id: :integer do |t|
      t.integer :service_id, null: false
      t.integer :mentee_id, null: false
      t.integer :mentor_id, null: false
      t.string :status, limit: 20, default: "pending", null: false
      t.datetime :scheduled_at, null: false
      t.integer :duration, null: false
      t.decimal :total_price, precision: 10, scale: 2, null: false
      t.string :payment_status, limit: 20, default: "pending", null: false
      t.timestamps
    end
    add_index :bookings, :mentee_id
    add_index :bookings, :mentor_id
    add_index :bookings, :service_id
    add_index :bookings, :status
    add_index :bookings, :scheduled_at
    add_foreign_key :bookings, :services
    add_foreign_key :bookings, :users, column: :mentee_id
    add_foreign_key :bookings, :users, column: :mentor_id

    create_table :reviews, id: :integer do |t|
      t.integer :booking_id, null: false
      t.integer :service_id, null: false
      t.integer :mentor_id, null: false
      t.integer :mentee_id, null: false
      t.integer :rating, null: false
      t.text :comment, null: false
      t.timestamps
    end
    add_index :reviews, :booking_id, unique: true
    add_index :reviews, :mentor_id
    add_index :reviews, :service_id
    add_foreign_key :reviews, :bookings
    add_foreign_key :reviews, :services
    add_foreign_key :reviews, :users, column: :mentor_id
    add_foreign_key :reviews, :users, column: :mentee_id
  end
end
