class Api::V1::PublicProgramsController < ApplicationController
  before_action { response.headers['Cache-Control']='no-store' }

  def index
    stage=params[:stage].to_s;theme=params[:theme].to_s
    reject!('Choose a valid stage') if stage.present?&&!PlatformProgram::AUDIENCE_STAGES.include?(stage)
    reject!('Choose a valid theme') if theme.present?&&!PlatformProgram::THEMES.include?(theme)
    page=params.fetch(:page,'1').to_s
    reject!('Choose a valid page') unless page.match?(/\A[1-9]\d{0,3}\z/)
    reject!('Choose a valid featured filter') if params.key?(:featured)&&!%w[true false].include?(params[:featured].to_s)
    per_page=params.fetch(:per_page,'4').to_s
    reject!('Choose 4, 8 or 12 programs per page') unless %w[4 8 12].include?(per_page)
    per_page=per_page.to_i
    scope=PlatformProgram.active
    scope=scope.where('audience_stages @> ?::jsonb',[stage].to_json) if stage.present?
    scope=scope.where('themes @> ?::jsonb',[theme].to_json) if theme.present?
    q=params[:q].to_s.strip.first(150)
    scope=scope.where('title ILIKE :q OR description ILIKE :q OR target_audience ILIKE :q',q:"%#{ActiveRecord::Base.sanitize_sql_like(q)}%") if q.present?
    scope=scope.where(featured:true) if params[:featured].to_s=='true'
    total=scope.count
    rows=scope.includes(:category).with_attached_banner.order(featured: :desc,title: :asc,id: :asc).offset((page.to_i-1)*per_page).limit(per_page)
    render json:{items:rows.map{|program|serialize(program)},meta:{page:page.to_i,total:total,total_pages:(total/per_page.to_f).ceil},stages:PlatformProgram::AUDIENCE_STAGES,themes:PlatformProgram::THEMES}
  end

  def show
    program=PlatformProgram.active.with_attached_banner.includes(:category).find(params[:id])
    mentors=User.with_role('mentor').where(is_active:true,id:program.program_mentor_assignments.active.select(:user_id))
      .joins(:mentor_profile).where(mentor_profiles:{is_verified:true,is_published:true})
      .includes(:profile,avatar_attachment: :blob,mentor_profile: {avatar_attachment: :blob}).order(:full_name,:id)
    render json:serialize(program).merge(public_details:ProgramPublicDetails::DEFAULTS.merge(program.public_details),
      mentors:mentors.map{|user|{id:user.id,name:user.full_name,title:user.mentor_profile.title,avatar:mentor_portrait(user)}},
      availability:availability(program))
  end

  private
  def mentor_portrait(user)
    attachment=user.mentor_profile.avatar.attached? ? user.mentor_profile.avatar : user.avatar
    attachment.attached? ? rails_storage_proxy_path(attachment.blob,only_path:true) : user.profile&.profile_picture
  end

  def availability(program)
    today=Time.current.in_time_zone(SystemSetting.config.fetch('timezone')).to_date
    status=if program.ends_on&&program.ends_on<today
      'ended'
    elsif program.registration_starts_on&&program.registration_starts_on>today
      'upcoming'
    elsif program.registration_ends_on&&program.registration_ends_on<today
      'closed'
    elsif program.capacity&&program.program_memberships.where(is_active:true,user_id:User.with_role('mentee').select(:id)).count>=program.capacity
      'full'
    else
      'open'
    end
    {status:status,label:{'open'=>'Enrollment Inquiries Welcome','upcoming'=>'Registration Opening Soon','closed'=>'Registration Closed','full'=>'Currently Full','ended'=>'Program Ended'}.fetch(status)}
  end

  def reject!(message) = raise Administration::Rejected.new(message,:unprocessable_entity)
  def serialize(program)
    {id:program.id,title:program.title,description:program.description,image:program.banner_url,category:program.category&.name,
      audience_stages:program.audience_stages,themes:program.themes,featured:program.featured,
      starts_on:program.starts_on,ends_on:program.ends_on,target_audience:program.target_audience,
      mode:program.delivery_mode,objectives:program.objectives,registration_starts_on:program.registration_starts_on,
      registration_ends_on:program.registration_ends_on}
  end
end
