class CreateProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :profiles, id: :integer do |t|
      t.string :phone_number, limit: 20, null: false
      t.string :gender, limit: 10, null: false
      t.date :birth_date, null: false
      t.string :address, limit: 255, null: false
      t.string :city, limit: 100, null: false
      t.string :country, limit: 100, null: false
      t.string :profile_picture, limit: 255
      t.text :bio
      t.integer :user_id, null: false
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }
      t.datetime :updated_at
    end

    add_index :profiles, :phone_number, unique: true
    add_index :profiles, :user_id, unique: true
    add_foreign_key :profiles, :users
  end
end
