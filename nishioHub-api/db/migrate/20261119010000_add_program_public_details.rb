class AddProgramPublicDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :platform_programs, :public_details, :jsonb, default: {}, null: false
  end
end
