class ExpandMentorApplicationForm < ActiveRecord::Migration[8.1]
  def change
    change_table :mentor_applications do |t|
      t.integer :form_version, null:false, default:1
      t.string :full_name, null:false, default:''
      t.string :contact_email, null:false, default:''
      t.string :phone_number, null:false, default:''
      t.string :location, null:false, default:''
      t.string :gender, null:false, default:''
      t.date :date_of_birth
      t.string :highest_qualification, null:false, default:''
      t.string :organization, null:false, default:''
      t.string :experience_range, null:false, default:''
      t.jsonb :expertise_tags, null:false, default:[]
      t.jsonb :target_learners, null:false, default:[]
      t.boolean :terms_accepted, null:false, default:false
    end
  end
end
