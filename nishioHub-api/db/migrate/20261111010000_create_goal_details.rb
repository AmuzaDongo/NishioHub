class CreateGoalDetails < ActiveRecord::Migration[8.1]
  def up
    [:mentee_goals,:mentor_goals,:program_goals].each do |table|
      add_column table,:priority,:string,default:'medium',null:false
      add_column table,:completed_at,:datetime
      kind=table.to_s.delete_suffix('s')
      execute <<~SQL
        WITH history AS (
          SELECT #{kind}_id AS goal_id, progress, note, created_at, id,
            LAG(progress) OVER (PARTITION BY #{kind}_id ORDER BY created_at,id) AS prior_progress
          FROM goal_progress_events WHERE #{kind}_id IS NOT NULL
        ), completions AS (
          SELECT DISTINCT ON (goal_id) goal_id, created_at FROM history
          WHERE progress=100 AND (prior_progress<100 OR (prior_progress IS NULL AND note='Goal created'))
          ORDER BY goal_id,created_at DESC,id DESC
        )
        UPDATE #{table} goal SET completed_at=completions.created_at
        FROM completions WHERE goal.id=completions.goal_id AND goal.progress=100
      SQL
    end
    [:goal_updates,:goal_attachments].each do |table|
      create_table table do |t|
        t.references :mentee_goal,foreign_key:true
        t.references :mentor_goal,foreign_key:true
        t.references :program_goal,foreign_key:true
        t.references :author,foreign_key:{to_table: :users,on_delete: :nullify}
        t.string :author_name,null:false
        t.integer :lock_version,default:0,null:false
        t.boolean :is_active,default:true,null:false
        if table==:goal_updates
          t.text :body,null:false
        else
          t.string :title,null:false
          t.string :url
        end
        t.timestamps
      end
      add_check_constraint table,'num_nonnulls(mentee_goal_id,mentor_goal_id,program_goal_id)=1',name:"#{table}_one_goal"
    end
  end
  def down
    drop_table :goal_updates
    drop_table :goal_attachments
    [:mentee_goals,:mentor_goals,:program_goals].each do |table|
      remove_column table,:priority
      remove_column table,:completed_at
    end
  end
end
