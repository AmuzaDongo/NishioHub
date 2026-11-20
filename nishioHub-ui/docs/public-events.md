# Public Events

Routes: `/community-events` and `/community-events/:id`. Legacy `?event=ID` links redirect to the full details page. Uses the shared public header, platform branding and Tailwind. The learner `/events` and admin `/admin/events` retain their existing screens.

## Working flows

- Discovery uses `GET /api/v1/platform/events/discover`; details use `GET /api/v1/platform/events/discover/:id`.
- Only published, undeleted events are public. System Settings → show events on public pages controls both endpoints. This setting defaults to off; enable it to publish the catalog.
- Upcoming, Live (online/hybrid currently running), Past and Featured tabs query actual schedules and explicit featured status. Six records per page; type counts describe the active tab before filters.
- Apply Filters combines event type, audience, mode, search and date range. Clear All resets filters. Discovery filters and event detail section selection persist in their respective URLs. Date boundaries use the platform timezone, including custom ranges up to 366 inclusive days.
- Public categories group training with workshops, conferences with career talks, and networking/launch/challenge/other under community events. Existing event types are preserved.
- Admin event create/edit includes audience tags, featured status and public recording URL. No audience selection welcomes all audiences. Public recording links must use HTTPS and are exposed only after the event ends.
- Anonymous visitors view details then log in or create an account. Validated canonical `/community-events/ID` and legacy `/community-events?event=ID` return destinations are accepted. Registration requires an explicit confirmation after login; there is no automatic enrollment.
- Registered visitors can save their calendar reminder (none, 15/30/60 minutes or one day), then download an ICS file containing that reminder. Reminder preferences are exposed only to the registered account.
- Existing authenticated registration/cancellation APIs enforce capacity, idempotence, publication and the global registration switch for every role. Meeting links appear only for the viewer's own registration before the event ends. No attendee roster or email is exposed publicly.
- Host an Event opens `/host-an-event`, with authenticated eligible account submission and the request approval workflow described in `event-hosting.md`.
- Empty tabs offer a relevant alternate tab or clear filters, plus hosting/creation. Event-detail errors offer retry; filters remain usable during background refreshes. Empty, loading, disabled, full, ended and API error states are handled explicitly. Catalog refreshes every minute and selected details every 30 seconds.

Migration: `20261114000000_add_public_event_discovery.rb`. Apply with the project's configured Ruby and Rails environment before deployment. Existing records default to all audiences, not featured, with no public recording.

## Promotional image

`public/images/events/public-events-hero.webp` is an optimized generated promotional image, not documentation of an actual event. Event cards use their saved banner or established category fallback image. No fictional event records are seeded.

Generated source: `/home/dongo/.codex/generated_images/01a1b749-277d-7543-a1b0-86c136c971dd/exec-d3fe5718-7618-460a-8b57-8dbba74481a2.png`.

Prompt: Photorealistic website banner photograph for a Ugandan educational events platform. Wide landscape 3:2 composition. A confident smiling Black Ugandan secondary school girl aged about 16 with neat long braided ponytail, wearing a purple school sweater over white collared shirt and dark tie, holding a handheld microphone and speaking at a school learning workshop in a bright modern library. The girl is foreground center-right, whole head/hair visible and microphone clear. Supportive smiling Black Ugandan learners and an adult facilitator are softly blurred behind her; warm natural daylight, wooden tables and bookshelves, subtle purple education brand palette. Empowering respectful school environment, authentic joyful expressions, realistic anatomy, professional commercial photography. No text, no logos, no graphic overlays, no borders. Leave soft background on left for website copy. This is a fictional promotional illustration, not a real event photograph.

## Verification

- Full Rails suite: 439 tests, 3,490 assertions, zero failures/errors/skips.
- TypeScript and production build pass. Targeted ESLint has zero errors and one existing Fast Refresh export warning in the event editor.
- Browser checks at 1200px desktop and 390px mobile: no horizontal overflow, visible images load, pagination, applied type filters, clear, search, featured/live/past tabs, recording links, actual sign-in return, registration, reminder saving, ICS download with the saved alarm, cancellation, detail-error retry and empty Upcoming → Past navigation all pass; no JavaScript exceptions.
- Temporary browser fixtures were confined to the isolated test database and removed before the regression suite.

## Local setup completion

Public event visibility was enabled in the local development database with a settings audit entry. The local API was verified with zero upcoming and one past published event; existing event schedules were preserved. Homepage cards open the selected public event directly. Admin event changes and system setting changes invalidate public discovery, selected event and homepage caches immediately. Production visibility remains controlled by its own settings.
