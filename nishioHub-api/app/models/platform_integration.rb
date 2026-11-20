class PlatformIntegration < ApplicationRecord
  belongs_to :updated_by,class_name:'User',optional:true
  validates :provider_key,inclusion:{in:IntegrationCatalog::PROVIDERS.map{|p|p[:key]}},uniqueness:true
  validates :environment,inclusion:{in:%w[live sandbox]}
  validates :paused,:verified,inclusion:{in:[true,false]}
  validate do
    errors.add(:environment,'sandbox is available for Pesapal, MTN MoMo and SMS Uganda') if environment=='sandbox'&&!provider_key.in?(%w[pesapal mtn_momo sms_uganda])
  end
  def self.encryptor
    key=Rails.application.key_generator.generate_key('platform-integration-credentials-v1',32)
    ActiveSupport::MessageEncryptor.new(key,cipher:'aes-256-gcm',serializer:JSON)
  end
  def credentials
    encrypted_credentials.present? ? self.class.encryptor.decrypt_and_verify(encrypted_credentials,purpose:'integration-credentials') : {}
  end
  def credentials=(value)
    self.encrypted_credentials=value.present? ? self.class.encryptor.encrypt_and_sign(value,purpose:'integration-credentials') : nil
  end
  def configured? = encrypted_credentials.present?
  def status = !configured? ? 'available' : paused? ? 'paused' : verified? ? 'active' : 'attention'
  def self.ready_credentials(key)
    row=find_by(provider_key:key)
    raise Administration::Rejected.new('Integration is not verified and active',:unprocessable_entity) unless row&.status=='active'
    row.credentials
  end
end
