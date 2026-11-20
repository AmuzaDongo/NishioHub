class MakeCategorySlugNotNull < ActiveRecord::Migration[8.0]
  def change
    change_column_null :categories, :slug, false
  end
end
