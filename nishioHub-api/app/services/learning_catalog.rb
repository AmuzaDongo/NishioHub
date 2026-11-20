class LearningCatalog
  def self.data
    @data ||= JSON.parse(Rails.root.join("config/learning_catalog.json").read)
  end

  def self.courses
    data.fetch("courses")
  end

  def self.find(id)
    courses.find { |course| course["id"] == id.to_s }
  end
end
