class CreateReportingWorkspace < ActiveRecord::Migration[8.1]
  def change
    [:saved_reports,:report_schedules].each do |table|
      create_table table do |t|
        t.references :user,null:false,foreign_key:true
        t.string :name,null:false,limit:150
        t.string :kind,null:false
        t.jsonb :columns,null:false,default:[]
        t.jsonb :filters,null:false,default:{'period'=>'30'}
        t.integer :lock_version,null:false,default:0
        if table==:report_schedules
          t.string :frequency,null:false,default:'weekly'
          t.string :timezone,null:false
          t.integer :hour,null:false,default:8
          t.integer :minute,null:false,default:0
          t.integer :weekday,null:false,default:1
          t.integer :month_day,null:false,default:1
          t.boolean :active,null:false,default:true
          t.datetime :next_run_at,null:false
          t.datetime :last_run_at
          t.string :last_status
          t.string :last_error,limit:500
        end
        t.timestamps
      end
    end
    add_index :report_schedules,[:active,:next_run_at]
    create_table :report_runs do |t|
      t.references :user,null:false,foreign_key:true
      t.references :report_schedule,foreign_key:{on_delete: :nullify}
      t.string :name,null:false
      t.string :kind,null:false
      t.jsonb :filters,null:false,default:{}
      t.jsonb :columns,null:false,default:[]
      t.string :status,null:false,default:'running'
      t.integer :row_count
      t.string :error,limit:500
      t.datetime :scheduled_for
      t.datetime :finished_at
      t.timestamps
    end
    add_index :report_runs,[:report_schedule_id,:scheduled_for],unique:true,name:'unique_scheduled_report_run'
  end
end
