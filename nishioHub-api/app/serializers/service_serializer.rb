class ServiceSerializer
  def initialize(service)
    @service = service
  end

  def as_json(*)
    reviews = @service.reviews
    rating = reviews.empty? ? nil : (reviews.sum(&:rating).to_f / reviews.size).round(1)

    {
      id: @service.id,
      title: @service.title,
      description: @service.description,
      shortDescription: @service.description.to_s.truncate(120),
      short_description: @service.description.to_s.truncate(120),
      mentorId: @service.mentor_id,
      mentor_id: @service.mentor_id,
      categoryId: @service.category_id,
      category_id: @service.category_id,
      category: @service.category&.name,
      price: @service.price.to_f,
      duration: @service.duration,
      tags: @service.tags || [],
      imageUrl: @service.image_url,
      image_url: @service.image_url,
      image: @service.image_url,
      rating: rating,
      reviewCount: reviews.size,
      review_count: reviews.size,
      isActive: @service.is_active,
      is_active: @service.is_active,
      createdAt: @service.created_at&.iso8601,
      created_at: @service.created_at&.iso8601,
      updatedAt: @service.updated_at&.iso8601,
      updated_at: @service.updated_at&.iso8601,
      mentor: MentorSerializer.new(@service.mentor).as_json
    }
  end
end
