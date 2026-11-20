class Api::V1::PublicLearningResourcesController < ApplicationController
  before_action {response.headers['Cache-Control']='no-store'}
  before_action :authenticate_user!,only:%i[bookmarks save_bookmark remove_bookmark]

  def index
    category=params[:category].to_s;path=params[:path].to_s;format=params[:format].to_s;sort=params.fetch(:sort,'featured').to_s
    reject!('Choose a valid category') if category.present?&&!ResourceLibraryDetails::CATEGORIES.include?(category)
    reject!('Choose a valid learning path') if path.present?&&!ResourceLibraryDetails::PATHS.include?(path)
    reject!('Choose a valid format') if format.present?&&!%w[study_material video toolkit career_guide learning_path other].include?(format)
    reject!('Choose featured, recent, popular or title sorting') unless %w[featured recent popular title].include?(sort)
    page=params.fetch(:page,'1').to_s;size=params.fetch(:per_page,'3').to_s
    reject!('Choose a valid page') unless page.match?(/\A[1-9]\d{0,3}\z/)
    reject!('Choose 3, 6, 9 or 12 resources per page') unless %w[3 6 9 12].include?(size)
    %w[saved featured].each{|key|reject!("#{key.humanize} must be true or false") if params.key?(key)&&!%w[true false].include?(params[key].to_s)}
    scope=public_scope
    scope=scope.where("COALESCE(library_details->>'category','general') = ?",category) if category.present?
    scope=scope.where("library_details->'learning_paths' @> ?::jsonb",[path].to_json) if path.present?
    scope=scope.where("#{format_sql} = ?",format) if format.present?
    scope=scope.where("library_details->>'featured' = 'true'") if params[:featured].to_s=='true'
    q=params[:q].to_s.strip.first(150)
    scope=scope.where('title ILIKE :q OR description ILIKE :q OR tags::text ILIKE :q',q:"%#{ActiveRecord::Base.sanitize_sql_like(q)}%") if q.present?
    if params[:saved].to_s=='true'
      authenticate_user!;return if performed?
      response.headers['Cache-Control']='private, no-store'
      scope=scope.where(id:current_user.resource_bookmarks.select(:platform_resource_id))
    end
    order=case sort
    when 'popular' then Arel.sql("#{access_sql} DESC, platform_resources.id DESC")
    when 'title' then {title: :asc,id: :asc}
    when 'recent' then {published_at: :desc,id: :desc}
    else Arel.sql("CASE WHEN library_details->>'featured'='true' THEN 0 ELSE 1 END, platform_resources.published_at DESC, platform_resources.id DESC")
    end
    total=scope.count
    counts=public_scope.group(Arel.sql("COALESCE(library_details->>'category','general')")).count
    render json:{items:rows(scope.order(order).offset((page.to_i-1)*size.to_i).limit(size.to_i)),
      recent:rows(scope.order(published_at: :desc,id: :desc).limit(3)),
      popular:rows(scope.where("#{access_sql}>0").order(Arel.sql("#{access_sql} DESC, platform_resources.id DESC")).limit(3)),
      categories:counts,total:counts.values.sum,meta:{page:page.to_i,total:total,total_pages:(total/size.to_f).ceil}}
  end
  def show
    resource=find_resource
    related=public_scope.where.not(id:resource.id).where("COALESCE(library_details->>'category','general') = ?",resource.library_details.fetch('category','general')).order(published_at: :desc,id: :desc).limit(3)
    supporting=resource.resource_contents.where(public_listing:true).order(:position,:id).with_attached_file.select{|c|c.file.attached?||c.url.present?}
    count=resource.resource_comments.where(status:'approved').joins(:user).where(users:{is_active:true}).count
    render json:rows(public_scope.where(id:resource.id)).first.merge(
      page_details:ResourcePageDetails::DEFAULTS.merge(resource.page_details),updated_at:resource.updated_at.iso8601,
      comments_count:count,related:rows(related),has_file:resource.file.attached?,has_link:resource.url.present?,
      supporting_resources:supporting.map{|c|{id:c.id,title:c.title,has_file:c.file.attached?,has_link:c.url.present?,file_type:c.file.attached? ? c.file.content_type : nil,size:c.file.attached? ? c.file.byte_size : nil}})
  end
  def thumbnail
    resource=find_resource;raise ActiveRecord::RecordNotFound unless resource.thumbnail.attached?
    response.headers['Cache-Control']='no-store'
    send_data resource.thumbnail.download,type:resource.thumbnail.content_type,disposition:'inline'
  end
  def bookmarks
    response.headers['Cache-Control']='private, no-store'
    render json:{resource_ids:public_scope.where(id:current_user.resource_bookmarks.select(:platform_resource_id)).pluck(:id)}
  end
  def save_bookmark
    resource=find_resource
    # Serialize against publication changes and concurrent duplicate requests.
    resource.with_lock do
      raise ActiveRecord::RecordNotFound unless resource.published?&&!resource.archived?&&resource.deleted_at.nil?&&resource.visibility=='platform'
      current_user.resource_bookmarks.find_or_create_by!(platform_resource:resource)
    end
    head :no_content
  end
  def remove_bookmark
    current_user.resource_bookmarks.where(platform_resource_id:params[:id]).destroy_all
    head :no_content
  end
  private
  def public_scope = PlatformResource.kept.where(published:true,archived:false,visibility:'platform')
  def find_resource = public_scope.find(params[:id])
  def reject!(message) = raise Administration::Rejected.new(message,:unprocessable_entity)
  def access_sql = '(SELECT COUNT(*) FROM platform_resource_accesses a WHERE a.platform_resource_id=platform_resources.id)'
  def format_sql = "CASE WHEN COALESCE(library_details->>'format','auto')<>'auto' THEN library_details->>'format' WHEN resource_type='video' THEN 'video' WHEN resource_type='document' THEN 'study_material' WHEN resource_type='course' THEN 'learning_path' ELSE 'other' END"
  def rows(scope)
    scope.select('platform_resources.*',"#{access_sql} AS public_accesses",'(SELECT COUNT(*) FROM platform_resource_accesses a WHERE a.platform_resource_id=platform_resources.id AND a.kind=\'download\') AS public_downloads')
      .with_attached_thumbnail.with_attached_file.map do |resource|
      data=ResourceLibraryDetails::DEFAULTS.merge(resource.library_details)
      {id:resource.id,title:resource.title,description:resource.description,resource_type:resource.resource_type,
        category:data['category'],learning_paths:data['learning_paths'],format:ResourceLibraryDetails.format(resource),level:data['level'],page_count:data['page_count'],featured:data['featured'],
        duration_seconds:resource.duration_seconds,thumbnail:resource.thumbnail.attached? ? "/api/v1/platform/learning-resources/#{resource.id}/thumbnail?version=#{resource.lock_version}" : nil,
        file_type:resource.file.attached? ? resource.file.content_type : nil,accesses:resource[:public_accesses].to_i,downloads:resource[:public_downloads].to_i,
        language:resource.language,target_audience:resource.target_audience,published_at:resource.published_at&.iso8601}
    end
  end
end
