class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users, id: :integer do |t|
      t.string :full_name, limit: 100, null: false
      t.string :email, limit: 100, null: false
      t.string :hashed_password, limit: 128, null: false
      t.boolean :is_active, default: true
      t.boolean :is_verified, default: false
      t.integer :role_id
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }
      t.datetime :updated_at
    end

    add_index :users, :email, unique: true
    add_foreign_key :users, :roles, column: :role_id
  end
end
