require 'csv'
class AdminResourceImport
  HEADERS = %w[title description resource_type program_id url status tags].freeze
  attr_reader :validated_rows
  def initialize(file)
    raise Administration::Rejected.new('Upload a UTF-8 CSV up to 256 KB', :unprocessable_entity) unless file.is_a?(ActionDispatch::Http::UploadedFile) && file.size <= 256.kilobytes
    text = file.read.force_encoding(Encoding::UTF_8).sub(/\A\uFEFF/, '')
    raise ArgumentError unless text.valid_encoding?
    @rows = CSV.parse(text, headers: true, skip_blanks: true)
    raise ArgumentError unless @rows.headers&.sort == HEADERS.sort && @rows.size.between?(1, 100)
  rescue CSV::MalformedCSVError, ArgumentError
    raise Administration::Rejected.new('Use template headers and include 1–100 resource links', :unprocessable_entity)
  end
  def preview
    @validated_rows = []
    rows = @rows.each_with_index.map do |row, index|
      data = row.to_h.transform_values { |v| v.to_s.strip }
      data['resource_type'] = data['resource_type'].presence || 'link'; data['status'] = data['status'].presence || 'draft'
      data['tags'] = data['tags'].split(';').map(&:strip).reject(&:blank?)
      errors = []
      begin
        program = data['program_id'].present? ? PlatformProgram.active.find(AdminMenteeQuery.positive_id!(data['program_id'])) : nil
        item = PlatformResource.new(data.slice('title', 'description', 'resource_type', 'url', 'tags').merge(platform_program: program).merge(AdminResourceManagement.status_attributes(data['status'])))
        item.type_explicit = true; item.validate!
        data['platform_program_id'] = program&.id
        @validated_rows << data
      rescue Administration::Rejected, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
        errors << (e.is_a?(ActiveRecord::RecordInvalid) ? e.record.errors.full_messages.join(', ') : e.is_a?(ActiveRecord::RecordNotFound) ? 'Choose an existing active program ID' : e.message)
      end
      { row: index + 2, title: data['title'], errors: errors }
    end
    { rows: rows, ready: validated_rows.size, total: rows.size, valid: rows.all? { |r| r[:errors].empty? } }
  end
end
