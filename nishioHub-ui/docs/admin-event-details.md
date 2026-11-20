# Event Details

`/admin/events/:id` follows the supplied Event Details reference using the existing admin shell and Tailwind: event hero, performance ring, section tabs, information, quick actions, agenda, registration summary, growth and rating distribution. The Events table and dashboard open this page. Header search uses platform search; section searches filter their saved records.

## Access and data

Admin and Super Admin accounts need `dashboard.read`. All mutations independently require `dashboard.manage`, enforced by the API. Read-only controls remain disabled. Counts and charts come from saved records; no sample analytics are returned by the API.

Registered means active RSVPs, attended means confirmed present, and No Show means explicitly absent. Unrecorded attendance is reported separately instead of being treated as absence. Attendance percentage divides confirmed presence by active registrations. Ratings use participant feedback; empty ratings show no reviews. Growth uses cumulative current active registrations over seven actual past timestamps. Comparison uses the preceding published event of the same type and program, and is omitted without a baseline.

## Actions and sections

- Edit event metadata, banner, capacity and schedule through the existing validated editor. A future reschedule shifts agenda times by the same offset; a shortened schedule that excludes agenda entries is rejected atomically. Started event schedules remain locked.
- Registrations and Attendees use the same saved roster, with search, pagination, registration/attendance filters, active-account selection, capacity checks, cancellation and explicit present/absent/unrecorded controls.
- Agenda supports create/edit/remove, chronological ordering and schedule validation. Speakers support name, title, bio and an optional HTTP(S) photo URL.
- Materials support HTTP(S) links or private uploaded PDF, text, image, audio/video files within the platform limit (maximum 10 MB). Removed materials are hidden without purging their stored content. Registered participants access material files through authenticated endpoints.
- Send Announcement delivers in-app notifications to active registered accounts, respecting preferences. Retries with the same request key do not resend; reusing a key for different text returns a conflict. Delivery/skipped counts are reported.
- Duplicate creates a future draft, copying metadata, banner, speakers, materials and shifted agenda. Registrations, attendance, feedback and announcements are excluded. The agenda must fit the new duration.
- Delete retains the database history and hides the event from admin/learner discovery and content access. Published events that have not ended must first be cancelled. Destructive UI actions require confirmation.
- Calendar, attendee CSV and event report downloads are functional. The report includes real counts, attendance, ratings and cumulative registrations, with spreadsheet-safe values. Administrative writes and exports are audited; revisions prevent stale edits.

## Participant feedback

The existing learner Events dialog displays agenda, speakers and materials for registered participants. Confirmed attendees may submit or update one rating/comment after a published event ends. Feedback updates require the current revision and immediately feed the admin feedback section and report. Nonparticipants, cancelled RSVPs and unconfirmed attendees cannot submit feedback.

## API and migration

Apply `20261110050000_create_event_details.rb` with `bin/rails db:migrate`.

Admin routes under `/api/v1/admin/events/:id` include `/details`, `/sections/:section` (list/create), `/sections/:section/:item_id` (edit/remove), `/materials/:item_id/file`, `/announcement`, `/duplicate`, `/report` and DELETE on the event itself. Existing registration/calendar/publication endpoints remain in use.

Participant routes under `/api/v1/events/:id`: `/details`, PUT `/feedback` and `/materials/:item_id/file`. Each checks current registration and event visibility. Material files are not exposed as unrestricted storage URLs.

Verification covers integration permissions, revisions, validation, file privacy, feedback eligibility, announcement idempotency, duplication, rescheduling and soft deletion. Browser checks cover all eight tabs, CRUD workflows, uploads/downloads, announcements, reports, duplication/deletion, learner feedback and desktop/mobile overflow.

Final validation: production build passed, and desktop/mobile browser workflows passed without runtime exceptions. The full Rails regression run completed with 354 tests and 2,252 assertions; the only failures were the existing no-role user/required-phone test and the existing email-verification redirect expectation. A final targeted event run also covers completed-event deletion statistics. TypeScript continues to report the nine existing `StudentProfile`/`EditProfile` errors; no errors were reported in this implementation. Temporary browser fixtures were removed from the isolated test database and the temporary API/UI/browser processes were stopped.

Subsequent validation: the previously noted Rails failures and profile TypeScript errors were resolved by the [profile fixes across roles](profile-role-fixes.md). The full suite and TypeScript checks now pass.
