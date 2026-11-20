class Api::V1::PublicHomeController < ApplicationController
  before_action { response.headers['Cache-Control']='no-store' }
  def show
    mentors=User.with_role('mentor').where(is_active:true).joins(:mentor_profile).where(mentor_profiles:{is_verified:true,is_published:true})
      .includes(:profile,avatar_attachment: :blob,mentor_profile: [:skills,avatar_attachment: :blob]).order(id: :desc).limit(4)
    render json:{mentors:mentors.map{|u|{id:u.id,name:u.full_name,title:u.mentor_profile.title,skills:u.mentor_profile.skills.map(&:name).first(3),verified:true,avatar:portrait(u)}},events:public_events.limit(3).map{|e|event_json(e)}}
  end
  def about
    config=SystemSetting.config
    mentors=User.with_role('mentor').where(is_active:true).joins(:mentor_profile).where(mentor_profiles:{is_verified:true,is_published:true})
    organizations=User.with_role('organization').or(User.with_role('school')).where(is_active:true)
    render json:{
      impact:{learners:User.with_role('mentee').where(is_active:true).count,
        mentors:mentors.count,
        resources:PlatformResource.kept.where(published:true,archived:false,visibility:'platform').count,
        events:config['public_events_enabled'] ? Event.kept.where(status:'published').count : 0,
        organizations:organizations.count},
      story_video_url:config['about_story_video_url'].presence,
      team:config['about_team'].select{|member|member['published']==true}.map{|member|member.slice('name','title','bio','photo_url')}
    }
  end

  def catalog
    kind=params[:kind].to_s
    raise Administration::Rejected.new('Choose programs, learning or events',:unprocessable_entity) unless %w[programs learning events].include?(kind)
    page=params.fetch(:page,'1').to_s
    raise Administration::Rejected.new('Choose a valid page',:unprocessable_entity) unless page.match?(/\A[1-9]\d{0,3}\z/)
    page=page.to_i;q=params[:q].to_s.strip.first(150)
    if kind=='learning'
      rows=LearningCatalog.courses.select{|c|q.blank?||"#{c['title']} #{c['level']}".downcase.include?(q.downcase)}
      total=rows.size;items=rows.slice((page-1)*12,12).to_a.map{|c|{id:c['id'],title:c['title'],level:c['level'],image:c['image'],lessons:c['lessons'].size}}
    else
      scope=kind=='programs' ? PlatformProgram.where(status:'active').includes(:category).with_attached_banner.order(title: :asc,id: :asc) : public_events
      scope=scope.where('title ILIKE :q OR description ILIKE :q',q:"%#{ActiveRecord::Base.sanitize_sql_like(q)}%") if q.present?
      total=scope.count;rows=scope.offset((page-1)*12).limit(12)
      items=rows.map{|r|kind=='events' ? event_json(r) : {id:r.id,title:r.title,description:r.description,image:r.banner_url,category:r.category&.name,starts_on:r.starts_on,ends_on:r.ends_on,mode:r.delivery_mode,target_audience:r.target_audience,objectives:r.objectives}}
    end
    render json:{items:items,meta:{page:page,total:total,total_pages:(total/12.0).ceil},enabled:kind!='events'||SystemSetting.config['public_events_enabled']}
  end
  private
  def portrait(user)
    attachment=user.mentor_profile.avatar.attached? ? user.mentor_profile.avatar : user.avatar
    attachment.attached? ? rails_storage_proxy_path(attachment.blob,only_path:true) : user.profile&.profile_picture
  end
  def public_events
    scope=Event.kept.where(status:'published').where('starts_at > ?',Time.current).order(:starts_at,:id)
    SystemSetting.config['public_events_enabled'] ? scope : scope.none
  end
  def event_json(e) = {id:e.id,title:e.title,description:e.description,starts_at:e.starts_at.iso8601,ends_at:e.ends_at.iso8601,location:e.location,image:e.image_path,category:e.event_type}
end
