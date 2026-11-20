module ResourceLibraryDetails
  CATEGORIES=%w[general academic digital career entrepreneurship mentorship teaching exams research].freeze
  PATHS=%w[primary secondary university career entrepreneurs].freeze
  FORMATS=%w[auto study_material video toolkit career_guide learning_path other].freeze
  LEVELS=%w[all beginner intermediate advanced].freeze
  DEFAULTS={'category'=>'general','learning_paths'=>[],'format'=>'auto','level'=>'all','page_count'=>nil,'featured'=>false}.freeze
  def self.validate(record)
    value=record.library_details
    unless value.is_a?(Hash)&&(value.keys-DEFAULTS.keys).empty?
      record.errors.add(:library_details,'must be an object containing supported library fields');return
    end
    data=DEFAULTS.merge(value)
    {'category'=>CATEGORIES,'format'=>FORMATS,'level'=>LEVELS}.each{|key,options|record.errors.add(key,'is not supported') unless options.include?(data[key])}
    paths=data['learning_paths']
    record.errors.add(:learning_paths,'must contain unique supported learning paths') unless paths.is_a?(Array)&&paths.uniq==paths&&(paths-PATHS).empty?
    pages=data['page_count']
    record.errors.add(:page_count,'must be an integer between 1 and 10000 or blank') unless pages.nil?||pages.is_a?(Integer)&&pages.between?(1,10000)
    record.errors.add(:featured,'must be true or false') unless [true,false].include?(data['featured'])
  end
  def self.format(resource)
    value=resource.library_details.fetch('format','auto')
    return value unless value=='auto'
    {'document'=>'study_material','video'=>'video','course'=>'learning_path'}.fetch(resource.resource_type,'other')
  end
end
