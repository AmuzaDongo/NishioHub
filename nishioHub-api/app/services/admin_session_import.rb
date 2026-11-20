require 'csv'
class AdminSessionImport
  HEADERS = %w[title description mentor_id mentee_ids category_id program_id scheduled_at duration format location meeting_url].freeze
  attr_reader :validated_rows
  def initialize(file)
    raise Administration::Rejected.new('Upload a UTF-8 CSV up to 256 KB', :unprocessable_entity) unless file.is_a?(ActionDispatch::Http::UploadedFile) && file.size <= 256.kilobytes
    text = file.read.force_encoding(Encoding::UTF_8).sub(/\A\uFEFF/, '')
    raise ArgumentError unless text.valid_encoding?
    @rows = CSV.parse(text, headers: true, skip_blanks: true)
    raise ArgumentError unless @rows.headers&.sort == HEADERS.sort && @rows.size.between?(1, 100)
  rescue CSV::MalformedCSVError, ArgumentError
    raise Administration::Rejected.new('Use the template headers and include 1–100 sessions', :unprocessable_entity)
  end
  def preview
    @validated_rows = []; planned = []
    rows = @rows.each_with_index.map do |row, index|
      data = row.to_h.transform_values { |v| v.to_s.strip }; data['mentee_ids'] = data['mentee_ids'].split(';').map(&:strip)
      errors = []
      begin
        valid = AdminSessionManagement.validate!(data)
        people = [valid[:attrs][:mentor].id, *valid[:ids]]; starts = valid[:attrs][:scheduled_at]; finish = starts + valid[:attrs][:duration].minutes
        if planned.any? { |p| (people & p[:people]).any? && starts < p[:finish] && finish > p[:starts] }
          errors << 'A participant has overlapping sessions in this CSV'
        end
        planned << { people: people, starts: starts, finish: finish }
      rescue Administration::Rejected, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
        errors << (e.is_a?(ActiveRecord::RecordInvalid) ? e.record.errors.full_messages.join(', ') : e.is_a?(ActiveRecord::RecordNotFound) ? 'Choose existing eligible account, category and program IDs' : e.message)
      end
      @validated_rows << data if errors.empty?
      { row: index + 2, title: data['title'], errors: errors }
    end
    { rows: rows, ready: validated_rows.size, total: rows.size, valid: rows.all? { |r| r[:errors].empty? } }
  end
end
