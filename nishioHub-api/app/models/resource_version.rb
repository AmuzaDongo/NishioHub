class ResourceVersion < ApplicationRecord
  FIELDS = %w[page_details library_details title description resource_type tags url platform_program_id published archived language target_audience module_name position required awards duration_seconds visibility published_at deleted_at].freeze
  belongs_to :platform_resource
  belongs_to :actor, class_name: 'User', optional: true
  has_many_attached :content_files
  has_one_attached :file
  has_one_attached :thumbnail
  has_one_attached :captions
  def self.capture!(resource, actor = nil)
    snapshot = resource.attributes.slice(*FIELDS).as_json.merge(
      'contents' => resource.resource_contents.order(:position, :id).map { |c| c.attributes.slice('title','body','url','position','start_seconds','public_listing').merge('file_blob_id'=>c.file.attached? ? c.file.blob.id : nil) },
      'shares' => resource.resource_program_shares.order(:platform_program_id).pluck(:platform_program_id))
    %w[file thumbnail captions].each { |key| snapshot["#{key}_blob_id"] = resource.public_send(key).attached? ? resource.public_send(key).blob.id : nil }
    last = resource.resource_versions.order(number: :desc).first
    return last if last && last.snapshot == snapshot
    version = resource.resource_versions.new(actor: actor, actor_name: actor&.full_name || 'System', number: (last&.number || 0) + 1, snapshot: snapshot)
    %w[file thumbnail captions].each { |key| version.public_send(key).attach(resource.public_send(key).blob) if resource.public_send(key).attached? }
    blobs=resource.resource_contents.includes(file_attachment: :blob).filter_map{|c|c.file.blob if c.file.attached?}
    version.content_files.attach(blobs.uniq(&:id)) if blobs.any?
    version.save!
    version
  end
end
