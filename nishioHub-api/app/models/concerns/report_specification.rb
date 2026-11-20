module ReportSpecification
  extend ActiveSupport::Concern
  included do
    belongs_to :user
    validates :name,presence:true,length:{maximum:150}
    validates :kind,inclusion:{in:['overview']+AnalyticsReport::DATASETS.keys}
    validate do
      allowed=kind=='overview' ? [] : AnalyticsReport::DATASETS[kind]&.keys
      unless columns.is_a?(Array)&&columns.uniq==columns&&allowed&&(kind=='overview' ? columns.empty? : columns.size.between?(1,12)&&columns.all?{|c|allowed.include?(c)})
        errors.add(:columns,'must contain distinct available columns')
      end
      if !filters.is_a?(Hash)||filters.keys.any?{|key|!AnalyticsReport::FILTER_KEYS.include?(key)}
        errors.add(:filters,'must use the supported report filters')
      else
        begin
          AnalyticsPeriod.build(filters)
          AdminMenteeQuery.positive_id!(filters['program_id']) if filters['program_id'].present?
        rescue Administration::Rejected,ActionController::ParameterMissing
          errors.add(:filters,'must contain a valid reporting range and program')
        end
      end
    end
  end
end
