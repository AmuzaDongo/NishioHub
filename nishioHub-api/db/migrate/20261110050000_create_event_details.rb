class CreateEventDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :deleted_at, :datetime
    add_index :events, :deleted_at
    create_table :event_agenda_items do |t|
      t.references :event, null:false, foreign_key:true
      t.string :title, null:false
      t.text :description
      t.datetime :starts_at, null:false
      t.datetime :ends_at, null:false
      t.integer :lock_version, null:false, default:0
      t.timestamps
    end
    create_table :event_speakers do |t|
      t.references :event, null:false, foreign_key:true
      t.string :name, null:false
      t.string :title
      t.text :bio
      t.string :avatar_url
      t.integer :lock_version, null:false, default:0
      t.timestamps
    end
    create_table :event_materials do |t|
      t.references :event, null:false, foreign_key:true
      t.string :title, null:false
      t.text :description
      t.string :url
      t.boolean :is_active, null:false, default:true
      t.integer :lock_version, null:false, default:0
      t.timestamps
    end
    create_table :event_feedbacks do |t|
      t.references :event, null:false, foreign_key:true
      t.references :user, null:false, foreign_key:true
      t.integer :rating, null:false
      t.text :comment
      t.integer :lock_version, null:false, default:0
      t.timestamps
    end
    add_index :event_feedbacks, [:event_id,:user_id], unique:true
  end
end
