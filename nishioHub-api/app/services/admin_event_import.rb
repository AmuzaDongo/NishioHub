require 'csv'
class AdminEventImport
  HEADERS = %w[title description event_type program_id starts_at ends_at format location meeting_url capacity status].freeze
  attr_reader :validated_rows
  def initialize(file, actor)
    @actor = actor
    raise Administration::Rejected.new('Upload a UTF-8 CSV up to 256 KB',:unprocessable_entity) unless file.is_a?(ActionDispatch::Http::UploadedFile) && file.size<=256.kilobytes
    text=file.read.force_encoding(Encoding::UTF_8).sub(/\A\uFEFF/,'')
    raise ArgumentError unless text.valid_encoding?
    @rows=CSV.parse(text,headers:true,skip_blanks:true)
    raise ArgumentError unless @rows.headers&.sort==HEADERS.sort && @rows.size.between?(1,100)
  rescue CSV::MalformedCSVError, ArgumentError
    raise Administration::Rejected.new('Use template headers and include 1–100 events',:unprocessable_entity)
  end
  def preview
    @validated_rows=[];seen=[]
    rows=@rows.each_with_index.map do |row,i|
      data=row.to_h.transform_values{|v|v.to_s.strip};data['platform_program_id']=data.delete('program_id');data['status']=data['status'].presence||'draft';data['event_type']=data['event_type'].presence||'other';data['format']=data['format'].presence||'on_site'
      errors=[]
      begin
        event=AdminEventManagement.build(@actor,data);event.validate!
        key=event.attributes.slice('title','starts_at','event_type','platform_program_id')
        raise Administration::Rejected.new('Duplicate event in this file or already saved',:unprocessable_entity) if seen.include?(key)||Event.exists?(key)
        seen<<key;@validated_rows<<data
      rescue Administration::Rejected,ActiveRecord::RecordInvalid,ActiveRecord::RecordNotFound => e
        errors << (e.is_a?(ActiveRecord::RecordInvalid) ? e.record.errors.full_messages.join(', ') : e.is_a?(ActiveRecord::RecordNotFound) ? 'Choose an active program ID' : e.message)
      end
      {row:i+2,title:data['title'],errors:errors}
    end
    {rows:rows,total:rows.size,ready:validated_rows.size,valid:rows.all?{|r|r[:errors].empty?}}
  end
end
