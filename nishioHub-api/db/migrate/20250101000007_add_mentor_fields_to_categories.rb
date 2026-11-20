class AddMentorFieldsToCategories < ActiveRecord::Migration[8.0]
  def change
    add_column :categories, :slug, :string, limit: 100
    add_column :categories, :description, :text
    add_column :categories, :icon_path, :string, limit: 255
    add_column :categories, :topics, :jsonb, default: []
    add_index :categories, :slug, unique: true
  end
end
