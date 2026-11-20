# Admin Events

`/admin/events` uses the existing admin workspace and Tailwind utilities. The table, status tabs, summary cards, next event, calendar and type chart follow the supplied Events Management reference. It is accessible to Admin and Super Admin accounts with `dashboard.read`. Writes additionally require `dashboard.manage`; read-only controls are disabled and the API enforces permissions independently.

## Management

- Create and edit event metadata, program, event type, capacity, format, meeting URL, schedule and optional banner (JPEG/PNG/WebP, 2 MB).
- New admin events default to drafts, shown as **Scheduled**. Publish opens registration and learner discovery. Unpublishing hides discovery; cancellation retains registration history, hides discovery, blocks new registration, and sends in-app cancellation notices according to notification preferences.
- Upcoming, ongoing and completed statuses derive from published start/end times. End Event closes an ongoing event at the current time. Started schedules cannot be rewritten. Cancelled events cannot be reopened or edited.
- Search, filter, sort and paginate saved records. Select rows to export them; otherwise Export downloads the filtered result. Spreadsheet formula cells are escaped.
- Import uses a downloadable template, a read-only preview and an atomic commit. UTF-8 CSV, 1–100 rows, 256 KB maximum. Program IDs must identify active programs; times need explicit offsets. Exact duplicates are rejected. Upload banners after import.
- View Details opens `/admin/events/:id`, the full Event Details page, with a paginated registration roster. Add up to 100 active accounts, export registrations, download ICS, cancel an unattended RSVP, or record present/absent/unrecorded attendance after the event starts. Capacity checks are serialized with learner registration writes. Registration reactivation preserves the record and clears previous attendance.
- Event and attendance writes use `lock_version` to reject stale changes. Administrative changes and exports are audited.

## Data and time

Summary cards and the donut use all saved events. Completed/upcoming exclude drafts and cancellations. Total Attendees counts registered RSVPs on non-cancelled events, including completed events; it is not a unique people count. Growth compares current versus preceding 30-day windows and is omitted when no baseline exists. The donut groups training/talk/challenge/mentorship with Other.

The calendar uses the platform timezone, starts on Monday, and marks multi-day overlaps. Calendar clicks filter table rows by date. Calendar events respect the current filters and are capped at 500 with a narrowing message. Next Upcoming Event uses the next published future event across the platform.

## API and migration

Apply `20261110040000_expand_admin_events.rb` with `bin/rails db:migrate`. Existing events retain their categories, registrations and attendance. `event_type` is separate from the four legacy learner categories.

The API is under `/api/v1/admin/events`: index, show, create, update, `/:id/status`, `/:id/calendar`, `/:id/attendees` (list/add), `/:id/attendees/:registration_id` (update), `/:id/attendees/export`, `/people`, `/export`, `/import-template`, `/import-preview` and `/import`. Updates submit the event form snapshot, explicit-offset start/end times and displayed lock version. Publication changes use the status endpoint.

Dashboard links and the admin sidebar open this workspace. `/admin/events?action=create` opens the editor. `/admin/events/:id` opens details; legacy `/admin/events?event=ID` links redirect to it. The existing learner Events page shares these records and handles cancelled events without offering registration or reminders.

## Verification

Integration coverage: admin/member/read-only access, stale revisions, validation, image upload/removal, publication/cancellation, capacity, attendance, registration scoping, timezone overlaps, reporting, import atomicity/duplicates and safe exports. Browser checks cover create/edit/publish/cancel, account selection, attendance, filters, pagination, calendar selection, CSV preview/import, CSV/ICS downloads and desktop/mobile overflow.

Final checks: 17 event integration tests passed; the full Rails suite completed with 347 tests, 2,173 assertions, two unrelated failures (the no-role user test omits the required phone number, and email verification expects a redirect while the endpoint returns JSON). Production build passed. TypeScript reports the nine existing `StudentProfile`/`EditProfile` type errors and no errors in the event implementation. Temporary browser fixtures were removed from the isolated test database, and the temporary API/UI/browser processes were stopped.

Subsequent validation: the previously noted Rails failures and profile TypeScript errors were resolved by the [profile fixes across roles](profile-role-fixes.md). The full suite and TypeScript checks now pass.
