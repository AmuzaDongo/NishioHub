# Application contact snapshots use the form's default country (+256), while
# explicitly international numbers keep their own country code. Account login
# phone values are not changed by this normalization.
module ApplicationPhoneNumber
  FORMAT=/\A\+[1-9]\d{6,14}\z/
  COUNTRY_LENGTHS={ '256'=>9, '254'=>9, '255'=>9, '250'=>9, '1'=>10, '44'=>10 }.freeze
  TRUNK_CODES=%w[256 254 255 250 44].freeze

  def self.normalize(value)
    phone=value.to_s.strip.gsub(/[\s\u00a0().-]/,'')
    return '' if phone.empty?
    phone="+#{phone[2..]}" if phone.start_with?('00')
    unless phone.start_with?('+')
      if phone.match?(/\A0\d{9}\z/)
        phone="+256#{phone[1..]}"
      elsif phone.match?(/\A[1-9]\d{8}\z/)
        phone="+256#{phone}"
      elsif COUNTRY_LENGTHS.any?{|code,length|phone.start_with?(code)&&phone.match?(/\A\d+\z/)&&phone.length==code.length+length}
        phone="+#{phone}"
      end
    end
    TRUNK_CODES.each do |code|
      length=COUNTRY_LENGTHS.fetch(code)
      if phone.start_with?("+#{code}0")&&phone.length==1+code.length+length+1
        phone="+#{code}#{phone[(code.length+2)..]}"
        break
      end
    end
    phone
  end

  def self.prefill(value)
    normalized=normalize(value)
    normalized.match?(FORMAT) ? normalized : ''
  end
end
