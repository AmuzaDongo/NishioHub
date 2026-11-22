module HowItWorksContent
  DEFAULTS={
    'heading'=>'How NishioHub Works',
    'description'=>'A simple and powerful way to connect learners, mentors, schools and organizations for learning, guidance and growth.',
    'hero_image'=>'/images/learning/library-hero.webp',
    'overview_video_url'=>'','overview_seconds'=>120,
    'steps'=>[
      {'title'=>'Create Your Account','description'=>'Sign up as a learner or mentor, or contact our team for your school or organization.'},
      {'title'=>'Set Up Your Profile','description'=>'Add your details, interests, skills and goals.'},
      {'title'=>'Discover & Participate','description'=>'Find mentors, join programs, access learning resources and events.'},
      {'title'=>'Learn, Grow & Achieve','description'=>'Get guidance, build your skills, track progress and reach your goals.'}
    ],
    'audiences'=>[
      {'id'=>'learners','title'=>'For Learners','image'=>'/images/programs/young-learners-hero.webp','points'=>['Find a mentor','Access learning resources','Join programs and events','Build career and life skills']},
      {'id'=>'mentors','title'=>'For Mentors','image'=>'/images/onboarding/mentor-hero.webp','points'=>['Share your knowledge','Guide and support learners','Host sessions and events','Build your impact and network']},
      {'id'=>'schools','title'=>'For Schools','image'=>'/images/home/mentorship-hero.webp','points'=>['Connect learners to mentors','Discuss school programs and clubs','Host events on NishioHub','Support learner engagement']},
      {'id'=>'organizations','title'=>'For Organizations','image'=>'/images/partnerships/partnership-hero.webp','points'=>['Partner on learning programs','Sponsor events and initiatives','Provide resources and opportunities','Support talent development']}
    ]
  }.freeze
  def self.https_url?(value)
    uri=URI.parse(value) rescue nil
    value.is_a?(String)&&value.length<=2048&&uri.is_a?(URI::HTTPS)&&uri.host.present?&&uri.userinfo.nil?
  end
  def self.image?(value)
    value.is_a?(String)&&(https_url?(value)||(value.match?(%r{\A/images/[a-zA-Z0-9_./-]+\z})&&!value.include?('..')))
  end
  def self.video?(value)
    return true if value==''
    return false unless https_url?(value)
    uri=URI.parse(value);parts=uri.path.split('/').reject(&:empty?)
    return true if uri.path.match?(/\.(mp4|webm)\z/i)
    if %w[youtube.com www.youtube.com m.youtube.com youtube-nocookie.com www.youtube-nocookie.com youtu.be www.youtu.be].include?(uri.host.downcase)
      id=uri.host.end_with?('youtu.be') ? parts.first : uri.path=='/watch' ? URI.decode_www_form(uri.query.to_s).to_h['v'] : %w[embed shorts live].include?(parts.first) ? parts[1] : nil
      return !!id&.match?(/\A[\w-]{11}\z/)
    end
    %w[vimeo.com www.vimeo.com player.vimeo.com].include?(uri.host.downcase)&&parts.any?{|part|part.match?(/\A\d+\z/)}
  end
  def self.text?(value,max) = value.is_a?(String)&&value.strip.present?&&value.length<=max
  def self.validate(record,data)
    valid=data.is_a?(Hash)&&data.keys.sort==DEFAULTS.keys.sort
    if valid
      valid=text?(data['heading'],100)&&text?(data['description'],500)&&image?(data['hero_image'])&&video?(data['overview_video_url'])&&data['overview_seconds'].is_a?(Integer)&&(1..3600).cover?(data['overview_seconds'])
      valid&&=data['steps'].is_a?(Array)&&data['steps'].length==4&&data['steps'].all?{|s|s.is_a?(Hash)&&s.keys.sort==%w[description title]&&text?(s['title'],80)&&text?(s['description'],250)}
      valid&&=data['audiences'].is_a?(Array)&&data['audiences'].length==4&&data['audiences'].map{|a|a.is_a?(Hash)&&a['id']}==%w[learners mentors schools organizations]&&data['audiences'].all?{|a|a.keys.sort==%w[id image points title]&&text?(a['title'],80)&&image?(a['image'])&&a['points'].is_a?(Array)&&a['points'].length.between?(1,6)&&a['points'].all?{|p|text?(p,150)}}
    end
    record.errors.add(:how_it_works,'must include a heading, description, safe images/video, four steps and four audience cards with valid text') unless valid
  rescue URI::InvalidURIError,ArgumentError
    record.errors.add(:how_it_works,'contains an invalid URL')
  end
end
