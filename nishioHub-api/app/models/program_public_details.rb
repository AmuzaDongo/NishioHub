module ProgramPublicDetails
  DEFAULTS={'benefits'=>[],'curriculum'=>[],'requirements'=>[],'faqs'=>[],'schedule'=>[],
    'duration_label'=>'','cost_label'=>'','certificate_label'=>'','intro_video_url'=>''}.freeze

  def self.https_url?(value,video:false)
    uri=URI.parse(value) rescue nil
    uri.is_a?(URI::HTTPS)&&uri.host.present?&&uri.userinfo.nil?&&value.length<=2048&&(!video||uri.path.match?(/\.(mp4|webm)\z/i))
  end

  def self.validate(record)
    raw=record.public_details
    unless raw.is_a?(Hash)&&(raw.keys-DEFAULTS.keys).empty?
      record.errors.add(:public_details,'must be an object containing supported public fields')
      return
    end
    data=DEFAULTS.merge(raw)
    %w[duration_label cost_label certificate_label].each do |key|
      value=data[key]
      record.errors.add(key,'must be text up to 200 characters') unless value.is_a?(String)&&value.length<=200
    end
    video=data['intro_video_url']
    record.errors.add(:intro_video_url,'must be an HTTPS MP4 or WebM URL, or blank') unless video==''||(video.is_a?(String)&&https_url?(video,video:true))
    {'benefits'=>[12,120],'requirements'=>[20,300]}.each do |key,(limit,length)|
      value=data[key]
      record.errors.add(key,"must contain up to #{limit} nonempty text entries") unless value.is_a?(Array)&&value.size<=limit&&value.all?{|item|item.is_a?(String)&&item.strip.present?&&item.length<=length}
    end
    {'curriculum'=>[24,{'title'=>120,'description'=>1000,'image_url'=>2048}],
      'faqs'=>[20,{'question'=>200,'answer'=>1000}],
      'schedule'=>[20,{'title'=>120,'description'=>500}]}.each do |key,(limit,fields)|
      value=data[key]
      valid=value.is_a?(Array)&&value.size<=limit&&value.all? do |item|
        item.is_a?(Hash)&&(item.keys-fields.keys).empty?&&fields.all? do |field,length|
          text=item[field]
          if field=='image_url'
            text.nil?||text==''||(text.is_a?(String)&&https_url?(text))
          else
            text.is_a?(String)&&text.strip.present?&&text.length<=length
          end
        end
      end
      record.errors.add(key,"must contain up to #{limit} valid entries") unless valid
    end
  end
end
