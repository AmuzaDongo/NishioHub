class CreateAdminAchievements < ActiveRecord::Migration[8.1]
  def change
    create_table :achievement_definitions do |t|
      t.string :title,null:false
      t.text :description
      t.text :criteria
      t.string :kind,null:false
      t.string :icon,null:false,default:'trophy'
      t.string :color,null:false,default:'purple'
      t.boolean :is_active,null:false,default:true
      t.integer :lock_version,null:false,default:0
      t.timestamps
    end
    create_table :achievement_awards do |t|
      t.references :achievement_definition,null:false,foreign_key:true
      t.references :user,null:false,foreign_key:true
      t.references :platform_program,foreign_key:true
      t.references :issuer,foreign_key:{to_table: :users,on_delete: :nullify}
      t.string :issuer_name,null:false
      t.string :identifier,null:false
      t.string :title,null:false
      t.text :description
      t.string :kind,null:false
      t.string :icon,null:false
      t.string :color,null:false
      t.datetime :awarded_at,null:false
      t.datetime :revoked_at
      t.text :revocation_reason
      t.integer :lock_version,null:false,default:0
      t.timestamps
    end
    add_index :achievement_awards,:identifier,unique:true
    add_index :achievement_awards,[:achievement_definition_id,:user_id],unique:true,where:'revoked_at IS NULL',name:'one_active_achievement_per_learner'
    add_index :achievement_awards,:awarded_at
  end
end
