class AddEventRequestApproval < ActiveRecord::Migration[8.1]
  def up
    add_reference :public_inquiries,:requester,type: :integer,foreign_key:{to_table: :users,on_delete: :nullify}
    add_reference :public_inquiries,:reviewer,type: :integer,foreign_key:{to_table: :users,on_delete: :nullify}
    add_reference :public_inquiries,:event,foreign_key:{on_delete: :nullify},index:{unique:true}
    add_column :public_inquiries,:status,:string,null:false,default:'pending'
    add_column :public_inquiries,:review_note,:text,null:false,default:''
    add_column :public_inquiries,:reviewed_at,:datetime
    add_column :public_inquiries,:lock_version,:integer,null:false,default:0
    add_check_constraint :public_inquiries,"status IN ('pending','approved','rejected','changes_requested')",name:'public_inquiries_status'
    execute <<~SQL
      UPDATE public_inquiries SET requester_id=users.id
      FROM users WHERE public_inquiries.category='event_hosting'
      AND public_inquiries.event_details->>'submitted_by_id'=users.id::text
    SQL
  end

  def down
    remove_check_constraint :public_inquiries,name:'public_inquiries_status'
    remove_reference :public_inquiries,:requester,foreign_key:{to_table: :users}
    remove_reference :public_inquiries,:reviewer,foreign_key:{to_table: :users}
    remove_reference :public_inquiries,:event,foreign_key:true
    remove_column :public_inquiries,:status
    remove_column :public_inquiries,:review_note
    remove_column :public_inquiries,:reviewed_at
    remove_column :public_inquiries,:lock_version
  end
end
