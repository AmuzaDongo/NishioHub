class AddPublicEventDiscovery < ActiveRecord::Migration[8.1]
  def change
    add_column :events,:target_audiences,:jsonb,null:false,default:[]
    add_column :events,:public_featured,:boolean,null:false,default:false
    add_column :events,:public_recording_url,:string,limit:2048
  end
end
