class CreateMentorApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :mentor_applications do |t|
      t.references :user, null:false, foreign_key:true, index:{unique:true}
      t.string :status, null:false, default:'draft'
      t.string :headline, null:false, default:''
      t.text :background, null:false, default:''
      t.text :expertise, null:false, default:''
      t.integer :years_of_experience, null:false, default:0
      t.text :motivation, null:false, default:''
      t.text :references_text, null:false, default:''
      t.boolean :conduct_accepted, null:false, default:false
      t.boolean :safeguarding_accepted, null:false, default:false
      t.string :policy_version
      t.datetime :submitted_at
      t.datetime :consented_at
      t.references :reviewed_by, foreign_key:{to_table: :users}
      t.datetime :reviewed_at
      t.text :review_note, null:false, default:''
      t.integer :lock_version, null:false, default:0
      t.timestamps
    end
    add_index :mentor_applications, [:status,:submitted_at]
  end
end
