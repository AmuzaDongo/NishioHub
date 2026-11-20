require "csv"

class Api::V1::AchievementsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_mentee!

  def index
    render json: MenteeAchievements.new(current_user).as_json
  end

  def record
    data = MenteeAchievements.new(current_user).as_json
    content = CSV.generate do |csv|
      csv << ["Learner", "Type", "Achievement", "Description", "Date"]
      data[:achievements].each do |entry|
        csv << [current_user.full_name, entry[:kind], entry[:title], entry[:description], entry[:occurred_at]].map { |value| csv_cell(value) }
      end
    end
    send_data content, type: "text/csv; charset=utf-8", disposition: "attachment", filename: "nishiohub-achievement-record.csv"
  end

  def certificate
    if params[:id].to_s.start_with?('award-')
      award=current_user.achievement_awards.active.find_by!(identifier:params[:id].delete_prefix('award-'),kind:'certificate')
      return send_data AchievementCertificateDocument.new(award).svg,type:'image/svg+xml',disposition:'attachment',filename:"nishiohub-certificate-#{award.identifier}.svg"
    end
    certificate = LearningCertificate.joins(:learning_enrollment)
      .where(learning_enrollments: { user_id: current_user.id }).find_by!(identifier: params[:id])
    return render_error("Course is not completed", :unprocessable_entity) unless certificate.learning_enrollment.course_complete?

    send_data LearningCertificateDocument.new(certificate).svg, type: "image/svg+xml", disposition: "attachment",
      filename: "nishiohub-certificate-#{certificate.identifier}.svg"
  end

  private

  def require_mentee!
    render_error("Mentee access required", :forbidden) unless current_user.has_role?('mentee')
  end

  def csv_cell(value)
    text = value.to_s
    text.match?(/\A[=+\-@\t\r\n]/) ? "'#{text}" : text
  end
end
