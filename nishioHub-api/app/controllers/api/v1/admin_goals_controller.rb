require 'csv'
class Api::V1::AdminGoalsController < ApplicationController
  before_action :require_admin!
  before_action -> {Administration.authorize!(current_user,'dashboard.read')}
  before_action {response.headers['Cache-Control']='private, no-store'}
  def index
    query=AdminGoalQuery.new(params);scope=query.filtered;size=query.per_page;page=query.page_number;total=scope.count
    payload=query.report.merge(capabilities:{manage:current_user.management_permission?('dashboard.manage'),view_users:current_user.management_permission?('users.read')})
    if %w[mentees mentors].include?(params[:tab])
      people=query.people(scope);payload.merge!(people:people[:items],items:[],meta:people[:meta]);payload[:mode]='people'
    else
      payload.merge!(items:query.rows(query.ordered(scope).limit(size).offset((page-1)*size)),meta:{page:page,per_page:size,total:total,total_pages:(total/size.to_f).ceil},mode:'goals',people:[])
    end
    render json:payload
  end
  def show
    goal=AdminGoalManagement.find!(params[:id])
    query=AdminGoalQuery.new
    row=query.rows(query.base.where('goal_rows.goal_key = ?',goal.goal_key)).first
    render json:row.merge(milestones:goal.goal_milestones.order(Arel.sql('target_date ASC NULLS LAST, id ASC')).as_json(only:[:id,:title,:target_date,:completed,:lock_version]),history:goal.goal_progress_events.order(created_at: :desc,id: :desc).limit(100).as_json(only:[:id,:progress,:note,:actor_name,:created_at]))
  end
  def create
    goal=AdminGoalManagement.save!(current_user,data);params[:id]=goal.goal_key;show;response.status=201
  end
  def update
    AdminGoalManagement.save!(current_user,data,goal:AdminGoalManagement.find!(params[:id]));show
  end
  def destroy
    Administration.transaction do
      AdminGoalManagement.authorize!(current_user);goal=AdminGoalManagement.find!(params[:id]);goal.lock!;AdminGoalManagement.revision!(goal,params[:lock_version]);goal.update!(archived_at:Time.current)
      Administration.audit!(current_user,'goal.archived',goal,{kind:goal.goal_kind,title:goal.title})
    end
    head :no_content
  end
  def save_milestone
    source=object(:milestone)
    Administration.transaction do
      AdminGoalManagement.authorize!(current_user);goal=AdminGoalManagement.find!(params[:id]);goal.lock!;raise ActiveRecord::RecordNotFound if goal.archived_at
      item=params[:milestone_id] ? goal.goal_milestones.lock.find(params[:milestone_id]) : goal.goal_milestones.new
      AdminGoalManagement.revision!(item,source[:lock_version]) if item.persisted?
      raise Administration::Rejected.new('Keep at most 100 milestones per goal',:unprocessable_entity) if item.new_record?&&goal.goal_milestones.count>=100
      item.update!(source.permit(:title,:target_date,:completed));goal.touch
      Administration.audit!(current_user,'goal.milestone_saved',goal,{milestone_id:item.id,completed:item.completed})
    end
    head :no_content
  end
  def remove_milestone
    Administration.transaction do
      AdminGoalManagement.authorize!(current_user);goal=AdminGoalManagement.find!(params[:id]);goal.lock!;raise ActiveRecord::RecordNotFound if goal.archived_at
      item=goal.goal_milestones.lock.find(params[:milestone_id]);AdminGoalManagement.revision!(item,params[:lock_version]);item.destroy!;goal.touch
      Administration.audit!(current_user,'goal.milestone_removed',goal,{milestone_id:params[:milestone_id]})
    end
    head :no_content
  end
  def export
    query=AdminGoalQuery.new(params);scope=export_scope(query)
    return render_error('Filter to at most 10,000 goals before exporting',:unprocessable_entity) if scope.count>10000
    csv=CSV.generate do |out|
      out<<%w[id title description goal_type category program assignee target_date progress status]
      (scope.count/100.0).ceil.times do |n|
        query.rows(query.ordered(scope).limit(100).offset(n*100)).each{|r|out<<[r[:id],r[:title],r[:description],r[:kind],r[:category],r.dig(:program,:title),r.dig(:assignee,:name)||'Program Team',r[:target_date],r[:progress],r[:status]].map{|v|AdminUserQuery.csv_cell(v)}}
      end
    end
    Administration.audit!(current_user,'goals.exported',current_user,{count:scope.count})
    send_data csv,type:'text/csv; charset=utf-8',filename:'nishiohub-goals.csv'
  end
  def report
    query=AdminGoalQuery.new(params);report=query.report
    csv=CSV.generate do |out|
      out<<%w[metric value]
      report[:stats].except(:changes).each{|k,v|out<<[k,v]}
      report[:categories].each{|c|out<<["category_#{c[:category]}",c[:count]]}
      report[:trend].each{|p|out<<["progress_#{p[:month]}",p[:progress]];out<<["recorded_goals_#{p[:month]}",p[:recorded_goals]]}
    end
    Administration.audit!(current_user,'goals.report_exported',current_user,{filters:params.permit(:q,:tab,:type,:status,:program_id,:category,:assignee_id).to_h})
    send_data csv,type:'text/csv; charset=utf-8',filename:'nishiohub-goals-report.csv'
  end
  private
  def object(key)
    source=params.require(key)
    raise Administration::Rejected.new("#{key} must be an object",:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    source
  end
  def data = object(:goal).permit(:kind,:title,:description,:user_id,:platform_program_id,:progress,:target_date,:category,:tracking_status,:priority,:icon,:lock_version,:note).to_h
  def export_scope(query)
    scope=query.filtered
    if params[:goal_ids].present?
      ids=params[:goal_ids]
      raise Administration::Rejected.new('Choose 1–100 valid goal identifiers',:unprocessable_entity) unless ids.is_a?(Array)&&ids.size.between?(1,100)&&ids.all?{|id|id.is_a?(String)&&id.match?(/\A(mentee|mentor|program)-[1-9]\d*\z/)}
      scope=scope.where('goal_rows.goal_key IN (?)',ids.uniq)
    end
    scope
  end
end
