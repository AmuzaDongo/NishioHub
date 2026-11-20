class CreateLearningCertificates < ActiveRecord::Migration[8.1]
  def change
    create_table :learning_certificates do |t|
      t.references :learning_enrollment, null: false, foreign_key: true, index: { unique: true }
      t.string :identifier, null: false
      t.datetime :issued_at, null: false
      t.timestamps
    end
    add_index :learning_certificates, :identifier, unique: true
  end
end
