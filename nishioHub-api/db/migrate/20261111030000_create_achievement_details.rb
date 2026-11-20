class CreateAchievementDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :achievement_awards,:criteria_snapshot,:text
    add_column :achievement_awards,:cohort_label,:string
    add_column :achievement_awards,:final_score,:decimal,precision:5,scale:2
    create_table :achievement_criteria do |t|
      t.references :achievement_award,null:false,foreign_key:true
      t.string :title,null:false
      t.string :category,null:false,default:'other'
      t.integer :completed_units,null:false,default:0
      t.integer :target_units,null:false,default:1
      t.datetime :completed_at
      t.integer :lock_version,null:false,default:0
      t.timestamps
    end
    create_table :achievement_notes do |t|
      t.string :achievement_key,null:false,limit:150
      t.references :author,foreign_key:{to_table: :users,on_delete: :nullify}
      t.string :author_name,null:false
      t.text :body,null:false
      t.boolean :is_active,null:false,default:true
      t.integer :lock_version,null:false,default:0
      t.timestamps
    end
    add_index :achievement_notes,[:achievement_key,:created_at]
    create_table :achievement_goal_links do |t|
      t.string :achievement_key,null:false,limit:150
      t.references :mentee_goal,null:false,foreign_key:true
      t.integer :lock_version,null:false,default:0
      t.timestamps
    end
    add_index :achievement_goal_links,[:achievement_key,:mentee_goal_id],unique:true,name:'unique_achievement_goal_link'
  end
end
