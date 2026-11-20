class AddPublicProgramDiscovery < ActiveRecord::Migration[8.1]
  def change
    add_column :platform_programs, :audience_stages, :jsonb, default: [], null: false
    add_column :platform_programs, :themes, :jsonb, default: [], null: false
    add_column :platform_programs, :featured, :boolean, default: false, null: false
    add_column :public_inquiries, :program_details, :jsonb, default: {}, null: false
  end
end
