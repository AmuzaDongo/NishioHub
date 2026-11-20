class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories, id: :integer do |t|
      t.string :name, limit: 100, null: false
      t.boolean :is_active, default: true
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }
      t.datetime :updated_at
    end

    add_index :categories, :name, unique: true
  end
end
