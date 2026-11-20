class ExpandAdminEvents < ActiveRecord::Migration[8.1]
  def up
    add_reference :events, :platform_program, foreign_key: { on_delete: :nullify }
    add_column :events, :event_type, :string
    execute 'UPDATE events SET event_type = category'
    change_column_default :events, :event_type, 'other'
    change_column_null :events, :event_type, false
    add_column :events, :status, :string, default: 'published', null: false
    add_column :events, :format, :string, default: 'on_site', null: false
    execute "UPDATE events SET format = 'online' WHERE meeting_url IS NOT NULL AND meeting_url <> ''"
    add_column :events, :lock_version, :integer, default: 0, null: false
    add_column :event_registrations, :lock_version, :integer, default: 0, null: false
    add_column :event_registrations, :attendance_status, :string, default: 'unrecorded', null: false
    execute "UPDATE event_registrations SET attendance_status = 'present' WHERE attended_at IS NOT NULL"
    add_index :events, [:status, :starts_at]
  end
  def down
    remove_index :events, [:status, :starts_at]
    remove_reference :events, :platform_program, foreign_key: true
    %i[event_type status format lock_version].each { |c| remove_column :events, c }
    %i[attendance_status lock_version].each { |c| remove_column :event_registrations, c }
  end
end
