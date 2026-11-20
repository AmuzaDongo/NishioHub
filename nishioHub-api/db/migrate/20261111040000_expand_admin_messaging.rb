class ExpandAdminMessaging < ActiveRecord::Migration[8.1]
  def change
    add_reference :conversations,:platform_program,foreign_key:true
    add_column :conversations,:cohort_label,:string,limit:150
    [:starred,:archived,:muted].each{|name|add_column :conversation_memberships,name,:boolean,default:false,null:false}
    add_column :conversation_memberships,:deleted_at,:datetime
    add_column :conversation_memberships,:deleted_through_message_id,:bigint,default:0,null:false
    add_column :conversation_memberships,:lock_version,:integer,default:0,null:false
    create_table :messaging_blocks do |t|
      t.references :blocker,null:false,foreign_key:{to_table: :users}
      t.references :blocked,null:false,foreign_key:{to_table: :users}
      t.timestamps
    end
    add_index :messaging_blocks,[:blocker_id,:blocked_id],unique:true
    create_table :messaging_preferences do |t|
      t.references :user,null:false,foreign_key:true,index:{unique:true}
      t.boolean :notify_messages,null:false,default:true
      t.boolean :send_read_receipts,null:false,default:true
      t.boolean :enter_to_send,null:false,default:true
      t.integer :lock_version,null:false,default:0
      t.timestamps
    end
    create_table :message_broadcasts do |t|
      t.references :sender,null:false,foreign_key:{to_table: :users}
      t.string :client_nonce,null:false,limit:100
      t.string :title,limit:150
      t.text :content,null:false
      t.jsonb :recipient_ids,null:false,default:[]
      t.jsonb :conversation_ids,null:false,default:[]
      t.timestamps
    end
    add_index :message_broadcasts,[:sender_id,:client_nonce],unique:true
  end
end
