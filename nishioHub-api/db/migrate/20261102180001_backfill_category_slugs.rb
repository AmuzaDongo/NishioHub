class BackfillCategorySlugs < ActiveRecord::Migration[8.0]
  def up
    Category.reset_column_information

    Category.where(slug: [nil, ""]).find_each do |category|
      base = category.name.to_s.parameterize
      candidate = base
      suffix = 2

      while Category.where.not(id: category.id).exists?(slug: candidate)
        candidate = "#{base}-#{suffix}"
        suffix += 1
      end

      category.update_columns(slug: candidate)
    end
  end

  def down
    # Slugs are data; no rollback.
  end
end
