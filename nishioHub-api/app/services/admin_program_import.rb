require 'csv'
class AdminProgramImport
  HEADERS = %w[title description category status starts_on ends_on icon].freeze
  attr_reader :validated_rows
  def initialize(file)
    raise Administration::Rejected.new('Upload a CSV file up to 256 KB', :unprocessable_entity) unless file.is_a?(ActionDispatch::Http::UploadedFile) && file.size <= 256.kilobytes
    text = file.read.force_encoding(Encoding::UTF_8).sub(/\A\uFEFF/, '')
    raise ArgumentError unless text.valid_encoding?
    @rows = CSV.parse(text, headers: true, skip_blanks: true)
    raise ArgumentError unless @rows.headers&.sort == HEADERS.sort && @rows.size.between?(1, 100)
  rescue CSV::MalformedCSVError, ArgumentError
    raise Administration::Rejected.new('Use the UTF-8 template headers and include 1–100 programs', :unprocessable_entity)
  end
  def preview
    @validated_rows = []
    seen = []
    rows = @rows.each_with_index.map do |row, index|
      values = row.to_h.transform_values { |value| value.to_s.strip }
      category = Category.active.where('LOWER(name) = ?', values['category'].downcase).first if values['category'].present?
      attributes = values.slice('title', 'description').merge('category_id' => category&.id, 'status' => values['status'].presence || 'draft',
        'starts_on' => values['starts_on'].presence, 'ends_on' => values['ends_on'].presence, 'icon' => values['icon'].presence || 'graduation')
      program = PlatformProgram.new(attributes)
      program.valid?
      errors = program.errors.full_messages
      errors << 'Choose an existing active category, or leave it empty' if values['category'].present? && !category
      errors << 'Program title already exists' if PlatformProgram.where('LOWER(title) = ?', values['title'].downcase).exists?
      errors << 'Program title appears more than once in this file' if seen.include?(values['title'].downcase)
      seen << values['title'].downcase
      @validated_rows << attributes if errors.empty?
      { row: index + 2, title: values['title'], category: values['category'], errors: errors }
    end
    { rows: rows, valid: rows.all? { |r| r[:errors].empty? }, ready: validated_rows.size, total: rows.size }
  end
end
