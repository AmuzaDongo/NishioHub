class ExpandLearningResources < ActiveRecord::Migration[8.1]
  def up
    add_column :platform_resources, :resource_type, :string, default: 'link', null: false
    add_column :platform_resources, :archived, :boolean, default: false, null: false
    add_column :platform_resources, :tags, :jsonb, default: [], null: false
    execute <<~SQL
      UPDATE platform_resources SET resource_type = CASE WHEN b.content_type LIKE 'video/%' THEN 'video' WHEN b.content_type LIKE 'image/%' OR b.content_type LIKE 'audio/%' THEN 'other' ELSE 'document' END
      FROM active_storage_attachments a JOIN active_storage_blobs b ON b.id = a.blob_id
      WHERE a.record_type = 'PlatformResource' AND a.name = 'file' AND platform_resources.id = a.record_id
    SQL
    add_index :platform_resources, [:resource_type, :published, :archived]
  end
  def down
    remove_index :platform_resources, [:resource_type, :published, :archived]
    remove_column :platform_resources, :resource_type
    remove_column :platform_resources, :archived
    remove_column :platform_resources, :tags
  end
end
