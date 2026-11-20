class CreateMenteeDashboardTables < ActiveRecord::Migration[8.1]
  def change
    create_table :mentee_profiles do |t|
      t.references :user, null: false, foreign_key: true, type: :integer, index: { unique: true }
      t.string :school, limit: 150
      t.string :grade, limit: 50
      t.string :location, limit: 150
      t.text :bio
      t.timestamps
    end

    create_table :mentee_goals do |t|
      t.references :user, null: false, foreign_key: true, type: :integer
      t.string :title, limit: 200, null: false
      t.boolean :completed, default: false, null: false
      t.timestamps
    end
  end
end
