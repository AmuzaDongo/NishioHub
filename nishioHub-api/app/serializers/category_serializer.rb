class CategorySerializer
  def initialize(category)
    @category = category
  end

  def as_json(*)
    {
      id: @category.id,
      name: @category.name,
      slug: @category.slug,
      description: @category.description,
      iconPath: image_url,
      icon_path: @category.icon_path,
      image_url: image_url,
      image_metadata: image_metadata,
      topics: @category.topics || [],
      position: @category.position,
      is_active: @category.is_active,
      parent_id: @category.parent_id,
      service_count: @category.services.size,
      created_at: @category.created_at&.iso8601,
      updated_at: @category.updated_at&.iso8601
    }
  end

  private

  def image_url
    return nil unless @category.image.attached?

    @category.image.url
  end

  def image_metadata
    return nil unless @category.image.attached?

    {
      alt: @category.image_alt.presence || @category.name,
      content_type: @category.image.blob.content_type,
      byte_size: @category.image.blob.byte_size
    }
  end
end
