class AddPublicEventDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :events,:public_details,:jsonb,null:false,default:{}
    add_column :event_speakers,:role,:string,null:false,default:'Speaker'
  end
end
