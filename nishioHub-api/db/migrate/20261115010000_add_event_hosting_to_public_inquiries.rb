class AddEventHostingToPublicInquiries < ActiveRecord::Migration[8.1]
  def change
    add_column :public_inquiries, :event_details, :jsonb, null: false, default: {}
    add_column :public_inquiries, :submission_key, :string
    add_index :public_inquiries, :submission_key, unique: true
  end
end
