class CreateResourceDetails < ActiveRecord::Migration[8.1]
  def change
    change_table :platform_resources do |t|
      t.string :language, default: 'en', null: false
      t.string :target_audience, limit: 500
      t.string :module_name, limit: 200
      t.integer :position
      t.boolean :required, default: false, null: false
      t.string :awards, limit: 500
      t.integer :duration_seconds
      t.string :visibility, default: 'platform', null: false
      t.datetime :published_at
      t.datetime :deleted_at
    end
    create_table :resource_contents do |t|
      t.references :platform_resource, null: false, foreign_key: { on_delete: :cascade }
      t.string :title, limit: 200, null: false
      t.text :body
      t.string :url, limit: 2048
      t.integer :position, default: 1, null: false
      t.integer :start_seconds
      t.integer :lock_version, default: 0, null: false
      t.timestamps
    end
    create_table :resource_program_shares do |t|
      t.references :platform_resource, null: false, foreign_key: { on_delete: :cascade }
      t.references :platform_program, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :resource_program_shares, [:platform_resource_id, :platform_program_id], unique: true, name: 'resource_program_share_unique'
    create_table :resource_progresses do |t|
      t.references :platform_resource, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :percent, default: 0, null: false
      t.datetime :completed_at
      t.integer :lock_version, default: 0, null: false
      t.timestamps
    end
    add_index :resource_progresses, [:platform_resource_id, :user_id], unique: true
    add_check_constraint :resource_progresses, 'percent BETWEEN 0 AND 100', name: 'resource_progress_range'
    create_table :resource_feedbacks do |t|
      t.references :platform_resource, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.integer :rating, null: false
      t.text :comment, null: false
      t.timestamps
    end
    add_index :resource_feedbacks, [:platform_resource_id, :user_id], unique: true
    add_check_constraint :resource_feedbacks, 'rating BETWEEN 1 AND 5', name: 'resource_feedback_rating_range'
    create_table :resource_versions do |t|
      t.references :platform_resource, null: false, foreign_key: { on_delete: :cascade }
      t.references :actor, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :actor_name, null: false
      t.integer :number, null: false
      t.jsonb :snapshot, default: {}, null: false
      t.timestamps
    end
    add_index :resource_versions, [:platform_resource_id, :number], unique: true
  end
end
