class ExpandProgramDetails < ActiveRecord::Migration[8.1]
  def change
    change_table :platform_programs do |t|
      t.integer :capacity
      t.jsonb :objectives, default: [], null: false
      t.string :target_audience, limit: 500
      t.string :delivery_mode, default: 'hybrid', null: false
      t.date :registration_starts_on
      t.date :registration_ends_on
      t.date :evaluation_starts_on
      t.date :evaluation_ends_on
    end
    add_check_constraint :platform_programs, 'capacity IS NULL OR capacity > 0', name: 'program_positive_capacity'
  end
end
