class ExpandMenteeGoals < ActiveRecord::Migration[8.1]
  def change
    add_column :mentee_goals, :description, :text
    add_column :mentee_goals, :progress, :integer, default: 0, null: false
    add_column :mentee_goals, :target_date, :date
    add_column :mentee_goals, :icon, :string, default: "target", null: false
    add_column :mentee_profiles, :vision, :text
    reversible do |direction|
      direction.up { execute "UPDATE mentee_goals SET progress = 100 WHERE completed = TRUE" }
    end
    add_check_constraint :mentee_goals, "progress >= 0 AND progress <= 100", name: "mentee_goal_progress_range"

    create_table :goal_milestones do |t|
      t.references :mentee_goal, null: false, foreign_key: true
      t.string :title, limit: 200, null: false
      t.date :target_date
      t.boolean :completed, default: false, null: false
      t.timestamps
    end
    create_table :goal_progress_events do |t|
      t.references :mentee_goal, null: false, foreign_key: true
      t.integer :progress, null: false
      t.string :note, limit: 250, null: false
      t.timestamps
    end
  end
end
