class CreateLearningLessonCompletions < ActiveRecord::Migration[8.1]
  def change
    create_table :learning_lesson_completions do |t|
      t.references :learning_enrollment, null: false, foreign_key: true
      t.string :lesson_key, null: false
      t.timestamps
    end
    add_index :learning_lesson_completions, [:learning_enrollment_id, :lesson_key], unique: true, name: "index_lesson_completions_on_enrollment_and_lesson"
  end
end
