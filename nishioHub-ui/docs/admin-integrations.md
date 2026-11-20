# Admin Integrations

`/admin/integrations` uses Tailwind and the shared admin workspace, preserving the
reference layout: five metrics, category tabs, connected-provider cards, available
providers, and an activity feed. The sidebar, dashboard service-settings link,
and the Integrations section in System Settings open the page.

## Supported management

The catalog has 12 providers: Pesapal, SendGrid, SMS Uganda (Africa’s Talking),
Google Analytics, Google Drive, YouTube, OpenAI, Zoom, MTN MoMo, Microsoft 365,
Slack, and Sentry. Metrics derive from persisted configuration; nothing is marked
Active by default. Category and search filters operate on the API.

Administrators can configure or replace provider credentials, run connection
checks, pause/resume, disconnect, inspect credential-presence metadata, open
provider documentation, and filter/paginate integration logs. Writes and checks
require `dashboard.read` and `system.manage`. Reads require `dashboard.read`.
Both Admin and Super Admin roles are supported, including additional role grants.

Credentials are encrypted at rest using AES-256-GCM with a purpose-bound key
obtained from the Rails application key generator. Keep the application's stable
secret key configuration across restarts/deployments. Secret values are never
returned to the UI, audit records, or activity logs. Rails request logging filters
the complete credentials object. Blank fields preserve existing credentials;
disconnecting removes the locally stored encrypted values. Provider-side revocation
is a separate account operation.

State semantics:

- Available: no stored credentials.
- Needs Attention: configured but unverified, or the last check failed.
- Active: the last check succeeded and the integration is not paused.
- Paused: configured and explicitly paused. Resume requires another check.

Checks use authentication/account metadata endpoints, never send messages or
perform financial transactions. A successful check verifies API access to that
endpoint; it is not proof of delivery, a completed payment, storage sync, or every
possible provider permission. This workspace does not implement payment checkout,
mail/SMS dispatch, automatic content sync, analytics script injection, or AI content
features. Existing SMTP mail delivery remains configured separately.

Google, Microsoft, Zoom, Slack, and Sentry use provider-issued access tokens.
Access tokens are entered manually; OAuth consent/refresh automation is outside
this workspace. Replace expiring tokens in Manage. SendGrid needs access to the
scopes endpoint. MTN requires an already provisioned Collection API user, API key,
and subscription key. Pesapal/MTN/SMS support separate sandbox environments.
SMS Uganda explicitly uses Africa’s Talking rather than an unidentified gateway.

## API and safeguards

- `GET /api/v1/admin/integrations?q=&category=`
- `PATCH /api/v1/admin/integrations/:key` with `integration: {credentials, environment, lock_version}`
- `POST /api/v1/admin/integrations/:key/check` with `lock_version`
- `POST /api/v1/admin/integrations/:key/status` with `action_name: pause|resume`, `lock_version`
- `DELETE /api/v1/admin/integrations/:key?lock_version=`
- `GET /api/v1/admin/integrations/logs?provider=&outcome=&page=`

Revisions prevent lost updates, including competing first connections (the
unconfigured catalog revision is null until a database record exists). Checks reserve an attempt, release database locks
before network access, and recheck permissions and configuration revisions before
saving results. Credential changes during an in-flight check invalidate its result.
Checks are rate limited to one attempt per integration every 30 seconds. Provider
URLs are fixed HTTPS destinations; credentials cannot supply arbitrary endpoints.
No redirects or ambient proxies are followed. TLS verification remains enabled.
Connection/write/read deadlines, an overall timeout, response-size bounds, and
provider-specific JSON success checks prevent misleading success responses.
Provider response bodies and errors are never copied into logs.

Migration: `20261111060000_create_platform_integrations.rb` via `bin/rails db:migrate`.
No third-party accounts or live credentials are created by this migration.
Provider credentials are required to verify a real account connection.

## Provider references

- [Pesapal authentication](https://developer.pesapal.com/how-to-integrate/e-commerce/api-30-json/authentication)
- [SendGrid scopes](https://www.twilio.com/docs/sendgrid/api-reference/api-key-permissions/retrieve-a-list-of-scopes-for-which-this-user-has-access)
- [Africa’s Talking](https://developers.africastalking.com/docs)
- [MTN MoMo API](https://momodeveloper.mtn.com/api-documentation/api-description)
- [Google Drive about](https://developers.google.com/workspace/drive/api/reference/rest/v3/about/get)
- [Google Analytics account summaries](https://developers.google.com/analytics/devguides/config/admin/v1/rest/v1beta/accountSummaries/list)
- [YouTube channels](https://developers.google.com/youtube/v3/docs/channels/list)
- [OpenAI models](https://developers.openai.com/api/reference/resources/models/methods/list)
- [Zoom users](https://developers.zoom.us/docs/api/users/)
- [Microsoft Graph profile](https://learn.microsoft.com/en-us/graph/api/user-get?view=graph-rest-1.0)
- [Slack authentication check](https://docs.slack.dev/reference/methods/auth.test/)
- [Sentry authentication](https://docs.sentry.io/api/auth/)
