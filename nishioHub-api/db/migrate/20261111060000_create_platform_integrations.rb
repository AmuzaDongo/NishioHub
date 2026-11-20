class CreatePlatformIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :platform_integrations do |t|
      t.string :provider_key,null:false
      t.string :environment,null:false,default:'live'
      t.text :encrypted_credentials
      t.boolean :paused,null:false,default:false
      t.boolean :verified,null:false,default:false
      t.datetime :last_attempt_at
      t.datetime :last_checked_at
      t.string :last_message
      t.integer :last_http_status
      t.references :updated_by,foreign_key:{to_table: :users}
      t.integer :lock_version,null:false,default:0
      t.timestamps
    end
    add_index :platform_integrations,:provider_key,unique:true
    create_table :integration_logs do |t|
      t.string :provider_key,null:false
      t.string :action,null:false
      t.string :outcome,null:false
      t.string :message,null:false
      t.integer :http_status
      t.references :actor,foreign_key:{to_table: :users,on_delete: :nullify}
      t.string :actor_name,null:false
      t.timestamps
    end
    add_index :integration_logs,[:provider_key,:created_at]
  end
end
