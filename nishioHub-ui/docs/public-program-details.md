# Public program details

Route: `/programs/:id`. Program cards open this page. Old `/programs?program=:id` links redirect to the canonical route.

The page follows the supplied purple/yellow hero, six-tab content area, learning cards and right-hand summary design using Tailwind and the shared layout. Tabs, intro and inquiry dialogs have URL state (`tab`, `intro`, `join`). Tabs support arrow/Home/End keyboard navigation. Data loads with a page skeleton; unavailable, draft and invalid records have recovery links.

## Published data

`GET /api/v1/platform/programs/:id` extends the public summary with:

- `public_details`: benefits, curriculum modules, requirements, FAQs, published schedule notes, duration/cost/certificate labels and optional intro video URL.
- `mentors`: only active assigned mentors whose profiles are verified and published. Public names, titles, IDs and portraits only; no emails, phones, student identities or private booking times.
- `availability`: open/upcoming/closed/full/ended, derived from registration dates, program end date, allocated membership capacity and the platform timezone. The UI describes inquiries rather than promising reserved seats.

Program listings remain lean and do not include the detail arrays or mentor records. Unpublished programs return 404 through public endpoints.

Existing records default to empty public details. Actual objectives provide learning outcomes where a curriculum has not been authored. Missing costs and certificates are shown as “Contact our team,” not invented free participation or awards. The free CTA is used only when the configured cost label is exactly “Free” (case insensitive).

## Administration

Apply migration `20261119010000_add_program_public_details.rb`. The admin program details editor includes **Public Program Details** with duration, cost, certificate, optional HTTPS MP4/WebM intro, benefits and requirements, plus add/remove/reorder controls for curriculum, schedule notes and FAQs. The existing Assigned Mentors picker controls public program mentor assignments; unverified/unpublished accounts stay hidden publicly.

Existing authorization, optimistic locking and auditing cover changes. The backend validates supported fields, array counts, lengths and safe HTTPS image/video URLs. Multipart requests serialize `public_details_json` so banner replacement and editorial changes commit together. Unknown fields and malformed JSON are rejected.

## Joining and school inquiries

Individual and school actions open the existing validated program inquiry form, now with an `interest_type` of `individual` or `school`. The server snapshots program references, protects idempotent retries, shares the existing contact throttle, and notifies authorized staff. The admin inbox labels school inquiries and links to existing enrollment management.

Requests do not create accounts, enroll children, reserve capacity or issue certificates automatically. Staff confirms eligibility and school/guardian participation where relevant. Closed/full programs still accept availability questions without presenting an open enrollment claim.

## Introduction

A configured video uses native controls. Without one, the intro opens an illustrated overview linked to the real curriculum. Video errors fall back to that overview.

## Generated artwork

Built-in imagegen assets, compressed with ImageMagick:

- `public/images/programs/young-learners-hero.webp`
- `public/images/programs/learning-activities-strip.webp`

These are illustrative promotional images. Uploaded program banners take precedence; the primary-school fallback is only used for primary-tagged programs.

Hero prompt:

> Use case: photorealistic-natural. Asset type: wide primary school mentorship program hero photo. Three smiling Black Ugandan primary-school learners, two girls with neatly braided hair and one boy, wearing purple school sweaters over white shirts, seated together at a classroom desk with books and pencils. Bright sunlit school courtyard and classroom background with green trees softly blurred. Friendly candid editorial promotional photograph, authentic skin texture, natural smiles. Wide landscape 2:1 composition with all heads and upper torsos visible, boy center and girls either side. No text, logos or watermark. Illustrative promotional artwork, not documentation of real enrolled children.

Learning cards prompt:

> Use case: photorealistic-natural. Asset type: four-panel horizontal photo strip for primary-school program curriculum cards. Four equal-width independent photographic panels from left to right: (1) a Black Ugandan primary-school boy in purple uniform reading a book at a school desk, (2) a Black Ugandan primary-school girl with braids in purple uniform thinking with a smile and looking upward, (3) close-up of dark-skinned hands holding a healthy green seedling with soil, (4) a Black Ugandan primary-school boy in purple uniform exploring with binoculars outdoors. Natural sunny editorial photography, green school garden backgrounds, subjects centered within each panel with faces fully visible. Very wide 4:1 horizontal composition, straight aligned panels, no text, no icons, no labels, no decorative borders, no watermarks. Illustrative promotional images.

## Verification

502 Rails tests / 4,397 assertions passed. Coverage includes public mentor filtering, private-data exclusion, registration/capacity availability, content validation, school interest types, idempotent inquiries without enrollment, and multipart content/banner updates. TypeScript, ESLint and production build passed. Headless Chrome verified card navigation and legacy redirects, all six tabs, carousel, mentor profiles, intro fallback, individual/school inquiry dialogs, school context in the admin inbox, admin price/FAQ editing with a replacement banner, public visibility of saved changes, invalid IDs and mobile overflow checks. Temporary QA records were removed after testing.

Shared header/footer `children` props were made optional to match their standalone usage. `MainLayout` supports an optional announcement flag so this details page can use the reference header without changing announcement defaults elsewhere. Its search action opens program discovery through an optional shared-layout callback.
