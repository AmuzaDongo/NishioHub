require 'csv'
class Api::V1::AdminAchievementDetailsController < ApplicationController
  before_action :require_admin!
  before_action ->{Administration.authorize!(current_user,'dashboard.read')}
  before_action {response.headers['Cache-Control']='private, no-store'}
  def show
    render json:details.as_json.merge(capabilities:{manage:current_user.management_permission?('dashboard.manage'),edit:!!details.award&&details.row[:revoked_at].nil?&&current_user.management_permission?('dashboard.manage')})
  end
  def section
    result=case params[:section]
    when 'notes' then details.note_page(page:page,q:params[:q])
    when 'goals' then details.goal_page(page:page,q:params[:q])
    when 'activity' then details.activities(page:page,q:params[:q])
    when 'criteria'
      items=details.criteria.select{|c|c[:title].to_s.downcase.include?(params[:q].to_s.first(150).downcase)}
      {items:items,meta:{page:1,per_page:100,total:items.size,total_pages:1}}
    else raise Administration::Rejected.new('Choose criteria, goals, activity or notes',:unprocessable_entity)
    end
    render json:result
  end
  def update
    source=object(:achievement)
    write do |context|
      award=editable_award(context);AdminGoalManagement.revision!(award,source[:lock_version])
      attrs=source.permit(:title,:description,:icon,:color,:cohort_label,:criteria_snapshot,:final_score,:platform_program_id).to_h
      attrs['final_score']=nil if attrs.key?('final_score')&&attrs['final_score'].blank?
      if attrs.key?('platform_program_id')
        attrs['platform_program_id']=nil if attrs['platform_program_id'].blank?
        if attrs['platform_program_id']&&attrs['platform_program_id'].to_s!=award.platform_program_id.to_s
          PlatformProgram.active.find(AdminMenteeQuery.positive_id!(attrs['platform_program_id']))
        end
      end
      award.update!(attrs)
      audit(context,'achievement.corrected',changes:award.saved_changes.except('updated_at','lock_version'),title:award.title)
    end
    head :no_content
  end
  def save_criterion
    source=object(:criterion)
    write do |context|
      award=editable_award(context)
      item=params[:criterion_id] ? award.achievement_criteria.lock.find(params[:criterion_id]) : award.achievement_criteria.new
      AdminGoalManagement.revision!(item,source[:lock_version]) if item.persisted?
      raise Administration::Rejected.new('Keep at most 100 criteria per award',:unprocessable_entity) if item.new_record?&&award.achievement_criteria.count>=100
      item.update!(source.permit(:title,:category,:completed_units,:target_units));award.touch
      audit(context,'achievement.criterion_saved',criterion_id:item.id,title:item.title,completed_units:item.completed_units,target_units:item.target_units)
    end
    head :no_content
  end
  def remove_criterion
    write do |context|
      award=editable_award(context);item=award.achievement_criteria.lock.find(params[:criterion_id]);AdminGoalManagement.revision!(item,params[:lock_version]);title=item.title;item.destroy!;award.touch
      audit(context,'achievement.criterion_removed',title:title)
    end
    head :no_content
  end
  def save_note
    source=object(:note)
    write do |context|
      item=params[:note_id] ? context.notes.lock.find(params[:note_id]) : context.notes.new(author:current_user,author_name:current_user.full_name)
      AdminGoalManagement.revision!(item,source[:lock_version]) if item.persisted?
      old=item.body;item.update!(body:source[:body]);audit(context,'achievement.note_saved',note_id:item.id,body:item.body,previous_body:old)
    end
    head :no_content
  end
  def remove_note
    write do |context|
      item=context.notes.lock.find(params[:note_id]);AdminGoalManagement.revision!(item,params[:lock_version]);item.update!(is_active:false)
      audit(context,'achievement.note_removed',note_id:item.id)
    end
    head :no_content
  end
  def eligible_goals
    scope=MenteeGoal.kept.where(user_id:details.learner.id).where.not(id:details.links.select(:mentee_goal_id)).where('title ILIKE ?',"%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.first(150))}%").order(title: :asc,id: :asc)
    render json:{items:scope.limit(20).offset((page-1)*20).map{|g|{id:g.id,title:g.title,progress:g.progress,goal_key:g.goal_key}},meta:{page:page,per_page:20,total:scope.count,total_pages:(scope.count/20.0).ceil}}
  end
  def link_goal
    write do |context|
      raise Administration::Rejected.new('Keep at most 100 related goals',:unprocessable_entity) if context.links.count>=100
      goal=MenteeGoal.kept.where(user_id:context.learner.id).lock.find(AdminMenteeQuery.positive_id!(params[:goal_id]))
      link=AchievementGoalLink.create!(achievement_key:context.key,mentee_goal:goal)
      audit(context,'achievement.goal_linked',link_id:link.id,title:goal.title,goal_key:goal.goal_key)
    end
    head :no_content
  end
  def unlink_goal
    write do |context|
      link=context.links.lock.find(params[:link_id]);AdminGoalManagement.revision!(link,params[:lock_version]);title=link.mentee_goal.title;link.destroy!
      audit(context,'achievement.goal_unlinked',title:title)
    end
    head :no_content
  end
  def certificate
    document=details.certificate_document
    audit(details,'achievement.certificate_accessed',title:details.row[:title])
    send_data document.svg,type:'image/svg+xml',disposition:'attachment',filename:"nishiohub-#{details.key}.svg"
  end
  def issue_certificate
    write do |context|
      enrollment=context.enrollment
      raise Administration::Rejected.new('Only completed courses can issue a missing course certificate',:unprocessable_entity) unless enrollment
      created=false
      enrollment.with_lock do
        raise Administration::Rejected.new('Course is not completed',:unprocessable_entity) unless enrollment.course_complete?
        created=!enrollment.learning_certificate
        enrollment.issue_certificate_if_complete
      end
      audit(context,'achievement.certificate_issued',title:context.row[:title]) if created
    end
    head :no_content
  end
  def record
    data=details.as_json
    content=CSV.generate do |out|
      out<<%w[field value]
      {id:details.key,title:data[:title],description:data[:description],kind:data[:kind],learner:data.dig(:learner,:name),program:data.dig(:program,:title),cohort:data[:cohort],awarded_at:data[:awarded_at],status:data[:revoked_at] ? 'revoked' : 'awarded',criteria:data[:criteria_description],final_score:data.dig(:metrics,:final_score),overall_progress:data.dig(:metrics,:overall_progress)}.each{|k,v|out<<[k,AdminUserQuery.csv_cell(v)]}
      data[:criteria].each{|c|out<<[AdminUserQuery.csv_cell(c[:title]),"#{c[:completed_units]}/#{c[:target_units]}"]}
    end
    audit(details,'achievement.record_exported')
    send_data content,type:'text/csv; charset=utf-8',filename:"achievement-#{details.key}.csv"
  end
  private
  def details = @details ||= AchievementDetails.new(params[:id])
  def page
    value=params.fetch(:page,1).to_s
    raise Administration::Rejected.new('Invalid page',:unprocessable_entity) unless value.match?(/\A\d+\z/)&&value.to_i.between?(1,100000)
    value.to_i
  end
  def object(key)
    value=params.require(key);raise Administration::Rejected.new("#{key} must be an object",:unprocessable_entity) unless value.is_a?(ActionController::Parameters)
    value
  end
  def editable_award(context)
    award=context.award
    raise Administration::Rejected.new('Automatic achievements follow their source records',:unprocessable_entity) unless award
    award.lock!;raise Administration::Rejected.new('Revoked awards cannot be edited',:conflict) if award.revoked_at
    award
  end
  def write
    Administration.transaction do
      current_user.reload;Administration.authorize!(current_user,'dashboard.read');Administration.authorize!(current_user,'dashboard.manage')
      yield AchievementDetails.new(params[:id])
    end
  end
  def audit(context,action,**values) = AchievementDetails.audit!(current_user,context.row,action,values)
end
