class ExpandProgramManagement < ActiveRecord::Migration[8.1]
  def up
    add_reference :platform_programs, :category, foreign_key: { on_delete: :nullify }
    add_column :platform_programs, :icon, :string, null: false, default: 'graduation'
    add_column :program_memberships, :progress, :integer, null: false, default: 0
    add_column :program_memberships, :completed_at, :datetime
    add_column :program_memberships, :lock_version, :integer, null: false, default: 0
    add_check_constraint :program_memberships, 'progress BETWEEN 0 AND 100', name: 'program_membership_progress'
    create_table :program_mentor_assignments do |t|
      t.references :platform_program, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.boolean :is_active, null: false, default: true
      t.timestamps
    end
    add_index :program_mentor_assignments, [:platform_program_id, :user_id], unique: true, name: 'index_program_mentors_unique'
    execute <<~SQL
      INSERT INTO program_mentor_assignments (platform_program_id, user_id, is_active, created_at, updated_at)
      SELECT pm.platform_program_id, pm.user_id, pm.is_active, pm.created_at, pm.updated_at
      FROM program_memberships pm
      WHERE EXISTS (
        SELECT 1 FROM roles r WHERE LOWER(REPLACE(REPLACE(REPLACE(r.name, '_', ''), '-', ''), ' ', '')) = 'mentor'
        AND (r.id = (SELECT role_id FROM users WHERE id = pm.user_id)
          OR EXISTS (SELECT 1 FROM user_role_assignments ura WHERE ura.user_id = pm.user_id AND ura.role_id = r.id))
      )
    SQL
  end
  def down
    drop_table :program_mentor_assignments
    remove_check_constraint :program_memberships, name: 'program_membership_progress'
    remove_column :program_memberships, :lock_version
    remove_column :program_memberships, :completed_at
    remove_column :program_memberships, :progress
    remove_column :platform_programs, :icon
    remove_reference :platform_programs, :category, foreign_key: true
  end
end
