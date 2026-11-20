require 'test_helper'
class ApplicationPhoneNumberTest < ActiveSupport::TestCase
  test 'local and formatted international contact numbers normalize without repeating country codes' do
    {
      '0772345678'=>'+256772345678', '0772 345 678'=>'+256772345678',
      '772345678'=>'+256772345678', '256772345678'=>'+256772345678',
      '+256 772 345 678'=>'+256772345678', '+256 (0) 772-345-678'=>'+256772345678',
      '00256 772 345 678'=>'+256772345678', '+254 712 345 678'=>'+254712345678',
      '254712345678'=>'+254712345678', '+44 (0) 7700 900123'=>'+447700900123',
      '0049 151 23456789'=>'+4915123456789', '+1 (415) 555-0123'=>'+14155550123',
      ''=>'', '  '=>''
    }.each{|input,expected|assert_equal expected,ApplicationPhoneNumber.normalize(input),input}
  end
  test 'unusable account values do not block draft creation and invalid updates remain invalid' do
    %w[123 not-a-phone ++256772345678 4155550123].each do |value|
      assert_empty ApplicationPhoneNumber.prefill(value),value
      assert_not ApplicationPhoneNumber.normalize(value).match?(ApplicationPhoneNumber::FORMAT),value
    end
  end
end
