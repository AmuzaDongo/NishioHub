class CreateRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :roles, id: :integer do |t|
      t.string :name, limit: 50, null: false
    end

    add_index :roles, :name, unique: true
  end
end
