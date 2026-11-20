class AchievementDetails
  attr_reader :row,:learner,:award,:enrollment,:membership,:booking
  def initialize(key)
    raise ActiveRecord::RecordNotFound unless AchievementIdentity.valid?(key)
    query=AdminAchievementQuery.new(status:'all')
    @row=query.rows(query.base.where('achievement_rows.award_key=?',key)).first
    raise ActiveRecord::RecordNotFound unless row
    @learner=User.find(row.dig(:learner,:id))
    if row[:source]=='manual'
      @award=AchievementAward.find_by!(identifier:key.delete_prefix('award-'))
    elsif key.start_with?('course-')
      @enrollment=learner.learning_enrollments.find(key.delete_prefix('course-'))
    elsif key.start_with?('certificate-')
      @enrollment=LearningCertificate.find_by!(identifier:key.delete_prefix('certificate-')).learning_enrollment
    elsif key.start_with?('program-')
      @membership=ProgramMembership.find(key.delete_prefix('program-'))
    elsif key.start_with?('session-')
      @booking=learner.mentee_bookings.find(key.delete_prefix('session-'))
    end
  end
  def key = row[:id]
  def notes = AchievementNote.active.where(achievement_key:key)
  def links = AchievementGoalLink.where(achievement_key:key).joins(:mentee_goal).where(mentee_goals:{user_id:learner.id})
  def certificate_record
    return nil if row[:revoked_at]
    return award if award&&award.kind=='certificate'
    enrollment&.learning_certificate
  end
  def certificate_document
    cert=certificate_record;raise ActiveRecord::RecordNotFound unless cert
    cert.is_a?(AchievementAward) ? AchievementCertificateDocument.new(cert) : LearningCertificateDocument.new(cert)
  end
  def criteria
    if award
      award.achievement_criteria.order(:id).map{|c|{id:c.id.to_s,title:c.title,category:c.category,completed_units:c.completed_units,target_units:c.target_units,completed_at:c.completed_at&.iso8601,lock_version:c.lock_version,editable:row[:revoked_at].nil?}}
    elsif enrollment
      course=LearningCatalog.find(enrollment.course_key);stamps=enrollment.learning_lesson_completions.index_by(&:lesson_key)
      course['lessons'].map{|lesson|{id:lesson['id'],title:lesson['title'],category:'modules',completed_units:enrollment.completed_lesson_ids.include?(lesson['id']) ? 1 : 0,target_units:1,completed_at:stamps[lesson['id']]&.created_at&.iso8601,lock_version:0,editable:false}}
    elsif membership
      [{id:'program-completion',title:'Reach 100% program progress',category:'other',completed_units:membership.progress,target_units:100,completed_at:membership.completed_at&.iso8601,lock_version:0,editable:false}]
    elsif booking
      [{id:'session-completion',title:'Complete the mentorship session',category:'other',completed_units:1,target_units:1,completed_at:booking.updated_at.iso8601,lock_version:0,editable:false}]
    else
      builtin=AchievementCatalog::BADGES.find{|b|"builtin-#{b[0]}"==row[:definition_key]}
      [{id:'badge-criteria',title:builtin&.[](2)||row[:description],category:'other',completed_units:1,target_units:1,completed_at:row[:awarded_at],lock_version:0,editable:false}]
    end
  end
  def metrics
    list=criteria
    groups=%w[modules assessments project].to_h do |category|
      items=list.select{|c|c[:category]==category}
      [category,items.empty? ? nil : {completed:items.sum{|c|c[:completed_units]},total:items.sum{|c|c[:target_units]}}]
    end
    total=list.sum{|c|c[:target_units]};done=list.sum{|c|c[:completed_units]}
    groups.merge(overall_progress:total.zero? ? nil : (done*100.0/total).round(1),final_score:award&.final_score&.to_f)
  end
  def as_json(*)
    program_membership=row[:program]&&ProgramMembership.find_by(user:learner,platform_program_id:row[:program][:id])
    cert=certificate_record
    row.merge(learner:row[:learner].merge(phone:learner.phone_number),cohort:award&.cohort_label,joined_at:program_membership&.created_at&.iso8601,
      criteria_description:award ? award.criteria_snapshot : enrollment ? 'Complete every recorded lesson in the course.' : criteria.first&.dig(:title),
      criteria:criteria,metrics:metrics,certificate:cert&&{id:cert.is_a?(AchievementAward) ? "award-#{cert.identifier}" : "certificate-#{cert.identifier}",title:cert.is_a?(AchievementAward) ? cert.title : LearningCatalog.find(enrollment.course_key)['title'],issued_at:(cert.is_a?(AchievementAward) ? cert.awarded_at : cert.issued_at).iso8601},can_issue_certificate:!!(enrollment&&!cert&&enrollment.course_complete?),
      notes_count:notes.count,goals_count:links.count,recent_activity:activities(page:1,size:4)[:items],recent_notes:note_page(page:1,size:3)[:items])
  end
  def note_page(page:,q:'',size:20)
    scope=notes.where('body ILIKE ?',term(q)).order(created_at: :desc,id: :desc)
    {items:scope.limit(size).offset((page-1)*size).map{|n|{id:n.id,body:n.body,author:n.author_name,created_at:n.created_at.iso8601,updated_at:n.updated_at.iso8601,lock_version:n.lock_version}},meta:meta(scope.count,page,size)}
  end
  def goal_page(page:,q:'')
    scope=links.joins(:mentee_goal).where('mentee_goals.title ILIKE ?',term(q)).order(id: :desc)
    {items:scope.limit(20).offset((page-1)*20).includes(:mentee_goal).map{|l|g=l.mentee_goal;{id:l.id,goal_key:g.goal_key,title:g.title,progress:g.progress,status:g.display_status,target_date:g.target_date&.iso8601,archived:!!g.archived_at,lock_version:l.lock_version}},meta:meta(scope.count,page,20)}
  end
  def activities(page:,q:'',size:20)
    audits=AdministrationAudit.where(target_type:'AchievementRecord').where("changeset->>'achievement_key'=?",key)
    audits=audits.or(AdministrationAudit.where(target_type:'AchievementAward',target_id:award.id)) if award
    audits=audits.or(AdministrationAudit.where(action:'achievement.certificate_downloaded').where("changeset->>'award'=?",key))
    fragments=[audits.select("'audit-'||id::text item_key,action title,COALESCE(changeset->>'body',changeset->>'reason',changeset->>'title','') body,actor_name,created_at").to_sql]
    quote=->(value){ApplicationRecord.connection.quote(value)}
    fragments<<"SELECT 'earned'::text item_key,'Achievement awarded'::text title,#{quote.call(row[:title])}::text body,#{quote.call(row[:issuer]||'System (Automatic)')}::text actor_name,#{quote.call(Time.iso8601(row[:awarded_at]))}::timestamp created_at"
    if enrollment
      course=LearningCatalog.find(enrollment.course_key)
      names=course['lessons'].map{|l|"WHEN #{quote.call(l['id'])} THEN #{quote.call(l['title'])}"}.join(' ')
      fragments<<enrollment.learning_lesson_completions.where(lesson_key:course['lessons'].map{|l|l['id']}).select("'lesson-'||id::text item_key,'Lesson completed' title,CASE lesson_key #{names} END body,#{quote.call(learner.full_name)} actor_name,created_at").to_sql
    end
    if award
      fragments<<award.achievement_criteria.where.not(completed_at:nil).select("'criterion-'||id::text item_key,'Criterion completed' title,title body,#{quote.call('Recorded evidence')} actor_name,completed_at created_at").to_sql
    end
    clause=ApplicationRecord.sanitize_sql_array(['title ILIKE :q OR body ILIKE :q OR actor_name ILIKE :q',{q:term(q)}])
    base="FROM (#{fragments.join(' UNION ALL ')}) entries WHERE #{clause}"
    total=ApplicationRecord.connection.select_value("SELECT COUNT(*) #{base}").to_i
    records=ApplicationRecord.connection.select_all("SELECT * #{base} ORDER BY created_at DESC,item_key DESC LIMIT #{size.to_i} OFFSET #{(page-1)*size}").to_a
    {items:records.map{|r|{id:r['item_key'],title:r['title'],body:r['body'],author:r['actor_name'],at:(r['created_at'].respond_to?(:iso8601) ? r['created_at'].iso8601 : Time.parse(r['created_at'].to_s).iso8601)}},meta:meta(total,page,size)}
  end
  def self.audit!(actor,row,action,values={})
    AdministrationAudit.create!(actor:actor,actor_name:actor.full_name,target_type:'AchievementRecord',target_id:row.dig(:learner,:id),action:action,changeset:values.merge(achievement_key:row[:id]))
  end
  private
  def term(q) = "%#{ActiveRecord::Base.sanitize_sql_like(q.to_s.strip.first(150))}%"
  def meta(total,page,size) = {page:page,per_page:size,total:total,total_pages:(total/size.to_f).ceil}
end
