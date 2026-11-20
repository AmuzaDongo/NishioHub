class AddMenteeDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :mentee_profiles, :education, :string, limit: 200
    add_column :mentee_profiles, :interests, :jsonb, null: false, default: []
    create_table :platform_resource_accesses do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :platform_resource, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.timestamps
    end
    add_index :platform_resource_accesses, [:user_id, :created_at]
    add_check_constraint :platform_resource_accesses, "kind IN ('download', 'link')", name: 'resource_access_kind'
  end
end
