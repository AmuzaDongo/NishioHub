class CreateMentorProfilesAndSkills < ActiveRecord::Migration[8.0]
  def change
    create_table :mentor_profiles, id: :integer do |t|
      t.integer :user_id, null: false
      t.string :title, limit: 150
      t.integer :years_of_experience, default: 0, null: false
      t.jsonb :languages, default: [], null: false
      t.jsonb :education, default: [], null: false
      t.jsonb :experience, default: [], null: false
      t.decimal :hourly_rate, precision: 10, scale: 2
      t.boolean :accepting_bookings, default: true, null: false
      t.boolean :is_verified, default: false, null: false
      t.timestamps
    end
    add_index :mentor_profiles, :user_id, unique: true
    add_foreign_key :mentor_profiles, :users

    create_table :skills, id: :integer do |t|
      t.string :name, limit: 100, null: false
      t.timestamps
    end
    add_index :skills, :name, unique: true

    create_table :mentor_skills, id: :integer do |t|
      t.integer :mentor_profile_id, null: false
      t.integer :skill_id, null: false
      t.timestamps
    end
    add_index :mentor_skills, [:mentor_profile_id, :skill_id], unique: true
    add_index :mentor_skills, :skill_id
    add_foreign_key :mentor_skills, :mentor_profiles
    add_foreign_key :mentor_skills, :skills
  end
end
