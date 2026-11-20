class CreateMentorMentorshipTables < ActiveRecord::Migration[8.1]
  def change
    create_table :mentor_goals do |t|
      t.references :user, null: false, foreign_key: true, type: :integer
      t.string :title, limit: 200, null: false
      t.boolean :completed, default: false, null: false
      t.timestamps
    end
    create_table :mentorship_resources do |t|
      t.references :user, null: false, foreign_key: true, type: :integer
      t.string :title, limit: 200, null: false
      t.string :url, limit: 2000, null: false
      t.timestamps
    end
  end
end
