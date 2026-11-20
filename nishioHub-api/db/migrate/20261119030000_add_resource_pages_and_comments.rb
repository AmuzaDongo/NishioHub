class AddResourcePagesAndComments < ActiveRecord::Migration[8.1]
  def change
    add_column :platform_resources, :page_details, :jsonb, default: {}, null: false
    add_column :resource_contents, :public_listing, :boolean, default: false, null: false
    reversible do |direction|
      direction.up do
        remove_check_constraint :platform_resource_accesses, name:'resource_access_kind'
        add_check_constraint :platform_resource_accesses, "kind IN ('download','link','view')", name:'resource_access_kind'
      end
      direction.down do
        execute "UPDATE platform_resource_accesses SET kind='link' WHERE kind='view'"
        remove_check_constraint :platform_resource_accesses, name:'resource_access_kind'
        add_check_constraint :platform_resource_accesses, "kind IN ('download','link')", name:'resource_access_kind'
      end
    end
    create_table :resource_comments do |t|
      t.references :platform_resource, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :display_name, null: false
      t.text :body, null: false
      t.string :status, null: false, default: 'pending'
      t.string :submission_key, null: false
      t.integer :lock_version, null: false, default: 0
      t.datetime :reviewed_at
      t.timestamps
    end
    add_index :resource_comments, [:user_id,:platform_resource_id,:submission_key], unique: true, name:'index_resource_comment_submissions'
    add_index :resource_comments, [:platform_resource_id,:status,:created_at], name:'index_resource_comment_publication'
    add_check_constraint :resource_comments, "status IN ('pending','approved','rejected')", name:'resource_comment_status'
  end
end
