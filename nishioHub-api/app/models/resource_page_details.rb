module ResourcePageDetails
  DEFAULTS={'topic'=>'','license_label'=>'','learning_outcomes'=>[],'takeaways'=>[],'audiences'=>[],
    'author_name'=>'','author_title'=>'','author_bio'=>'','author_photo_url'=>'','author_profile_url'=>''}.freeze
  def self.validate(record)
    raw=record.page_details
    unless raw.is_a?(Hash)&&(raw.keys-DEFAULTS.keys).empty?
      record.errors.add(:page_details,'must be an object containing supported resource page fields');return
    end
    data=DEFAULTS.merge(raw)
    {'topic'=>150,'license_label'=>150,'author_name'=>150,'author_title'=>150,'author_bio'=>1000}.each do |key,length|
      record.errors.add(key,"must be text up to #{length} characters") unless data[key].is_a?(String)&&data[key].length<=length
    end
    %w[author_photo_url author_profile_url].each do |key|
      value=data[key];uri=URI.parse(value.to_s) rescue nil
      record.errors.add(key,'must be an HTTPS URL without credentials, or blank') unless value==''||value.is_a?(String)&&value.length<=2048&&uri.is_a?(URI::HTTPS)&&uri.host.present?&&uri.userinfo.nil?
    end
    {'learning_outcomes'=>[20,300],'takeaways'=>[20,300],'audiences'=>[10,200]}.each do |key,(limit,length)|
      value=data[key]
      record.errors.add(key,"must contain up to #{limit} nonempty entries of #{length} characters") unless value.is_a?(Array)&&value.size<=limit&&value.all?{|text|text.is_a?(String)&&text.strip.present?&&text.length<=length}
    end
  end
end
