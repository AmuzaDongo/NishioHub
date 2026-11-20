class Api::V1::AdminIntegrationsController < ApplicationController
  before_action :require_admin!
  before_action ->{Administration.authorize!(current_user,'dashboard.read')}
  before_action {response.headers['Cache-Control']='private, no-store'}
  def index
    rows=PlatformIntegration.all.index_by(&:provider_key)
    items=IntegrationCatalog::PROVIDERS.map{|provider|serialize(provider,rows[provider[:key]])}
    category=params[:category].presence||'all'
    raise Administration::Rejected.new('Choose a valid integration category',:unprocessable_entity) unless (['all']+IntegrationCatalog::CATEGORIES).include?(category)
    q=params[:q].to_s.first(150).strip.downcase
    filtered=items.select{|i|(category=='all'||i[:category]==category)&&(q.blank?||[i[:name],i[:description],i[:label]].join(' ').downcase.include?(q))}
    render json:{items:filtered,stats:{total:items.size,active:items.count{|i|i[:status]=='active'},paused:items.count{|i|i[:status]=='paused'},attention:items.count{|i|i[:status]=='attention'},available:items.count{|i|i[:status]=='available'}},categories:IntegrationCatalog::CATEGORIES.map{|key|{key:key,count:items.count{|i|i[:category]==key}}},activity:log_scope.order(id: :desc).limit(6).map{|log|serialize_log(log)},capabilities:{manage:current_user.management_permission?('system.manage')}}
  end
  def update
    provider=IntegrationCatalog.find!(params[:key]);source=params.require(:integration)
    raise Administration::Rejected.new('Integration must be an object',:unprocessable_entity) unless source.is_a?(ActionController::Parameters)
    incoming=source[:credentials]
    raise Administration::Rejected.new('Credentials must be an object',:unprocessable_entity) unless incoming.is_a?(ActionController::Parameters)
    fields=provider[:fields].map{|f|f[:key]}
    raise Administration::Rejected.new('Unknown credential fields',:unprocessable_entity) if (incoming.keys-fields).any?
    record=nil
    write do
      record=PlatformIntegration.lock.find_or_initialize_by(provider_key:provider[:key]);revision!(record,source[:lock_version])
      values=record.credentials
      incoming.each_pair do |key,value|
        unless value.is_a?(String)&&value.bytesize<=8192&&!value.match?(/[\r\n\u0000]/)
          raise Administration::Rejected.new('Credentials must be text without line breaks, up to 8 KB per field',:unprocessable_entity)
        end
        values[key]=value.strip if value.present?
      end
      raise Administration::Rejected.new('Complete all required credential fields',:unprocessable_entity) unless fields.all?{|key|values[key].present?}
      record.credentials=values.slice(*fields);record.environment=source[:environment] if source.key?(:environment)
      record.verified=false;record.last_checked_at=nil;record.last_attempt_at=nil;record.last_http_status=nil;record.last_message='Credentials saved. Run a connection check.';record.updated_by=current_user
      record.save!;log!(record,'configured','success','Integration credentials configured.')
    end
    render json:serialize(provider,record)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    render_error('Stored credentials cannot be opened. Disconnect and reconnect this integration.',:unprocessable_entity)
  end
  def change
    provider=IntegrationCatalog.find!(params[:key]);record=nil
    command=params[:action_name]
    raise Administration::Rejected.new('Choose pause or resume',:unprocessable_entity) unless %w[pause resume].include?(command)
    write do
      record=PlatformIntegration.lock.find_by!(provider_key:provider[:key]);revision!(record,params[:lock_version])
      raise Administration::Rejected.new('Connect this integration first',:unprocessable_entity) unless record.configured?
      record.paused=command=='pause';record.verified=false if command=='resume';record.updated_by=current_user;record.save!
      log!(record,command,'success',command=='pause' ? 'Integration paused.' : 'Integration resumed. Run a connection check.')
    end
    render json:serialize(provider,record)
  end
  def disconnect
    provider=IntegrationCatalog.find!(params[:key]);record=nil
    write do
      record=PlatformIntegration.lock.find_by!(provider_key:provider[:key]);revision!(record,params[:lock_version])
      record.credentials={};record.paused=false;record.verified=false;record.last_checked_at=nil;record.last_attempt_at=nil;record.last_message=nil;record.last_http_status=nil;record.updated_by=current_user;record.save!
      log!(record,'disconnected','warning','Integration disconnected and stored credentials removed.')
    end
    render json:serialize(provider,record)
  end
  def check
    provider=IntegrationCatalog.find!(params[:key]);record=nil;snapshot=nil;environment=nil;revision=nil
    write do
      record=PlatformIntegration.lock.find_by!(provider_key:provider[:key]);revision!(record,params[:lock_version])
      raise Administration::Rejected.new('Connect and resume this integration before checking it',:unprocessable_entity) unless record.configured?&&!record.paused?
      if record.last_attempt_at&&record.last_attempt_at>30.seconds.ago
        raise Administration::Rejected.new('Wait 30 seconds between connection checks',:too_many_requests)
      end
      snapshot=record.credentials;environment=record.environment
      record.update!(last_attempt_at:Time.current);revision=record.lock_version
    end
    result=IntegrationProbe.call(provider[:key],snapshot,environment)
    write do
      record.reload.lock!;revision!(record,revision)
      record.update!(verified:result[:success],last_checked_at:Time.current,last_http_status:result[:http_status],last_message:result[:message],updated_by:current_user)
      log!(record,'checked',result[:success] ? 'success' : 'error',result[:message],result[:http_status])
    end
    render json:serialize(provider,record)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    render_error('Stored credentials cannot be opened. Disconnect and reconnect this integration.',:unprocessable_entity)
  end
  def logs
    page=number(:page,1,1..10000);size=number(:per_page,10,[10,25,50]);scope=log_scope.order(id: :desc);total=scope.count
    render json:{items:scope.limit(size).offset((page-1)*size).map{|log|serialize_log(log)},meta:{page:page,per_page:size,total:total,total_pages:(total/size.to_f).ceil}}
  end
  private
  def write
    Administration.transaction do
      current_user.reload;raise Administration::Rejected,'Account is inactive' unless current_user.is_active?
      Administration.authorize!(current_user,'dashboard.read');Administration.authorize!(current_user,'system.manage');yield
    end
  end
  def revision!(record,value)
    if record.persisted?
      unless value.to_s.match?(/\A\d+\z/)&&value.to_i==record.lock_version
        raise Administration::Rejected.new('This integration changed. Reload it before saving.',:conflict)
      end
    elsif !value.nil?
      raise Administration::Rejected.new('Reload the latest integration before saving',:conflict)
    end
  end
  def serialize(provider,record)
    provider.merge(status:record&.status||'available',environment:record&.environment||'live',lock_version:record&.lock_version,
      credential_fields:record&.configured? ? provider[:fields].map{|f|f[:key]} : [],last_checked_at:record&.last_checked_at&.iso8601,last_message:record&.last_message,last_http_status:record&.last_http_status,
      updated_at:record&.updated_at&.iso8601,updated_by:record&.updated_by&.full_name)
  end
  def log!(record,action,outcome,message,http_status=nil)
    IntegrationLog.create!(provider_key:record.provider_key,action:action,outcome:outcome,message:message,http_status:http_status,actor:current_user,actor_name:current_user.full_name)
    Administration.audit!(current_user,"integration.#{action}",record,{provider:record.provider_key,environment:record.environment,outcome:outcome})
  end
  def serialize_log(log) = log.as_json(only:%i[id provider_key action outcome message http_status actor_name created_at])
  def log_scope
    scope=IntegrationLog.all
    if params[:provider].present?
      IntegrationCatalog.find!(params[:provider]);scope=scope.where(provider_key:params[:provider])
    end
    if params[:outcome].present?
      raise Administration::Rejected.new('Choose a valid log outcome',:unprocessable_entity) unless %w[success warning error].include?(params[:outcome])
      scope=scope.where(outcome:params[:outcome])
    end
    scope
  end
  def number(key,default,allowed)
    raw=params.fetch(key,default).to_s
    raise Administration::Rejected.new("Invalid #{key}",:unprocessable_entity) unless raw.match?(/\A\d+\z/)&&allowed.include?(raw.to_i)
    raw.to_i
  end
end
