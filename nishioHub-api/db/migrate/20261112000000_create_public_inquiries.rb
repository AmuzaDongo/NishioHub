class CreatePublicInquiries < ActiveRecord::Migration[8.1]
  def change
    create_table :public_inquiries do |t|
      t.string :reference,null:false
      t.string :name,null:false,limit:150
      t.string :email,null:false,limit:254
      t.string :subject,null:false,limit:150
      t.string :category,null:false
      t.text :message,null:false
      t.string :ip_digest,null:false
      t.boolean :reviewed,null:false,default:false
      t.timestamps
    end
    add_index :public_inquiries,:reference,unique:true
    add_index :public_inquiries,[:ip_digest,:created_at]
  end
end
