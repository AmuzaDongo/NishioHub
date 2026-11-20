require 'csv'
class Api::V1::AdminAchievementsController < ApplicationController
  before_action :require_admin!
  before_action ->{Administration.authorize!(current_user,'dashboard.read')}
  before_action {response.headers['Cache-Control']='private, no-store'}
  def index
    tab=params[:tab].presence||'overview'
    raise Administration::Rejected.new('Invalid achievement section',:unprocessable_entity) unless %w[overview all badges certificates users analytics].include?(tab)
    filters=params.to_unsafe_h.symbolize_keys
    filters[:kind]='certificate' if tab=='certificates'
    query=AdminAchievementQuery.new(filters);scope=query.filtered
    result=query.report(scope).merge(capabilities:{manage:current_user.management_permission?('dashboard.manage')})
    if tab=='users'
      result.merge!(query.people(scope));result[:mode]='people'
    elsif tab=='badges'
      result.merge!(catalog(query,kind:'skill_badge'));result[:mode]='badges'
    else
      result.merge!(items:query.rows(query.ordered(scope).limit(query.size).offset((query.page-1)*query.size)),meta:query.meta(scope.count),mode:'awards')
    end
    render json:result
  end
  def definitions
    query=AdminAchievementQuery.new(params)
    render json:catalog(query,kind:params[:kind])
  end
  def show
    render json:find_row
  end
  def create
    definition=nil;source=object(:definition)
    write do
      definition=AchievementDefinition.create!(source.permit(:title,:description,:criteria,:kind,:icon,:color))
      issue(definition,params[:user_ids],params[:program_id],params[:awarded_on]) if params[:user_ids].present?
      Administration.audit!(current_user,'achievement.definition_created',definition,{title:definition.title,kind:definition.kind})
    end
    render json:{id:definition.id},status: :created
  end
  def update_definition
    source=object(:definition)
    write do
      definition=AchievementDefinition.lock.find(params[:definition_id]);AdminGoalManagement.revision!(definition,source[:lock_version])
      definition.update!(source.permit(:title,:description,:criteria,:icon,:color,:is_active))
      Administration.audit!(current_user,'achievement.definition_updated',definition,source.permit(:title,:is_active).to_h)
    end
    head :no_content
  end
  def award
    write do
      definition=AchievementDefinition.active.lock.find(params[:definition_id]);issue(definition,params[:user_ids],params[:program_id],params[:awarded_on])
    end
    head :no_content
  end
  def revoke
    reason=params[:reason].to_s.strip
    raise Administration::Rejected.new('Provide a revocation reason of 1–2,000 characters',:unprocessable_entity) unless reason.length.between?(1,2000)
    write do
      award=manual_award;award.lock!;AdminGoalManagement.revision!(award,params[:lock_version])
      raise Administration::Rejected.new('This award is already revoked',:conflict) if award.revoked_at
      award.update!(revoked_at:Time.current,revocation_reason:reason)
      Administration.audit!(current_user,'achievement.revoked',award,{reason:reason})
      Notification.deliver(user:award.user,source_key:"achievement-revoked-#{award.id}",title:'Achievement Record Updated',message:"The award “#{award.title}” was revoked: #{reason}",category:'learning',topic:'goals',icon:'medal',href:'/my-achievements')
    end
    head :no_content
  end
  def certificate
    row=find_row
    raise ActiveRecord::RecordNotFound unless row[:kind]=='certificate'&&row[:revoked_at].nil?
    document=if row[:source]=='manual'
      AchievementCertificateDocument.new(manual_award).svg
    else
      LearningCertificateDocument.new(LearningCertificate.find_by!(identifier:row[:certificate_id])).svg
    end
    Administration.audit!(current_user,'achievement.certificate_downloaded',current_user,{award:row[:id]})
    send_data document,type:'image/svg+xml',disposition:'attachment',filename:"nishiohub-#{row[:id]}.svg"
  end
  def export
    query=AdminAchievementQuery.new(params);scope=query.filtered
    if params[:award_ids].present?
      ids=params[:award_ids]
      raise Administration::Rejected.new('Choose 1–100 award identifiers',:unprocessable_entity) unless ids.is_a?(Array)&&ids.size.between?(1,100)&&ids.all?{|id|id.is_a?(String)&&id.length<=150}
      scope=scope.where('achievement_rows.award_key IN (?)',ids.uniq)
    end
    raise Administration::Rejected.new('Filter to at most 10,000 awards before exporting',:unprocessable_entity) if scope.count>10000
    content=CSV.generate do |out|
      out<<%w[id learner email achievement type program awarded_at status issuer revocation_reason]
      (scope.count/100.0).ceil.times do |n|
        query.rows(query.ordered(scope).limit(100).offset(n*100)).each{|r|out<<[r[:id],r.dig(:learner,:name),r.dig(:learner,:email),r[:title],r[:kind],r.dig(:program,:title),r[:awarded_at],r[:revoked_at] ? 'revoked' : 'awarded',r[:issuer],r[:revocation_reason]].map{|v|AdminUserQuery.csv_cell(v)}}
      end
    end
    Administration.audit!(current_user,'achievements.exported',current_user,{count:scope.count})
    send_data content,type:'text/csv; charset=utf-8',filename:'nishiohub-achievements.csv'
  end
  def report
    result=AdminAchievementQuery.new(params).report
    content=CSV.generate do |out|
      out<<%w[metric value]
      result[:stats].except(:changes).each{|k,v|out<<[k,v]}
      result[:distribution].each{|r|out<<[r[:kind],r[:count]]}
      result[:trend].each{|r|out<<[r[:month],r[:count]]}
      result[:top_programs].each{|r|out<<[AdminUserQuery.csv_cell(r[:title]),r[:count]]}
    end
    Administration.audit!(current_user,'achievements.report_exported',current_user,{})
    send_data content,type:'text/csv; charset=utf-8',filename:'nishiohub-achievements-report.csv'
  end
  private
  def object(key)
    source=params.require(key)
    raise Administration::Rejected.new("#{key} must be an object",:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    source
  end
  def write
    Administration.transaction do
      current_user.reload;Administration.authorize!(current_user,'dashboard.read');Administration.authorize!(current_user,'dashboard.manage');yield
    end
  rescue ActiveRecord::RecordNotUnique
    raise Administration::Rejected.new('A selected learner already holds this award. No awards were issued.',:conflict)
  end
  def issue(definition,ids,program_id,awarded_on)
    raise Administration::Rejected.new('Choose 1–100 learners',:unprocessable_entity) unless ids.is_a?(Array)&&ids.size.between?(1,100)&&ids.map(&:to_s).uniq.size==ids.size
    ids=ids.map{|id|AdminMenteeQuery.positive_id!(id)}
    users=User.with_role('mentee').where(id:ids,is_active:true).order(:id).lock.to_a
    raise Administration::Rejected.new('Choose active mentee accounts for every recipient',:unprocessable_entity) unless users.size==ids.size
    program=PlatformProgram.active.find(AdminMenteeQuery.positive_id!(program_id)) if program_id.present?
    date=Time.current
    if awarded_on.present?
      unless awarded_on.is_a?(String)&&awarded_on.match?(/\A\d{4}-\d{2}-\d{2}\z/)&&(parsed=Date.iso8601(awarded_on) rescue nil)
        raise Administration::Rejected.new('Use a valid award date',:unprocessable_entity)
      end
      date=ActiveSupport::TimeZone[SystemSetting.config['timezone']].local(parsed.year,parsed.month,parsed.day)
    end
    users.each do |user|
      award=definition.achievement_awards.create!(user:user,platform_program:program,issuer:current_user,issuer_name:current_user.full_name,awarded_at:date,criteria_snapshot:definition.criteria,**definition.attributes.symbolize_keys.slice(:title,:description,:kind,:icon,:color))
      Administration.audit!(current_user,'achievement.awarded',award,{user_id:user.id,definition_id:definition.id,program_id:program&.id})
      Notification.deliver(user:user,source_key:"achievement-awarded-#{award.id}",title:'New Achievement Awarded!',message:"You earned “#{award.title}”. View it in My Achievements.",category:'learning',topic:'goals',icon:'medal',href:'/my-achievements')
    end
  end
  def manual_award
    match=params[:id].to_s.match(/\Aaward-([0-9a-f-]{36})\z/);raise ActiveRecord::RecordNotFound unless match
    AchievementAward.find_by!(identifier:match[1])
  end
  def find_row
    query=AdminAchievementQuery.new(status:'all');row=query.rows(query.base.where('achievement_rows.award_key=?',params[:id])).first
    raise ActiveRecord::RecordNotFound unless row
    row
  end
  def catalog(query,kind:nil)
    if kind.present?&&kind!='all'&&!AchievementDefinition::KINDS.include?(kind)
      raise Administration::Rejected.new('Invalid achievement type',:unprocessable_entity)
    end
    builtin=AchievementCatalog::BADGES.map do |key,title,description,icon,color|
      "SELECT #{query.quote("builtin-#{key}")} catalog_key,NULL::bigint source_id,#{query.quote(title)} title,#{query.quote(description)} description,#{query.quote(description)} criteria,'skill_badge' kind,#{query.quote(icon)} icon,#{query.quote(color)} color,true is_active,0 lock_version,true automatic"
    end.join(' UNION ALL ')
    custom="SELECT 'definition-'||id::text catalog_key,id source_id,title,description,criteria,kind,icon,color,is_active,lock_version,false automatic FROM achievement_definitions"
    scope=AchievementDefinition.unscoped.from("(#{builtin} UNION ALL #{custom}) catalog_rows").readonly
    scope=scope.where('catalog_rows.kind=?',kind) if kind.present?&&kind!='all'
    if params[:q].present?
      term="%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip.first(150))}%"
      scope=scope.where('catalog_rows.title ILIKE :q OR catalog_rows.description ILIKE :q',q:term)
    end
    scope=scope.where('catalog_rows.is_active=true') unless params[:include_archived]=='true'
    scope=scope.where('catalog_rows.automatic=false') if params[:custom_only]=='true'
    count=scope.count
    counts_query=AdminAchievementQuery.new(params.to_unsafe_h.symbolize_keys.except(:q))
    counts=counts_query.filtered.where('achievement_rows.revoked_at IS NULL').group('achievement_rows.definition_key').count
    items=scope.select('catalog_rows.*').order(Arel.sql('catalog_rows.title ASC,catalog_rows.catalog_key ASC')).limit(query.size).offset((query.page-1)*query.size).map do |r|
      {id:r[:catalog_key],definition_id:r[:source_id],title:r.title,description:r.description,criteria:r.criteria,kind:r.kind,icon:r.icon,color:r.color,active:r.is_active,lock_version:r.lock_version,automatic:r[:automatic],awarded:counts[r[:catalog_key]]||0}
    end
    {items:items,meta:query.meta(count)}
  end
end
