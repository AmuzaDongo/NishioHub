class CreateRefreshTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :refresh_tokens, id: :integer do |t|
      t.text :token, null: false
      t.integer :user_id, null: false
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }
      t.datetime :expires_at, null: false
      t.boolean :revoked, default: false
    end

    add_index :refresh_tokens, :token, unique: true
    add_foreign_key :refresh_tokens, :users, on_delete: :cascade
  end
end
