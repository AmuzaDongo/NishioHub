class GoalAttachment < ApplicationRecord
  include GoalOwned
  has_one_attached :file
  OFFICE={'.docx'=>'application/vnd.openxmlformats-officedocument.wordprocessingml.document','.xlsx'=>'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'}.freeze
  TYPES=(%w[application/pdf text/plain image/jpeg image/png image/webp]+OFFICE.values).freeze
  validates :title,presence:true,length:{maximum:200}
  validates :url,length:{maximum:2048}
  validate do
    errors.add(:base,'Add a file or a link, not both') unless file.attached? ^ url.present?
    if url.present?
      uri=URI.parse(url) rescue nil
      errors.add(:url,'must be an HTTP(S) URL without credentials') unless uri.is_a?(URI::HTTP)&&uri.host.present?&&uri.userinfo.nil?
    end
    if file.attached?
      errors.add(:file,'has an unsupported format') unless TYPES.include?(file.blob.content_type)
      errors.add(:file,'exceeds the platform upload limit') if file.byte_size>[SystemSetting.config['max_upload_mb'],10].min.megabytes
    end
  end
  def self.upload!(file)
    limit=[SystemSetting.config['max_upload_mb'],10].min.megabytes
    raise Administration::Rejected.new('Upload a supported document or image within the platform limit',:unprocessable_entity) unless file.is_a?(ActionDispatch::Http::UploadedFile)&&file.size<=limit
    detected=Marcel::MimeType.for(file.tempfile)
    extension=File.extname(file.original_filename.to_s).downcase
    if OFFICE.key?(extension)
      header=file.tempfile.read(4);file.tempfile.rewind
      raise Administration::Rejected.new('Choose a valid DOCX or XLSX archive',:unprocessable_entity) unless header=="PK\x03\x04".b
      detected=OFFICE[extension]
    elsif extension=='.txt'
      content=file.tempfile.read.force_encoding(Encoding::UTF_8);file.tempfile.rewind
      raise Administration::Rejected.new('Text files must contain UTF-8 text without null bytes',:unprocessable_entity) unless content.valid_encoding?&&!content.include?("\x00")
      detected='text/plain'
    end
    raise Administration::Rejected.new('Choose PDF, DOCX, XLSX, text, JPEG, PNG or WebP',:unprocessable_entity) unless TYPES.include?(detected)
    {io:file.tempfile,filename:file.original_filename,content_type:detected,identify:false}
  end
end
