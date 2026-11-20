class AddPartnershipDetailsToPublicInquiries < ActiveRecord::Migration[8.1]
  def change
    add_column :public_inquiries, :partnership_details, :jsonb, default: {}, null: false
  end
end
