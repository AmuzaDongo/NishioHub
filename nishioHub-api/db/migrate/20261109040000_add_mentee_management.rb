class AddMenteeManagement < ActiveRecord::Migration[8.1]
  def change
    add_column :mentee_profiles, :management_status, :string, null: false, default: 'active'
    add_column :mentee_profiles, :lock_version, :integer, null: false, default: 0
    add_reference :mentee_profiles, :assigned_mentor, foreign_key: { to_table: :users, on_delete: :nullify }
    add_reference :mentee_profiles, :primary_program, foreign_key: { to_table: :platform_programs, on_delete: :nullify }
    add_check_constraint :mentee_profiles, "management_status IN ('active', 'inactive', 'graduated', 'suspended')", name: 'mentee_management_status'
  end
end
