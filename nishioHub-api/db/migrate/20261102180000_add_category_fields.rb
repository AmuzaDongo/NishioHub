class AddCategoryFields < ActiveRecord::Migration[8.0]
  def change
    add_column :categories, :position, :integer, default: 0, null: false
    add_column :categories, :parent_id, :integer
    add_column :categories, :image_alt, :string, limit: 150

    add_index :categories, :position
    add_index :categories, :parent_id
    add_index :categories, :is_active
    add_foreign_key :categories, :categories, column: :parent_id, on_delete: :nullify
  end
end
