class AddPublicLearningLibrary < ActiveRecord::Migration[8.1]
  def change
    add_column :platform_resources, :library_details, :jsonb, default: {}, null: false
    create_table :resource_bookmarks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :platform_resource, null: false, foreign_key: true
      t.timestamps
    end
    add_index :resource_bookmarks, [:user_id, :platform_resource_id], unique: true
  end
end
