class CreateUserAdministration < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :affiliation, :string, limit: 150, default: '', null: false
    add_column :users, :lock_version, :integer, default: 0, null: false
    add_column :roles, :description, :string, limit: 300, default: '', null: false
    add_column :roles, :permissions, :jsonb
    add_column :roles, :lock_version, :integer, default: 0, null: false
    create_table :user_role_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
      t.timestamps
    end
    add_index :user_role_assignments, [:user_id, :role_id], unique: true
    create_table :administration_audits do |t|
      t.references :actor, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :actor_name, null: false
      t.string :action, null: false
      t.string :target_type, null: false
      t.bigint :target_id
      t.jsonb :changeset, null: false, default: {}
      t.datetime :created_at, null: false
    end
  end
end
