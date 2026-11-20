class CreateDashboardOperations < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_programs do |t|
      t.string :title, null: false, limit: 150
      t.text :description, null: false, default: ''
      t.string :status, null: false, default: 'active'
      t.date :starts_on
      t.date :ends_on
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    create_table :program_memberships do |t|
      t.references :platform_program, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end
    add_index :program_memberships, [:platform_program_id, :user_id], unique: true
    add_reference :bookings, :platform_program, foreign_key: true
    create_table :platform_resources do |t|
      t.string :title, null: false, limit: 200
      t.text :description, null: false, default: ''
      t.string :url, limit: 2048
      t.boolean :published, null: false, default: true
      t.references :platform_program, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
  end
end
