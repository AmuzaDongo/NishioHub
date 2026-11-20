class Api::V1::LearningAreaController < ApplicationController
  before_action :authenticate_user!
  before_action :require_mentee!
  before_action :set_course, only: %i[enroll complete_lesson]

  def show
    enrollments = current_user.learning_enrollments.index_by(&:course_key)
    courses = LearningCatalog.courses.map do |course|
      enrollment = enrollments[course["id"]]
      course.merge(
        "enrolled" => enrollment.present?,
        "completed_lesson_ids" => enrollment&.completed_lesson_ids || []
      )
    end
    enrolled = courses.select { |course| course["enrolled"] }
    lessons = enrolled.flat_map { |course| course["lessons"] }
    completed = enrolled.flat_map { |course| course["completed_lesson_ids"] }
    activity = enrollments.values.flat_map(&:activity_dates).uniq
    day = Date.current
    day -= 1 unless activity.include?(day.iso8601)
    streak = 0
    while activity.include?(day.iso8601)
      streak += 1
      day -= 1
    end
    render json: {
      name: current_user.full_name,
      avatar: current_user.avatar_url,
      shared_resources: PlatformResource.accessible_to(current_user).includes(:platform_program, file_attachment: :blob).order(created_at: :desc).limit(20).map { |resource|
        { id: resource.id, resource_type: resource.resource_type, tags: resource.tags, title: resource.title, description: resource.description, url: resource.url,
          program: resource.platform_program&.title, filename: resource.file.attached? ? resource.file.filename.to_s : nil,
          download_path: resource.file.attached? ? "/learning/resources/#{resource.id}/file" : nil }
      },
      categories: LearningCatalog.data.fetch("categories"),
      courses: courses,
      progress: {
        enrolled: enrolled.size,
        completed: enrolled.count { |course| course["lessons"].all? { |lesson| completed.include?(lesson["id"]) } },
        percent: lessons.empty? ? 0 : (completed.size * 100.0 / lessons.size).round,
        hours: (lessons.select { |lesson| completed.include?(lesson["id"]) }.sum { |lesson| lesson["minutes"] } / 60.0).round(1),
        streak: streak
      },
      upcoming_sessions: current_user.mentee_bookings.where(status: "confirmed").where("scheduled_at >= ?", Time.current)
        .includes(:service).order(:scheduled_at).limit(2).map do |booking|
          { id: booking.id, title: booking.service.title, scheduled_at: booking.scheduled_at.iso8601, duration: booking.duration }
        end
    }
  end

  def enroll
    return render_error('New course enrollments are paused', :forbidden) unless SystemSetting.config['learning_enrollment_enabled']
    enrollment = current_user.with_lock do
      current_user.learning_enrollments.find_or_create_by!(course_key: @course["id"])
    end
    render json: { course_id: enrollment.course_key }, status: :ok
  end

  def complete_lesson
    lesson = @course["lessons"].find { |candidate| candidate["id"] == params[:lesson_id] }
    return render_error("Lesson not found", :not_found) unless lesson

    enrollment = current_user.learning_enrollments.find_by!(course_key: @course["id"])
    enrollment.with_lock do
      enrollment.completed_lesson_ids |= [lesson["id"]]
      enrollment.activity_dates |= [Date.current.iso8601]
      enrollment.save!
    end
    render json: { completed_lesson_ids: enrollment.completed_lesson_ids }
  end

  private

  def require_mentee!
    render_error("Mentee access required", :forbidden) unless current_user.has_role?('mentee')
  end

  def set_course
    @course = LearningCatalog.find(params[:course_id])
    render_error("Course not found", :not_found) unless @course
  end
end
