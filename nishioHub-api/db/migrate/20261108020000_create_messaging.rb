class CreateMessaging < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :last_active_at, :datetime
    create_table :conversations do |t|
      t.references :creator, null: false, foreign_key: { to_table: :users }, type: :integer
      t.string :kind, null: false, default: "direct"
      t.string :title, limit: 150
      t.string :direct_key
      t.datetime :last_message_at
      t.timestamps
    end
    add_index :conversations, :direct_key, unique: true
    create_table :conversation_memberships do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true, type: :integer
      t.bigint :last_read_message_id, null: false, default: 0
      t.timestamps
    end
    add_index :conversation_memberships, [:conversation_id, :user_id], unique: true, name: "index_memberships_on_conversation_and_user"
    create_table :chat_messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.references :sender, null: false, foreign_key: { to_table: :users }, type: :integer
      t.text :content
      t.string :client_nonce, limit: 100
      t.timestamps
    end
    add_index :chat_messages, [:conversation_id, :sender_id, :client_nonce], unique: true, name: "index_chat_messages_on_client_nonce"
  end
end
