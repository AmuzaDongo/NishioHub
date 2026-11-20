class IntegrationCatalog
  CATEGORIES=%w[payments communication storage analytics productivity other].freeze
  PROVIDERS=[
    ['pesapal','Pesapal','payments','Payments','Verify access to your card, mobile money and bank payment gateway.','https://developer.pesapal.com/how-to-integrate/e-commerce/api-30-json/authentication',%w[consumer_key consumer_secret]],
    ['sendgrid','SendGrid','communication','Email','Manage and verify transactional email API credentials.','https://www.twilio.com/docs/sendgrid/api-reference/api-key-permissions/retrieve-a-list-of-scopes-for-which-this-user-has-access',%w[api_key]],
    ['sms_uganda','SMS Uganda','communication','SMS','Verify an Africa’s Talking account for Uganda SMS services.','https://developers.africastalking.com/docs',%w[username api_key]],
    ['google_analytics','Google Analytics','analytics','Analytics','Verify read access to Google Analytics accounts.','https://developers.google.com/analytics/devguides/config/admin/v1/rest/v1beta/accountSummaries/list',%w[access_token]],
    ['google_drive','Google Drive','storage','Storage','Verify access to your Google Drive account.','https://developers.google.com/workspace/drive/api/reference/rest/v3/about/get',%w[access_token]],
    ['youtube','YouTube','other','Media','Verify access to the authenticated YouTube channel.','https://developers.google.com/youtube/v3/docs/channels/list',%w[access_token]],
    ['openai','OpenAI','other','AI','Verify your AI API key and model-list access.','https://developers.openai.com/api/reference/resources/models/methods/list',%w[api_key]],
    ['zoom','Zoom','communication','Meetings','Verify account access for virtual meeting services.','https://developers.zoom.us/docs/api/users/',%w[access_token]],
    ['mtn_momo','MTN MoMo','payments','Payments','Verify Collection API authentication for MTN Mobile Money.','https://momodeveloper.mtn.com/api-documentation/api-description',%w[api_user api_key subscription_key]],
    ['microsoft365','Microsoft 365','productivity','Productivity','Verify delegated Microsoft Graph account access.','https://learn.microsoft.com/en-us/graph/api/user-get?view=graph-rest-1.0',%w[access_token]],
    ['slack','Slack','productivity','Productivity','Verify workspace authentication for Slack.','https://docs.slack.dev/reference/methods/auth.test/',%w[access_token]],
    ['sentry','Sentry','analytics','Monitoring','Verify access to Sentry organizations.','https://docs.sentry.io/api/auth/',%w[access_token]]
  ].map{|key,name,category,label,description,docs,fields|{key:key,name:name,category:category,label:label,description:description,docs_url:docs,fields:fields.map{|field|{key:field,label:field.split('_').map(&:capitalize).join(' '),secret:field!='username'&&field!='api_user'}}}}.freeze
  def self.find!(key)
    PROVIDERS.find{|p|p[:key]==key}||raise(ActiveRecord::RecordNotFound)
  end
end
