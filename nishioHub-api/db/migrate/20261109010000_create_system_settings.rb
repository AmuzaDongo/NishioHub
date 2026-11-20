class CreateSystemSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :system_settings do |t|
      t.string :key, null: false, default: 'platform'
      t.jsonb :values, null: false, default: {}
      t.integer :lock_version, null: false, default: 0
      t.references :updated_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
    add_index :system_settings, :key, unique: true
    create_table :system_setting_audits do |t|
      t.references :actor, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :actor_name, null: false
      t.string :action, null: false
      t.jsonb :changeset, null: false, default: {}
      t.integer :revision, null: false
      t.datetime :created_at, null: false
    end
    create_table :system_setting_snapshots do |t|
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :label, null: false
      t.jsonb :values, null: false
      t.string :checksum, null: false
      t.integer :revision, null: false
      t.timestamps
    end
    Role.find_or_create_by!(name: 'super_admin')
  end
end
