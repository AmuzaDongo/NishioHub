class AddAccountProfileFields < ActiveRecord::Migration[8.1]
  def change
    add_column :users,:bio,:text
    add_column :users,:location,:string,limit:150
    add_column :users,:website,:string,limit:2048
  end
end
