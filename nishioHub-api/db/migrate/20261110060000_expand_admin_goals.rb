class ExpandAdminGoals < ActiveRecord::Migration[8.1]
  def up
    create_table :program_goals do |t|
      t.references :platform_program, null:false, foreign_key:true
      t.string :title, limit:200, null:false
      t.text :description
      t.integer :progress, default:0, null:false
      t.boolean :completed, default:false, null:false
      t.date :target_date
      t.string :icon, default:'target', null:false
      t.string :category, default:'learning', null:false
      t.string :tracking_status, default:'in_progress', null:false
      t.integer :lock_version, default:0, null:false
      t.datetime :archived_at
      t.timestamps
    end
    [:mentee_goals,:mentor_goals].each do |table|
      add_reference table,:platform_program,foreign_key:{on_delete: :nullify}
      add_column table,:category,:string,default:'learning',null:false
      add_column table,:tracking_status,:string,default:'in_progress',null:false
      add_column table,:lock_version,:integer,default:0,null:false
      add_column table,:archived_at,:datetime
    end
    add_column :mentor_goals,:description,:text
    add_column :mentor_goals,:progress,:integer,default:0,null:false
    add_column :mentor_goals,:target_date,:date
    add_column :mentor_goals,:icon,:string,default:'target',null:false
    execute 'UPDATE mentor_goals SET progress = 100 WHERE completed = TRUE'
    [:mentor_goals,:program_goals].each do |table|
      add_check_constraint table,'progress >= 0 AND progress <= 100',name:"#{table}_progress_range"
    end
    [:goal_progress_events,:goal_milestones].each do |table|
      change_column_null table,:mentee_goal_id,true
      add_reference table,:mentor_goal,foreign_key:true
      add_reference table,:program_goal,foreign_key:true
      add_check_constraint table,'num_nonnulls(mentee_goal_id, mentor_goal_id, program_goal_id) = 1',name:"#{table}_one_goal"
    end
    add_column :goal_progress_events,:actor_name,:string
    add_column :goal_milestones,:lock_version,:integer,default:0,null:false
    [:mentee_goal_id,:mentor_goal_id,:program_goal_id].each { |key| add_index :goal_progress_events,[key,:created_at] }
    execute "INSERT INTO goal_progress_events (mentor_goal_id, progress, note, created_at, updated_at) SELECT id, progress, 'Existing goal baseline recorded', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP FROM mentor_goals"
  end
  def down
    execute 'DELETE FROM goal_progress_events WHERE mentor_goal_id IS NOT NULL OR program_goal_id IS NOT NULL'
    execute 'DELETE FROM goal_milestones WHERE mentor_goal_id IS NOT NULL OR program_goal_id IS NOT NULL'
    [:mentee_goal_id,:mentor_goal_id,:program_goal_id].each { |key| remove_index :goal_progress_events,[key,:created_at] }
    remove_column :goal_progress_events,:actor_name
    remove_column :goal_milestones,:lock_version
    [:goal_progress_events,:goal_milestones].each do |table|
      remove_check_constraint table,name:"#{table}_one_goal"
      remove_reference table,:mentor_goal,foreign_key:true
      remove_reference table,:program_goal,foreign_key:true
      change_column_null table,:mentee_goal_id,false
    end
    remove_check_constraint :mentor_goals,name:'mentor_goals_progress_range'
    [:description,:progress,:target_date,:icon].each { |key| remove_column :mentor_goals,key }
    [:mentee_goals,:mentor_goals].each do |table|
      remove_reference table,:platform_program,foreign_key:true
      [:category,:tracking_status,:lock_version,:archived_at].each { |key| remove_column table,key }
    end
    drop_table :program_goals
  end
end
