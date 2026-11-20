class MentorApplicationSerializer
  def initialize(record) = @record=record
  def as_json(*)
    @record.as_json(only:%i[id form_version full_name contact_email phone_number location gender date_of_birth highest_qualification organization experience_range expertise_tags target_learners terms_accepted status headline background expertise years_of_experience motivation references_text conduct_accepted safeguarding_accepted policy_version submitted_at reviewed_at review_note lock_version updated_at]).merge(
      profile_photo:@record.profile_photo.attached? ? {filename:@record.profile_photo.filename.to_s,size:@record.profile_photo.byte_size,content_type:@record.profile_photo.content_type,uploaded_at:@record.profile_photo.blob.created_at.iso8601(6)} : nil,
      policy_version_current:MentorApplication::POLICY_VERSION,editable:@record.editable?,
      documents:MentorApplication::DOCUMENTS.to_h{|kind|attachment=@record.public_send(kind);[kind,attachment.attached? ? {filename:attachment.filename.to_s,size:attachment.byte_size,content_type:attachment.content_type} : nil]},
      missing_requirements:@record.submission_errors)
  end
end
