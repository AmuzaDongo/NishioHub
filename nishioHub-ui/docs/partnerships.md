# Partner With Us

Public page: `/partner-with-us`. The home school CTA, shared For Schools menu and organization footer links use this route. The existing contact form still accepts legacy partnership inquiries.

## Requests and staff follow-up

`POST /api/v1/platform/partnership-requests` accepts `partnership_request`:

- `organization_name`, `name`, `contact_role`, `email`, `phone_number`
- `focus`: `schools`, `universities`, `businesses`, `ngos`, `government`, `community`
- `message`: 20–500 characters; `terms_accepted`: true
- `request_kind`: `partnership` or `meeting`
- `preferred_at`: future ISO 8601 time with explicit timezone, required for meetings
- `submission_key`: UUID v4, retained across retries of unchanged form data

Visitors may submit without an account. Numbers use the shared `react-phone-number-input` country selector and are normalized to international format on both client and server. The backend validates required data, stores the consent policy version, enforces the shared atomic five-per-hour contact throttle and rejects conflicting reuse of a submission key. Responses expose only receipt details, including the tracking reference.

Authorized admins and super admins with `system.manage` receive in-app notifications linking to `/admin/inquiries`. The inbox shows the organization, contact role, phone link, focus, proposal and optional preferred meeting time in the platform timezone. Staff can mark requests reviewed and follow up using the email or phone links. Other roles cannot read the inbox.

“Book a Meeting” opens the meeting version of the inquiry form. It records a preferred time for staff confirmation; it does not claim to reserve a calendar slot or send a meeting invitation. Configure a calendar integration separately if automatic booking becomes a product requirement.

The partnership community strip preserves the reference's visual position but uses neutral community icons. No unverified institutional logos or implied commercial endorsements are published.

## Hero artwork

Asset: `public/images/partnerships/partnership-hero.webp` (generated promotional illustration; no real partnership is implied).

Generated using the built-in imagegen tool, then resized/compressed with ImageMagick for the website. Final generation prompt:

> Use case: photorealistic-natural. Asset type: wide website partnership hero photograph. Primary request: two smiling Ugandan Black African professionals, a woman with braided hair in a purple blazer and a man with glasses in a navy suit, shaking hands across a desk with an open laptop in a bright contemporary education organization office. Composition: landscape 2:1, waist-up, handshake clearly visible in center, greenery and softly blurred office background. Natural warm daylight, authentic skin texture, polished welcoming editorial photograph. No text, no logos, no watermarks. This is illustrative promotional artwork, not a documentary photograph.

Apply the additive Rails migration `20261117010000_add_partnership_details_to_public_inquiries.rb` when deploying.

## Verification

Rails: 491 tests, 4,232 assertions passed. UI: TypeScript, ESLint and production build passed. Headless Chrome exercised required-field focus, opportunity preselection, country-aware phone entry, successful partnership and meeting submissions, receipt references, mobile overflow checks, admin structured inbox and review actions. Temporary QA records were removed afterward.
