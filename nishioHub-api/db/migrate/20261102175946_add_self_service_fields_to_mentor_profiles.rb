class AddSelfServiceFieldsToMentorProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :mentor_profiles, :bio, :text
    add_column :mentor_profiles, :currency, :string, limit: 3, default: "USD", null: false
    add_column :mentor_profiles, :timezone, :string, limit: 64, default: "UTC", null: false
    add_column :mentor_profiles, :is_published, :boolean, default: true, null: false
  end
end
