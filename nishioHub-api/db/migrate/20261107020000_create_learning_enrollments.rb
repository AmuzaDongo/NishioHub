class CreateLearningEnrollments < ActiveRecord::Migration[8.1]
  def change
    create_table :learning_enrollments do |t|
      t.references :user, null: false, foreign_key: true, type: :integer
      t.string :course_key, null: false
      t.jsonb :completed_lesson_ids, default: [], null: false
      t.jsonb :activity_dates, default: [], null: false
      t.timestamps
    end
    add_index :learning_enrollments, [:user_id, :course_key], unique: true
  end
end
