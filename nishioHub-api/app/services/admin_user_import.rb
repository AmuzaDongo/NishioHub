require 'csv'
class AdminUserImport
  HEADERS = %w[full_name email phone_number role affiliation password].freeze
  attr_reader :validated_rows

  def initialize(file, required_role: nil)
    @required_role = required_role
    unless file.is_a?(ActionDispatch::Http::UploadedFile) && file.size <= 256.kilobytes
      raise Administration::Rejected.new('Upload a CSV file up to 256 KB', :unprocessable_entity)
    end
    text = file.read.force_encoding(Encoding::UTF_8).sub(/\A\uFEFF/, '')
    raise Administration::Rejected.new('CSV must use UTF-8 encoding', :unprocessable_entity) unless text.valid_encoding?
    @rows = CSV.parse(text, headers: true, skip_blanks: true)
    unless @rows.headers&.sort == HEADERS.sort && @rows.size.between?(1, 100)
      raise Administration::Rejected.new('Use the template headers and include between 1 and 100 users', :unprocessable_entity)
    end
  rescue CSV::MalformedCSVError, ArgumentError
    raise Administration::Rejected.new('The CSV file could not be read', :unprocessable_entity)
  end

  def preview
    @validated_rows = []
    seen_emails, seen_phones = [], []
    rows = @rows.each_with_index.map do |row, index|
      values = row.to_h.transform_values { |value| value.to_s }
      role = Role.find_by(name: values['role'].strip)
      candidate = User.new(full_name: values['full_name'].strip, email: values['email'].strip.downcase,
        phone_number: values['phone_number'].strip, affiliation: values['affiliation'].strip, role: role, hashed_password: 'validation-only')
      candidate.valid?
      errors = candidate.errors.full_messages
      errors << 'Select an existing non-administrator role' unless role && !role.administrative?
      errors << 'Only Mentee accounts can be imported here' if @required_role && role&.canonical_name != @required_role
      errors << 'Email appears more than once in this file' if seen_emails.include?(candidate.email)
      errors << 'Phone number appears more than once in this file' if seen_phones.include?(candidate.phone_number)
      begin
        AdminUserManagement.password_valid!(values['password'])
      rescue Administration::Rejected => error
        errors << error.message
      end
      seen_emails << candidate.email
      seen_phones << candidate.phone_number
      @validated_rows << candidate.attributes.slice('full_name', 'email', 'phone_number', 'affiliation', 'role_id').merge('password' => values['password']) if errors.empty?
      { row: index + 2, full_name: candidate.full_name, email: candidate.email, role: role&.name || values['role'], errors: errors }
    end
    { rows: rows, valid: rows.all? { |row| row[:errors].empty? }, ready: @validated_rows.size, total: rows.size }
  end
end
