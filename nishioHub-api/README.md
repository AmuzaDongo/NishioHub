# nishioHub API — Rails 8.1 (API-only)

The nishioHub backend. A Rails 8.1.4 API-only service backed by PostgreSQL,
with JWT access tokens, database-backed refresh tokens, and bcrypt passwords.
It is the only backend in this project.

## Architecture

- `nishioHub-ui/` — React + Vite frontend. Reads `VITE_API_BASE_URL`.
- `nishioHub-api-rails/` — this Rails API, served on port 3000.
- PostgreSQL — the only data store.

The frontend calls the Rails API directly. There is no proxy and no second
backend.

## Requirements

- Ruby 3.3.6 (see `.ruby-version`)
- PostgreSQL 14+
- Bundler 2.5+

## Local setup

```bash
cd nishioHub-api-rails
bin/setup
cp .env.example .env
# edit .env: DATABASE_URL, SECRET_KEY, EMAIL_TOKEN_SECRET
bin/rails db:create db:migrate db:seed
bin/rails server -p 3000
```

The API is then at `http://127.0.0.1:3000/api/v1`.

Run the frontend in a second terminal:

```bash
cd nishioHub-ui
npm ci
npm run dev
```

`nishioHub-ui/.env.development` already points at
`http://127.0.0.1:3000/api/v1`.

`config/database.yml` reads `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`,
`DB_NAME`, and `DB_NAME_TEST`, and falls back to the local `nishiohub` role.
`DATABASE_URL` overrides those values when present.

## Authentication

- `POST /api/v1/auth/register` — JSON `{full_name, email, password, role_id}`.
  A blank `role_id` defaults to the `user` role; an unknown `role_id` returns
  `400 {"detail":"Invalid role_id"}`.
- `POST /api/v1/auth/login` — `application/x-www-form-urlencoded` with
  `username` (email) and `password`. Returns
  `{access_token, refresh_token, token_type}`.
- `POST /api/v1/auth/refresh?refresh_token=...` — returns a new access token.
- `POST /api/v1/auth/logout?refresh_token=...` — revokes the refresh token.

Access tokens are HS256 JWTs with `sub` (email) and `exp` (60 minutes). Refresh
tokens are HS256 JWTs with `sub` and `exp` (7 days) and are also stored in
`refresh_tokens`; logout sets `revoked = true`. Refresh does not rotate the
refresh token.

Send the access token as `Authorization: Bearer <token>`.

## Mentor feature

The mentor flow is fully API-backed:

- **Directory** — `GET /api/v1/mentors` supports `q`, `skill`, `available`,
  `sort` (`rating`, `price_low`, `price_high`), `page`, and `per_page`.
  `GET /api/v1/services` is the service directory used by the frontend's
  "Browse Mentors" page and supports `q`, `category_id`, `mentor_id`,
  `min_price`, `max_price`, `sort`, `page`, and `per_page`.
- **Detail** — `GET /api/v1/mentors/:id` returns the profile, skills,
  languages, education, experience, rate, rating aggregate, services, reviews,
  and availability.
- **Availability** — public `GET /api/v1/mentors/:id/availability`; the owning
  mentor can create, update, and delete slots under
  `/api/v1/mentors/me/availability`.
- **Bookings** — a mentee creates a booking with `POST /api/v1/bookings`
  (`service_id`, `scheduled_at`, optional `availability_slot_id`). Both
  participants list their bookings with `GET /api/v1/bookings`; the mentor can
  confirm or complete, either participant can cancel, and every transition is
  role- and participant-guarded.
- **Reviews** — `POST /api/v1/bookings/:id/review` is limited to the mentee who
  owns a completed booking and can run only once. `GET /api/v1/reviews` and
  `GET /api/v1/mentors/:id/reviews` expose the reviews.
- **Self-profile** — `GET/PATCH /api/v1/mentors/me` and
  `GET /api/v1/mentors/me/stats` for the mentor dashboard.
- **My Profile (self-service)** — `GET/PATCH /api/v1/me/mentor_profile` for the
  signed-in mentor's own profile, including private fields (`email`,
  `is_published`). A missing profile row is created idempotently on first
  access. `POST/DELETE /api/v1/me/mentor_profile/avatar` manage the profile
  picture. The public `GET /api/v1/mentor_profiles/:id` (and
  `GET /api/v1/mentors/:id`) never exposes `email` or `is_published`.

Errors use `{"detail": "..."}`; validation failures return `422` with
`{"detail": ["..."]}`. Unauthenticated requests return `401`, forbidden
requests `403`, and missing resources `404`.

### Seed accounts

`bin/rails db:seed` creates four mentors, two mentees, six services,
availability slots, bookings, and reviews. All seeded accounts use the password
`password123`:

- Mentors: `alex@nishiohub.com`, `sarah@nishiohub.com`,
  `david@nishiohub.com`, `maya@nishiohub.com`
- Mentees: `carlos@example.com`, `emma@example.com`

## Avatar storage

Profile pictures use Rails ActiveStorage:

```bash
bin/rails active_storage:install   # already applied in this repo
bin/rails db:migrate
```

`config/storage.yml` defines `local` (development/production default) and
`test` (test suite). The development and test environments set
`config.active_storage.service` to `:local` and `:test` respectively, so the
app boots and the tests run without any cloud credentials.

Production defaults to `:local` (files under `storage/`). To use S3 instead,
add `gem "aws-sdk-s3", require: false` to the Gemfile, set
`config.active_storage.service = :amazon` in
`config/environments/production.rb`, and provide `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, and `AWS_BUCKET`. The `amazon` service
block is already present in `config/storage.yml`.

Avatar rules: JPEG, PNG, or WebP only; maximum 5 MB. Replacing an avatar purges
the previous blob, and deleting it returns `204` with `avatar_url: null`.

## Categories

Categories are the public taxonomy for services and mentors. The frontend reads
them from `GET /api/v1/categories` and links to `/categories/:slug`.

- **Public reads** — `GET /api/v1/categories` returns active categories ordered
  by `position` (bare array, `skip`/`limit` supported). `GET
  /api/v1/categories/:id` accepts either a numeric id or a slug. `GET
  /api/v1/categories/by-slug/:slug` is the explicit slug lookup. Inactive
  categories return `404` to the public.
- **Admin writes** — `POST/PATCH/DELETE /api/v1/categories` are admin-only
  (`401` unauthenticated, `403` non-admin). `GET
  /api/v1/categories?include_inactive=true` is admin-only and includes inactive
  categories.
- **Image** — `PATCH /api/v1/categories/:id/image` (multipart field `image`)
  uploads or replaces the image; `DELETE /api/v1/categories/:id/image` removes
  it (`204`). PNG, JPEG, or WebP only, maximum 5 MB. Replacing purges the old
  blob. The JSON exposes `image_url` (absolute, `null` when absent) and
  `image_metadata` (`alt`, `content_type`, `byte_size`).
- **Slugs** — generated from the name when blank, stable on rename, unique at
  the database level. The admin can set an explicit slug.
- **Destroy** — a category used by services returns `422` with the service
  count; unused categories are deleted and their image is purged.

The legacy singular `/api/v1/category` routes remain as aliases for the public
read endpoints and admin writes.

### Seed accounts

`bin/rails db:seed` creates an admin account (`admin@nishiohub.com` /
`password123`) plus the mentor/mentee demo accounts. Categories are seeded with
positions, one inactive category, and two with ActiveStorage images.

## Endpoints

| Method | Path | Auth |
|---|---|---|
| POST | `/api/v1/auth/register` | public |
| POST | `/api/v1/auth/login` | public |
| POST | `/api/v1/auth/refresh` | refresh token |
| POST | `/api/v1/auth/logout` | refresh token |
| GET | `/api/v1/users` | bearer |
| GET | `/api/v1/users/me` | bearer |
| GET | `/api/v1/users/verify-email` | public |
| GET | `/api/v1/users/profile` | public |
| POST | `/api/v1/users/profile` | public |
| GET | `/api/v1/users/profile/:id` | public |
| PUT/PATCH | `/api/v1/users/profile/:id` | public |
| DELETE | `/api/v1/users/profile/:id` | public |
| POST | `/api/v1/users/profile/:id/upload-image` | public |
| GET | `/api/v1/roles/mentor-mentee` | public |
| GET | `/api/v1/roles` | admin |
| POST | `/api/v1/roles` | admin |
| PUT/PATCH | `/api/v1/roles/:id` | admin |
| DELETE | `/api/v1/roles/:id` | admin |
| GET | `/api/v1/categories` | public |
| GET | `/api/v1/categories/:id` | public |
| GET | `/api/v1/categories/by-slug/:slug` | public |
| POST | `/api/v1/categories` | admin |
| PATCH/PUT | `/api/v1/categories/:id` | admin |
| DELETE | `/api/v1/categories/:id` | admin |
| PATCH | `/api/v1/categories/:id/image` | admin |
| DELETE | `/api/v1/categories/:id/image` | admin |
| GET | `/api/v1/category` | public (legacy alias) |
| POST | `/api/v1/category` | admin (legacy alias) |
| GET | `/api/v1/category/:id` | public (legacy alias) |
| PUT/PATCH | `/api/v1/category/:id` | admin (legacy alias) |
| DELETE | `/api/v1/category/:id` | admin (legacy alias) |
| GET | `/api/v1/mentors` | public |
| GET | `/api/v1/mentors/:id` | public |
| GET | `/api/v1/mentors/:id/availability` | public |
| GET | `/api/v1/mentors/:id/reviews` | public |
| GET | `/api/v1/mentors/me` | mentor |
| PATCH | `/api/v1/mentors/me` | mentor |
| GET | `/api/v1/mentors/me/stats` | mentor |
| GET | `/api/v1/me/mentor_profile` | mentor |
| PATCH | `/api/v1/me/mentor_profile` | mentor |
| POST | `/api/v1/me/mentor_profile/avatar` | mentor |
| DELETE | `/api/v1/me/mentor_profile/avatar` | mentor |
| GET | `/api/v1/mentor_profiles/:id` | public |
| POST | `/api/v1/mentors/me/availability` | mentor |
| PATCH | `/api/v1/mentors/me/availability/:slot_id` | mentor |
| DELETE | `/api/v1/mentors/me/availability/:slot_id` | mentor |
| GET | `/api/v1/services` | public |
| POST | `/api/v1/services` | mentor |
| GET | `/api/v1/services/:id` | public |
| PATCH/PUT | `/api/v1/services/:id` | owning mentor |
| DELETE | `/api/v1/services/:id` | owning mentor |
| GET | `/api/v1/bookings` | bearer |
| POST | `/api/v1/bookings` | mentee |
| GET | `/api/v1/bookings/:id` | participant |
| PATCH/PUT | `/api/v1/bookings/:id` | participant |
| POST | `/api/v1/bookings/:id/review` | owning mentee |
| GET | `/api/v1/reviews` | public |
| GET | `/api/v1/dashboard` | public |
| GET | `/api/v1/notifications` | public |
| POST | `/api/v1/notifications` | public |
| GET | `/api/v1/statistics` | public |
| POST | `/api/v1/uploads` | public |

Errors use `{"detail": "..."}`. Validation errors return `422` with
`{"detail": ["..."]}`.

## Tests

```bash
bin/rails db:test:prepare
bin/rails test
```

The suite covers auth, the admin guard (including a user with no role returning
`403` rather than raising), users, roles, categories, profiles, uploads,
notifications, statistics, the JWT service, the user model, and the full mentor
surface: directory filters, detail, availability ownership, booking creation,
status transitions, and review guards. The current suite is 144 runs / 344
assertions.

## Docker

```bash
docker build -t nishiohub-api-rails .
docker run --rm -p 3000:3000 \
  -e DATABASE_URL=postgres://user:pass@host:5432/nishiohub_production \
  -e SECRET_KEY=... \
  -e SECRET_KEY_BASE=... \
  nishiohub-api-rails
```

The image uses `bin/docker-entrypoint`, which creates `tmp/pids` and runs
`bin/rails db:prepare` before the server starts. `SECRET_KEY_BASE` is required
by Rails in production; `SECRET_KEY` is the JWT signing key used by this app.

## Notes

- `GET /api/v1/users` returns only the caller. The frontend directory remains
  mock-backed until a dedicated user-directory endpoint is added.
- `DELETE /api/v1/users/profile/:id` returns `{"detail":"Profile deleted"}`.
- Deleting a role nullifies its users' `role_id` instead of deleting the users.
- `notification`, `statistics`, and `uploads` are mounted so the surface is
  complete; remove the routes in `config/routes.rb` if you do not need them.

## Rails 8 notes

- Resolved versions: Rails 8.1.4, Ruby 3.3.6, Puma 8.0.2, pg 1.7.0,
  bcrypt 3.1.22, jwt 2.10.3, rack-cors 3.0.0.
- `config.load_defaults 8.1` is set in `config/application.rb`. The generated
  `db/schema.rb` is `ActiveRecord::Schema[8.1]` because Rails 8.1 wrote it.
- Solid Cache, Solid Queue, Solid Cable, Thruster, and Kamal are intentionally
  not included. This is a stateless JSON API with no background jobs, no
  websockets, and no static asset pipeline; Puma and PostgreSQL cover the
  runtime. Add Solid Queue / Solid Cable only if background jobs or live
  updates are introduced later.
- `config/initializers/new_framework_defaults_8_0.rb` records that no Rails 8
  default is reverted.
- `bin/setup` and `bin/docker-entrypoint` are the Rails 8 entrypoints; the
  Dockerfile uses the Ruby 3.3.6 slim base image.

### Mentee dashboard

The signed-in mentee's dashboard is available in the UI at `/mentee/dashboard`.
Set the UI's `VITE_API_BASE_URL` to the Rails API URL (for example,
`http://localhost:3000/api/v1`) when developing locally, and run `bin/rails db:migrate`
with the API's database environment loaded before using it.

All mentee endpoints require a bearer token and the `mentee` role:

- `GET /api/v1/me/mentee_dashboard`: profile, next active session, connected mentor,
  completed-session milestone progress, goals, earned badges, and active learning areas.
- `PATCH /api/v1/me/mentee_profile`: `{ "profile": { "school": "...", "grade": "...", "location": "...", "bio": "..." } }`.
- `POST /api/v1/me/mentee_goals`: `{ "goal": { "title": "..." } }`.
- `PATCH /api/v1/me/mentee_goals/:id`: `{ "goal": { "completed": true } }`.

Records are scoped to the authenticated user. The connected mentor is taken from
that mentee's next active session or most recent completed session. Milestones
advance in groups of five completed sessions. Badges are derived from completed
sessions and goals. Learning cards use active categories; careers and events do
not currently have API models.

Run the focused tests with:
`bin/rails test test/controllers/api/v1/mentee_dashboard_controller_test.rb`.

### Mentor My Mentorship

The mentor workspace is available at `/mentor/mentorship` in the UI, with links
from the mentor dashboard and account navigation. It requires the `mentor` role.
Run `bin/rails db:migrate` with the API database settings loaded before using it.

- `GET /api/v1/me/mentorship`: authenticated mentor profile, own bookings, connected
  mentees, active programmes (services), mentor goals, and personal resource links.
- `POST /api/v1/me/mentorship/goals`: `{ "goal": { "title": "..." } }`.
- `PATCH /api/v1/me/mentorship/goals/:id`: `{ "goal": { "completed": true } }`.
- `POST /api/v1/me/mentorship/resources`:
  `{ "resource": { "title": "...", "url": "https://..." } }`.
- `DELETE /api/v1/me/mentorship/resources/:id`: removes an owned resource link.

Session acceptance, decline, and completion use the existing
`PATCH /api/v1/bookings/:id` endpoint. Programmes use existing service creation.
Inviting a mentee copies the public mentor profile link. Resource links are saved
privately and can be copied to share in messages; adding a resource does not send
messages automatically. Availability is managed from the mentor profile.

Mentee progress is the percentage of non-cancelled bookings with this mentor
that are completed. Cancelled-only connections are excluded. Mentored hours sum
completed booking durations. Ratings come from reviews, and goals in this
workspace belong to the mentor; private mentee goals are not exposed.

Focused checks:
`bin/rails test test/controllers/api/v1/mentorship_controller_test.rb test/controllers/api/v1/mentee_dashboard_controller_test.rb`.
Use a separate test `DATABASE_URL` when the local `.env` configures a development
URL: Rails uses that URL in preference to environment-specific database names.

### Learning Area

Mentees can open `/learning-area` (alias `/mentee/learning`) from their dashboard
or account menu. The page follows the supplied Learning Area design and includes
course search, category filters, a lesson reader, saved enrolment and completion,
learning progress, consecutive activity days, and upcoming confirmed bookings.

Run `bin/rails db:migrate` before using it. The version-controlled starter catalogue
in `config/learning_catalog.json` contains seven categories, eight courses, lesson
content, practice activities, and estimated study durations. It is separate from
paid mentor services. Keep course and lesson IDs stable when editing content so
existing learner progress remains associated with its lessons.

Authenticated mentee endpoints:

- `GET /api/v1/me/learning_area`: catalogue, own enrolments and completed lessons,
  derived progress, profile name/avatar, and the next two confirmed bookings.
- `POST /api/v1/me/learning_area/:course_id/enroll`: idempotent course enrolment.
- `POST /api/v1/me/learning_area/:course_id/lessons/:lesson_id/complete`: completes
  a valid lesson in an enrolled course. Repeated requests do not double count it.

Hours sum estimated durations of completed lessons; they do not measure elapsed
browser time. Streaks use consecutive lesson-completion dates in the Rails time
zone, including a streak ending yesterday. Upcoming sessions use existing bookings.
Learner progress is always scoped to the bearer-token user.

Test with `bin/rails test test/controllers/api/v1/learning_area_controller_test.rb`.
Use an isolated test `DATABASE_URL`, as noted above.

### My Goals

The mentee goals workspace is available at `/my-goals` (alias `/mentee/goals`).
It uses the existing mentee goal records, so goal completion stays synchronized
with the overview dashboard. Mentor goals remain in the mentor workspace.
Run `bin/rails db:migrate` before using the extended goals endpoints.

- `GET /api/v1/me/mentee_goals`: own goals, milestones, vision, profile name/avatar,
  and the latest 100 goal creation/progress events.
- `POST /api/v1/me/mentee_goals`: `{ "goal": { "title": "...", "description": "...", "progress": 40, "target_date": "2027-03-31", "icon": "code" } }`.
- `PATCH /api/v1/me/mentee_goals/:id`: updates the same fields. The older
  `{ "goal": { "completed": true } }` payload remains supported.
- `DELETE /api/v1/me/mentee_goals/:id`: deletes an owned goal with its milestones
  and progress history; the UI asks for confirmation.
- `POST /api/v1/me/mentee_goals/:id/milestones`:
  `{ "milestone": { "title": "...", "target_date": "2027-02-01" } }`.
- `PATCH /api/v1/me/mentee_goals/:id/milestones/:milestone_id`: updates title,
  optional target date, or completion.
- `DELETE /api/v1/me/mentee_goals/:id/milestones/:milestone_id`: removes a milestone.
- `PATCH /api/v1/me/goal_vision`: `{ "profile": { "vision": "..." } }`.

Progress must be an integer from 0 to 100. A value of 100 marks a goal completed;
a smaller value reopens it. The legacy completion checkbox sets progress to 100
or 0. Existing completed goals are backfilled to 100 by the migration. Milestone
completion is independent of the manually maintained goal percentage.

Vision, goals, milestones, and history are scoped to the authenticated mentee.
The UI supports editing, search, status filters, and a saved vision. Talk to My
Mentor opens an existing app conversation flow for the connected mentor; learners
without a connected mentor are directed to mentor discovery. Resources opens the
Learning Area. No messages are automatically sent.

Test with `bin/rails test test/controllers/api/v1/mentee_goals_controller_test.rb`.

### My Activities

The mentee activity workspace is available at `/my-activities` (alias
`/mentee/activities`) and is linked from the mentee navigation and account menu.
`GET /api/v1/me/activities` requires an authenticated mentee and returns the user's
name/avatar, activity feed, and overall total/completed/in-progress/upcoming counts.

Activity sources are current course enrolment snapshots, timestamped lesson
completions, mentorship bookings, and goal progress events. A course snapshot and
its completed lessons count as separate activities. Cancelled bookings remain
visible as cancelled and contribute to the total, without contributing to the
three status subtotals. Future pending bookings are upcoming requests and say
that they await confirmation. Completed/cancelled booking entries use the last
booking update time; other booking entries use the scheduled time.

Run `bin/rails db:migrate` before using it. New lesson completions have their own
timestamps and a unique constraint prevents duplicate completion entries. Older
course progress appears as a saved course snapshot; the migration does not
invent historical lesson-completion times. All sources are scoped to the signed-in
learner. Events and Challenges show registered events and challenges, including organizer-confirmed attendance.

The UI provides search, category/status filters, expandable recent activities,
upcoming activities, month navigation, date filtering, and calendar status markers.
Calendar day boundaries and displayed activity times use `Africa/Kampala`.
Course and lesson activities link directly to the corresponding Learning Area
reader; mentorship and goal activities link to their existing workspaces.

Test with `bin/rails test test/controllers/api/v1/activities_controller_test.rb`.
Use the isolated test `DATABASE_URL` described above.

### My Achievements

The mentee achievement record is available at `/my-achievements` (alias
`/mentee/achievements`), linked from the shared sidebar, Learning Area, overview,
and account menu. The layout follows the supplied Achievement Dashboard reference.
Run `bin/rails db:migrate` before using the certificate endpoints.

- `GET /api/v1/me/achievements`: own completed courses, earned/locked badge rules,
  certificate records, completed mentorship sessions, and goal milestones.
- `GET /api/v1/me/achievements/record`: downloads an authenticated CSV achievement
  record. Cells are escaped to prevent spreadsheet formula interpretation.
- `GET /api/v1/me/achievements/certificates/:id`: downloads the owner's certificate
  as an SVG document, using a stable UUID record ID. Other learners receive 404.

A certificate is created once when every course lesson is completed. Existing
completed enrolments receive a certificate on their first achievements visit.
Certificate issuance time and ID stay stable on repeated completion requests.
Certificates are NishioHub course-completion records. SVG text is escaped and does
not include external scripts or resources.

Badge rules are based on real records: three courses completed in one calendar
month (Active Learner), a completed goal (Goal Setter), a completed course (Course
Completer), the Innovation & Problem Solving course (Rising Innovator), and one,
five, or ten completed mentorship sessions. Event Participant requires organizer-confirmed event attendance. The overview dashboard uses the same badge rules.
Overall progress is completed lessons divided by lessons in enrolled courses.

The UI supports search, badge details, certificate previews/downloads, milestones,
and a user-triggered device share or clipboard text fallback. No achievement data
is published automatically. The Leaderboard tab shows an empty state because no
public rankings are implemented or exposed.

Test with `bin/rails test test/controllers/api/v1/achievements_controller_test.rb`.
Use an isolated test `DATABASE_URL` as described above.

### Events

The mentee Events page is available at `/events` (alias `/mentee/events`) with the
reference banner, category tabs, event cards, calendar, summary, and quick actions.
Run `bin/rails db:migrate` before using it. To populate a local development
catalogue with the four reference-based examples, run:
`bin/rails runner db/seeds/events.rb` with the development database environment
loaded. This optional script requires an existing mentor and refuses production.

All event endpoints require authentication:

- `GET /api/v1/events`: upcoming/ongoing events, own registrations, own hosted
  events, private suggestions, and registration/attendance/upcoming totals.
- `GET /api/v1/events/:id`: event details; meeting links are shown only to the
  registered learner or organizer.
- `POST /api/v1/events`: creates an event owned by the signed-in user. The event
  payload accepts title, description, category (`workshop`, `talk`, `challenge`,
  `mentorship`), ISO8601 start/end times, location, optional HTTP(S) meeting URL,
  and optional capacity. Creation requires a future start and end after start.
- `POST /api/v1/events/:id/registration`: registers or restores one's registration,
  idempotently; locks the event to enforce capacity and rejects ended events.
- `DELETE /api/v1/events/:id/registration`: cancels one's registration and releases
  the place. Verified attended registrations cannot be cancelled.
- `PATCH /api/v1/events/:id/registration`:
  `{ "registration": { "reminder_minutes": 60 } }`. Supported values: 0, 15, 30,
  60, 1440. Users cannot set attendance through this endpoint.
- `GET /api/v1/events/:id/calendar`: authenticated `.ics` download for a registered
  user, including the event's UTC times, private meeting link if present, and the
  saved display reminder. Import the file into a calendar app; no email or push
  delivery is implied. Text is escaped and UTF-8 lines folded for calendar import.
- `POST /api/v1/events/suggestions`: saves a private suggestion with title,
  description, and category. The user's suggestions appear in My Registrations.
- `GET /api/v1/events/:id/attendees`: organizer/admin-only attendee roster.
- `PATCH /api/v1/events/:id/attendees/:registration_id`:
  `{ "registration": { "attended": true } }`; organizer/admin-only, after the
  event starts. Attendance is visible in My Registrations and unlocks the Event
  Participant achievement. Event/challenge registrations appear in My Activities.

The page supports create/suggest forms, search, category/date filters, month
navigation, registration/cancellation, hosted-event attendance management, and
calendar downloads. All UI dates and datetime inputs use Kampala (UTC+3).

Test with `bin/rails test test/controllers/api/v1/events_controller_test.rb`, using
the isolated test database as described above.

### Notifications

The Notifications page at `/notifications` follows the supplied dashboard design.
The former global notification API is now authenticated and scoped to its owner.
Run `bin/rails db:migrate` before using it. Legacy unassigned rows remain hidden;
they are never assigned to an arbitrary user or exposed in private feeds.

- `GET /api/v1/me/notifications`: private workspace with name/avatar, notification
  records, category/unread totals, preferences, and pagination metadata. Query
  parameters: `category` (`all`, `mentorship`, `learning`, `events`, `system`),
  `q`, `unread=true`, and `page`. Pages contain 30 records.
- `GET /api/v1/notifications`: authenticated compatibility list, newest first,
  limited to 100 own records.
- `GET /api/v1/notifications/unread-count`: own unread count for application bells.
- `POST /api/v1/notifications`: creates a personal notification from title/message;
  supplied recipient, URL, category, and read-state fields are not accepted.
- `PATCH /api/v1/notifications/:id`: `{ "notification": { "read": true } }`.
- `PATCH /api/v1/notifications/read-all`: marks only the user's alerts as read.
- `GET /api/v1/me/notification_preferences`: five Boolean preferences.
- `PATCH /api/v1/me/notification_preferences`:
  `{ "preferences": { "mentorship": false, "learning": true, "events": true,
  "goals": true, "platform": true } }`. Partial updates are supported.

Booking status changes notify their participants. Course completion certificates,
goal progress, event registration, and organizer-confirmed attendance generate
private alerts. Preferences control new matching alerts and preserve the inbox.
Goal/achievement alerts use the Learning tab but have their own preference.

While the app is open, feed/unread refreshes discover upcoming confirmed mentorship
sessions within 24 hours, registered events within their saved reminder window,
and recently earned badges (last 30 days). Unique user/source keys prevent repeat
notifications. Reminders are checked on refresh, not delivered as scheduled email,
push, or browser notifications. Event calendar-file reminders remain available.
Incoming chat messages now create private mentorship alerts, subject to the
recipient’s mentorship preference. Opening a conversation marks its displayed
messages and associated alerts as read.

The UI provides category tabs, quick filters, search, pagination, individual
read/unread toggles, Mark All as Read, notification destination links, and saved
preferences. The shared workspace and existing app headers show real unread
counts. A mentor retains mentor navigation when opening this page.

Test with `bin/rails test test/controllers/api/v1/notifications_controller_test.rb`.
The authentication assertion for the legacy notifications endpoint is also
updated in `misc_controller_test.rb`.


### Messages

The `/messages` and `/messages/:id` pages retain the supplied inbox and chat design.
Run `bin/rails db:migrate` to create conversations, memberships, messages, and the
last-active timestamp. Existing browser-only mock chats are not imported.

All endpoints require authentication; conversation and attachment access is scoped
to members. Contact results expose names, roles, avatars, and recent activity only.

- `GET /api/v1/conversations`: own inbox; optional `q` searches names, group titles,
  and message contents. `page` paginates 30 conversations.
- `GET /api/v1/conversations/unread-count`: own unread incoming message count.
- `GET /api/v1/conversations/contacts?q=Grace`: search active people by name.
  Without a query, suggests existing conversation and booking contacts.
- `POST /api/v1/conversations`: `{ "kind": "direct", "participant_ids": [42] }`.
  Direct conversations are reused for the same pair. Groups require `kind: "group"`,
  a `title`, and 2–29 other participants; the authenticated creator is included.
- `GET /api/v1/conversations/:id`: conversation details and members.
- `GET /api/v1/conversations/:id/messages`: latest 50 messages in chronological
  order; `before_id` retrieves older messages. Includes read receipts.
- `POST /api/v1/conversations/:id/messages`: `message[content]` (up to 5,000
  characters), `message[client_nonce]` for retry deduplication, and optional
  multipart `message[attachment]`. Accepts one PDF, text file, JPEG, PNG, or WebP
  up to 10 MB. Text or an attachment is required.
- `PATCH /api/v1/conversations/:id/read`: `{ "last_message_id": 123 }`. The cursor
  only advances and the message must belong to this conversation.
- `GET /api/v1/conversations/:id/messages/:message_id/attachment`: private file
  download; messages never expose public signed attachment URLs.

The page supports inbox search, role/group filters, direct and group creation,
emoji, file downloads/uploads, history pagination, unread counts, and mobile
inbox/thread navigation. Open chats refresh every five seconds; unread badges
refresh every ten seconds. Active-recently status reflects messaging API activity
within 90 seconds. Calls are not implemented; audio/video controls are disabled.
Drafts remain in memory per conversation while the page is mounted.

Test with `bin/rails test test/controllers/api/v1/conversations_controller_test.rb`
against the isolated test database described above.

### Settings

The `/settings` page follows the supplied three-column design and supports mobile
navigation. Run `bin/rails db:migrate` before using the page. Account roles remain
read-only. School and class / level are required for mentee profile updates.

All settings endpoints require an active authenticated account and use `no-store`
responses. No endpoint accepts a target user ID.

- `GET /api/v1/me/settings`: own profile, account preferences, and the existing
  notification preferences.
- `PATCH /api/v1/me/settings/profile`: nested `profile` with `full_name`, `email`,
  `phone_number`, `school`, `grade`, and `bio`. Updates are atomic. Changing email
  also requires `current_password`, resets email verification, revokes previous
  sessions, and returns replacement tokens under `session`.
- `POST /api/v1/me/settings/avatar`: multipart `avatar`, JPEG/PNG/WebP up to 5 MB.
  The server checks both declared MIME type and file bytes. The photo is shared
  with profile, dashboard, and message avatars.
- `PATCH /api/v1/me/settings/password`: nested `password_change` with
  `current_password`, `new_password`, and `password_confirmation`. New passwords
  must be 8–72 bytes. Success rotates the current session and invalidates old
  access and refresh tokens using `auth_version`. Tokens are bound to the immutable
  user ID, so changing or reusing an email cannot transfer session access. Legacy
  sessions without a user ID must sign in again after this update.
- `PATCH /api/v1/me/settings/preferences`: partial nested `preferences` containing
  `appearance` (`light`, `dark`, `system`), Boolean `show_online_status` and
  `allow_contact_requests`, `learning_format` (`mixed`, `reading`, `video`,
  `practical`), `weekly_learning_minutes` (30–600), `session_preference` (`online`,
  `in_person`, `either`), and `mentorship_focus` (up to 200 characters).
- `GET /api/v1/me/settings/export`: private JSON download of the account's profile,
  preferences, learning records, goals, events, bookings, reviews, resources, and
  authored message text. Password hashes, tokens, other people's private records,
  and attachment file contents are excluded.
- `POST /api/v1/me/settings/deactivate`: nested `account` with `current_password`
  and `confirmation: "DEACTIVATE"`. Retains records, deactivates login, invalidates
  access, and revokes refresh tokens. Reactivation requires support.

Notification controls reuse `/me/notification_preferences`. Privacy controls hide
recent messaging activity and prevent new contacts from finding or starting chats
with the user; existing conversation members remain able to communicate. They do
not hide public profile pages. Learning and mentorship preferences are saved for
personal planning; they do not filter courses or automatically change bookings.
Appearance applies to the Settings workspace. English and Africa/Kampala are the
current interface language and regional time zone. Two-factor authentication is
not implemented; its control is disabled.

Run `bin/rails test test/controllers/api/v1/settings_controller_test.rb` using the
isolated test database described above.

### System Settings (Admin and Super Admin)

`/admin/system-settings` (alias `/system-settings`) matches the supplied admin
layout. Both `admin` and `super_admin` can read and change settings; other roles
are rejected by the API and the UI. The migration adds the `super_admin` role but
does not promote or create any administrator accounts. The existing admin
Dashboard and account menu link to System Settings. Personal settings remain
separate at `/settings`.

Run `bin/rails db:migrate`. Settings use a single database record and an integer
`lock_version`; every modifying request must include the last loaded revision.
Stale edits return 409 with a reload action instead of overwriting another admin.
Validation is atomic. The audit records the administrator, timestamp, revision,
and changed fields. The page provides section search, reset-to-default previews,
responsive tabs, branding uploads/removal, runtime service status, and saved
configuration backups.

Authenticated admin endpoints:

- `GET /api/v1/admin/system_settings`: saved settings, defaults, revision, custom
  asset URLs, last editor/time, and safe runtime status (no credentials).
- `PATCH /api/v1/admin/system_settings`: `{ "lock_version": 0, "settings": { ... } }`.
  Partial updates are supported. Unknown fields and invalid types are rejected.
- `POST /api/v1/admin/system_settings/assets/:kind`: multipart `file` and
  `lock_version`, with `kind` of `logo` or `favicon`. Logos support PNG, JPEG and
  WebP; favicons support PNG and ICO, up to 2 MB and within the global upload cap.
  SVG uploads are not accepted; the bundled SVG branding is trusted application
  code. Removal uses `DELETE` with `lock_version` and restores bundled branding.
- `GET /api/v1/admin/system_settings/audit?page=1`: 20 audit entries per page.
- `GET /api/v1/admin/system_settings/backups`: latest 30 saved configuration backups.
- `POST /api/v1/admin/system_settings/backups`: `lock_version` and optional `label`.
- `GET /api/v1/admin/system_settings/backups/:id`: authenticated JSON download.
- `POST /api/v1/admin/system_settings/restore`: `document`, `lock_version`, and
  `confirmation: "RESTORE"`. Validates schema version 1, SHA-256 checksum, allowed
  fields, and current settings rules. Saves a backup of the previous configuration
  before restoring, within the same transaction. This is a configuration restore,
  not a database restore: member data, images and credentials are excluded.
- `POST /api/v1/admin/system_settings/test-email`: sends only to the authenticated
  administrator's account email. No arbitrary recipient is accepted.

Public endpoints:

- `GET /api/v1/platform/config`: safe branding, support information, locale defaults,
  platform mode, registration policies and public feature flags. Custom logos
  update public/shared workspace headers; favicons update the browser tab.
- `GET /api/v1/platform/events`: up to three upcoming public event summaries when
  the public-events switch is enabled; excludes meeting links and attendee data.
  Public event summaries are disabled by default and appear on the home page when
  enabled by an administrator.

Saved settings govern actual behavior:

- Registration can be closed; a missing registration role defaults to Mentor or
  Mentee. Public requests can never select privileged roles.
- Email verification, when enabled, sends a verification link at signup and blocks
  unverified members from login. Administrators retain access. The login page
  supports credential-verified resend via `POST /api/v1/auth/resend-verification`.
- Maintenance blocks non-admin API traffic and shows a public maintenance screen;
  admin login/configuration and the health check remain available for recovery.
  Staging displays a banner; it does not change Rails' deployment environment.
- Mentorship, enrollment and event switches pause new bookings, course enrollments
  and event registrations respectively, while retaining existing records.
- The notification switch controls new in-app alerts. Existing alerts stay readable;
  user notification preferences continue to apply. Verification email is separate.
- Password length applies to registration and password changes (maximum 72 bytes).
  Access/refresh lifetimes apply to newly issued tokens, not existing token expiry.
- The global upload cap is enforced on incoming uploaded files; individual feature
  caps can be lower. Storage migration and provider credentials remain deployment
  concerns; the runtime panel reports the active provider.
- Meeting host allowlists apply to new/updated event meeting links, including valid
  subdomains and excluding lookalike suffixes. An empty list allows HTTP/HTTPS links.
- Locale defaults format public event dates and admin timestamps. Currency defaults
  are saved and previewed without converting existing service prices. English
  regional variants do not imply translation of course content.

Email delivery requires deployment variables `SMTP_ADDRESS`, `SMTP_PORT` (587 by
default), optional `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_DOMAIN`,
`SMTP_AUTHENTICATION` (`plain` by default), and `MAIL_FROM`. Set `API_PUBLIC_URL` to
the externally reachable API origin for verification links. TLS upgrade is enabled.
The UI cannot enable verification without configured delivery and never returns
SMTP secrets. Tests use Action Mailer's test transport and send no external mail.

Test using the isolated database described above:
`bin/rails test test/controllers/api/v1/system_settings_controller_test.rb`.

### Users & Roles

The reference dashboard is available at `/admin/users` (alias `/admin/users-roles`).
The older `/admin?tab=users` entry redirects here; Mentors and Mentees navigation
opens the corresponding server-side role filter. System Settings and Users & Roles
share the admin header/sidebar. All management endpoints require an active Admin
or Super Admin account and return non-cacheable responses.

Run `bin/rails db:migrate`. Existing primary roles are preserved. Additional roles
use `user_role_assignments`; the primary role chooses the default workspace while
additional Mentor/Mentee roles enable their respective API and UI features.
Administrative permission grants apply only when an account also holds Admin or
Super Admin. A custom role alone cannot grant administrator access.

- `GET /api/v1/admin/user_access`: current capabilities and the permission catalog.
- `GET /api/v1/admin/users`: paginated list, global summary totals, mutually
  exclusive chart distribution, and role choices. Parameters: `q` (name, email,
  numeric/NH-prefixed ID, or affiliation), `role`/`role_id`, `status`
  (`all`, `active`, `inactive`), `sort` (`name`, `email`, `joined`, `last_active`,
  `id`), `direction` (`asc`, `desc`), `page`, and `per_page` (10/25/50/100).
- `GET /api/v1/admin/users/:id`: account details and the latest 20 administration
  audit entries. Excludes passwords, password hashes, tokens and private chats.
- `POST /api/v1/admin/users`: nested `user` with `full_name`, `email`, `phone_number`,
  `affiliation`, `role_ids`, `primary_role_id`, initial `password`, and Boolean
  `is_active`/`is_verified`. A primary role must belong to the assigned roles.
- `PATCH /api/v1/admin/users/:id`: the editable account fields under `user`, with
  the displayed `lock_version`. Program/Organisation is a managed affiliation
  label, not a fabricated program enrollment. Existing records are retained when
  roles change. Phone edits stay synchronized with an existing legacy profile.
- `PATCH /api/v1/admin/users/:id/status`: `{ "lock_version": 0,
  "account": { "is_active": false } }`. Deactivation blocks login and revokes
  sessions; activation requires a fresh login. No account hard-delete is exposed.
- `POST /api/v1/admin/users/bulk-status`: `user_ids` (up to 100), a `versions` object
  mapping each ID to its displayed revision, and `account.is_active`. A stale or
  protected target rolls back the entire batch.
- `POST /api/v1/admin/users/:id/revoke-sessions`: displayed `lock_version`.
- `POST /api/v1/admin/users/:id/password`: `lock_version` plus `password_change`
  containing `password` and `password_confirmation`. Enforces the configured
  password policy and invalidates access and refresh sessions.
- `GET /api/v1/admin/users/export`: CSV for the current filters, or `user_ids` for
  the selected records. At most 10,000 filtered records (or 100 selected records).
  Passwords are excluded, and formula-like spreadsheet cells are escaped.
- `GET /api/v1/admin/users/import-template`: CSV template with headers
  `full_name,email,phone_number,role,affiliation,password`.
- `POST /api/v1/admin/users/import-preview`: multipart `file`, UTF-8 CSV up to
  256 KB and 100 rows. Checks database and within-file duplicate emails/phones,
  required fields, known roles, and initial password policy. Preview creates
  nothing and never returns passwords.
- `POST /api/v1/admin/users/import`: resubmit the same file after reviewing a valid
  preview. Revalidates every row and commits the whole batch or none. Admin and
  Super Admin assignments are never accepted through import; grant these through
  the reviewed account form as a Super Admin instead. Credentials must be shared
  privately by the administrator; import does not send unsolicited invitations.
- `GET /api/v1/admin/roles`: role descriptions, effective permissions, actual member
  counts, revisions and allowed operations, plus the live permission catalog.
- `POST /api/v1/admin/roles`: nested `role` with lowercase `name`, `description`,
  and a `permissions` array from the catalog.
- `PATCH /api/v1/admin/roles/:id`: nested `role` with edited fields and `lock_version`.
- `DELETE /api/v1/admin/roles/:id`: displayed `lock_version`; only unassigned custom
  roles can be deleted. Built-in names and the Super Admin role are protected.

Default Admin permissions cover user viewing, creation, editing, status, password
reset, session revocation, import/export, role viewing/management, and system
settings. Only Super Admin can assign administrator roles, modify other staff
accounts, or change Admin permissions. An administrator cannot grant a permission
they do not hold. Members' canonical roles do not grant management permissions.
The same protections apply to legacy `/roles` mutations, closing that alternate
route around the new UI.

Self-edits use My Account Settings. Users & Roles blocks self-demotion,
self-deactivation and self-password resets. Personal deactivation also protects
the last active administrator/Super Admin. Staff changes serialize under a common
transaction lock. Revision conflicts return 409 instead of silently overwriting
another administrator's changes. Role/permission, email, password and status
changes revoke affected sessions; authorization always reads current database
roles. Administration audits record actor/action/changed fields, never passwords.

Summary role counts include additional roles and may overlap. The donut assigns
each user once (Super Admin, then other staff, Mentor, Mentee, Other), so chart
percentages sum to 100%. Last Active reflects authenticated API activity; accounts
with no recorded activity display Never rather than a fabricated date.

Validate with the isolated database described above:
`bin/rails test test/controllers/api/v1/admin_users_controller_test.rb test/controllers/api/v1/admin_roles_controller_test.rb`.

## Admin dashboard and operations

`/admin` consumes `GET /api/v1/admin/dashboard`. Both Admin and Super Admin can
use it; member accounts receive 403. `dashboard.read` grants reports, operational
records and private administrative downloads. `dashboard.manage` additionally
grants program, session, event and resource changes. Default Admin includes both;
explicit permission overrides must grant these keys through Users & Roles.

Reports accept `period=7|30|90` (default 30), or `period=custom&from=YYYY-MM-DD&to=YYYY-MM-DD`
for 1–366 inclusive days ending no later than today, in the configured timezone.
User totals are cumulative through the end date. Mentor/Mentee totals use current
role assignments, including additional roles; the distribution counts each
account once. Growth is daily cumulative users. Session totals exclude cancelled
bookings and use scheduled dates; event totals use start dates. Deltas compare
equal preceding periods for sessions/events, and the pre-period cumulative user
baseline for account totals. A zero baseline is reported as null, never infinity.
Insights compare new-user cohorts, current completion of goals created by the
end date, and reviews of completed sessions submitted in the period. Empty goal
and review populations produce null. Top programs use current active memberships;
upcoming events are relative to now, independently of the selected report range.

Additional routes under `/api/v1/admin/dashboard`:

- `GET /search?q=...`: bounded cross-record search. User results additionally need
  `users.read`; private account fields and conversation content are excluded.
- `GET /health`: database probe, local storage access and application response.
  Queue/email configuration is distinguished from verified service health;
  historical availability, remote storage utilization and worker backlog are not monitored.
  Uptime refers only to the current API process.
- `GET /records?type=programs|sessions|events|resources|activities&page=1`: 20 per
  page, with `q`, `status`, and `window=all|period|upcoming` filters. Activities use
  the report range and persisted record/audit summaries.
- `GET /:type/:id`: operational details; `GET /options?q=...` supplies bounded
  active people, offerings, programs and categories for management forms.
- `POST /programs`, `PATCH /programs/:id`: nested `program`; updates require
  `lock_version`. Programs can be active, draft or archived. Optional initial
  `participant_ids` enroll active mentors/mentees.
- `GET|POST /programs/:id/members`, `DELETE /programs/:id/members/:user_id`:
  paginated membership, additions using `user_ids` (1–100), and logical removal.
  Session history and inactive membership records are retained.
- `POST /sessions`: nested `session` with mentee and explicit future timestamp,
  using an existing active `service_id`, or a private one-off title, mentor,
  category, duration (15–240 minutes) and price. One-off offerings stay outside
  the public catalogue. Optional program scheduling requires active membership.
  Both participants are locked while checking overlaps, including multiple-role
  accounts; the global matching pause applies. A confirmed booking is created;
  **no payment is processed**, and payment status remains pending.
- `PATCH /sessions/:id`: nested `session` status and exact `updated_at` revision.
  Pending sessions can be confirmed/cancelled; confirmed sessions can be cancelled
  or completed after their scheduled end. Participant preferences govern alerts.
- `POST /events`, `PATCH /events/:id`: nested `event`; updates require exact
  `updated_at`. Creation requires a future start. Capacity cannot drop below
  current registrations; meeting-provider policy applies.
- `POST /resources`, `PATCH /resources/:id`: nested JSON or multipart `resource`,
  with title, description, URL and/or file, optional program, and boolean published.
  Updates require `lock_version`. Supported files: PDF, text, JPEG, PNG, WebP;
  maximum 10 MB and subject to the global upload cap. URLs require HTTP(S),
  without embedded credentials. `GET /resources/:id/file` requires dashboard access.

Published resources appear in the authenticated mentee Learning Area. Member
file downloads use `GET /api/v1/learning/resources/:id/file`; draft IDs return 404.
File DTOs contain authenticated application routes rather than public blob URLs.
Mutations record administration audits and return 409 on stale revisions.
Legacy `/api/v1/dashboard` and `/api/v1/statistics` now require administrator access.
Run `bin/rails db:migrate` when updating an existing installation.

Regression coverage: `bin/rails test test/controllers/api/v1/admin_dashboard_controller_test.rb`.

## Mentee management

Admin and Super Admin use `/admin/mentees`. The API is scoped to accounts with a
current Mentee role, including additional roles. Every route requires `users.read`;
creation, editing, status, CSV import and CSV export additionally require their
respective `users.create`, `users.update`, `users.status`, `users.import`, and
`users.export` permissions. Import commit also requires `users.create`. Existing
staff/self-edit protections apply to mentees who hold additional staff roles.

- `GET /api/v1/admin/mentees`: paginated mentees and global engagement reports.
  Filters: `q` (name, email, NH-ID, mentor, program or session title), `tab` and
  `status` (`all|active|inactive|graduated|suspended`), `program_id`, `mentor_id`.
  `sort=name|joined|status|id`, `direction=asc|desc`, `per_page=5|10|25|50` (default 5).
- `GET /admin/mentees/options?q=...&active_only=true`: searchable choices, maximum
  100 per type. Active-only choices are used when assigning mentors/programs.
- `GET /admin/mentees/:id`: account and assignment details, active program
  memberships, latest 20 goals/sessions and latest 20 administrative history entries.
- `POST /admin/mentees`: nested `mentee` fields `full_name`, `email`, `phone_number`,
  initial `password`, optional `school`, `grade`, `location`, `mentor_id`, `program_id`,
  and `status`. The Mentee role is forced and email verification cannot be forged.
- `PATCH /admin/mentees/:id`: editable fields above, plus displayed `lock_version`
  and `profile_version`. Passwords and role changes use Users & Roles instead.
  Additional roles are preserved. Stale account or profile writes return 409.
- `PATCH /admin/mentees/:id/status`: nested `mentee` with `status`, `lock_version`,
  `profile_version`. Inactive and Suspended block login and revoke sign-in sessions;
  Graduated retains account access. Learning, booking and membership history remain.
- `POST /admin/mentees/bulk-status`: `user_ids` (1–100), `status`, and `versions`
  keyed by user ID, containing account/profile revisions. The batch is atomic.
- `GET /admin/mentees/export`: filtered CSV, optional selected `user_ids`, maximum
  10,000 mentees. Formula-like cells are escaped and credentials are excluded.
- `GET /admin/mentees/import-template`; `POST /admin/mentees/import-preview` and
  `POST /admin/mentees/import`: multipart CSV up to 256 KB/100 rows, using the
  existing six-column user template. Only canonical Mentee roles are accepted;
  preview returns row errors without passwords and creates nothing. Commit
  revalidates the whole file before an atomic import. No invitation email is sent.

Routes after the first bullet share the `/api/v1` prefix. All responses are
non-cacheable. Mutations record administration audits without credentials.

A primary program is an active program membership. Changing it logically removes
that previous primary membership and adds the new one; unrelated memberships and
all session history remain. Unassigned mentees display their earliest active
program membership, if any. Explicit mentor assignment takes precedence over the
latest non-cancelled booking mentor. Assigned connections appear on both mentee
and mentor dashboards before a first session. Self-service profile endpoints
cannot change management status or assignments.

Progress is average saved goal progress (zero with no goals); session counts are
completed bookings. Engagement rate is authenticated activity in the last 30 days
as a fraction of all current mentees. Satisfaction averages their submitted session
reviews (null when none). Goal completion counts mentees with at least one
completed goal; program completion counts Graduated mentees. Program distribution
counts each mentee once. Growth covers six calendar months using current role
assignments; historical role/status snapshots are not invented. Table filters and
export share a scope; summary reports cover all mentees. Month boundaries use the
configured platform timezone. Total growth compares with the pre-month cumulative
count; new-user growth compares calendar-month cohorts. Zero baselines are null.

Apply `bin/rails db:migrate` before using these routes. Verify with
`bin/rails test test/controllers/api/v1/admin_mentees_controller_test.rb`.

## Mentee details

`/admin/mentees/:id` is the dedicated Admin/Super Admin details page. All new API
routes require `users.read`, current Mentee role membership (including additional
roles), and return `Cache-Control: private, no-store`.

- `GET /api/v1/admin/mentees/:id/details`: profile, primary program end date,
  average goal progress, course progress, earned badges, recent sessions/goals,
  satisfaction from submitted completed-session reviews, and 30-day activity.
- `GET /api/v1/admin/mentees/:id/sections/:section`: `sessions`, `progress`,
  `goals`, `achievements`, `reviews`, or `activity`; supports `q` and `page` with
  20 records per page. Goals include the first 20 milestones and a total count.
  Activity is paginated in SQL and returns event metadata, never chat bodies.
- `POST /api/v1/admin/mentees/:id/avatar`: multipart `avatar` and displayed
  `lock_version`; requires `users.update` and existing protected-account rules.
  JPEG, PNG and WebP bytes are checked, maximum 5 MB and within the global cap.
  Changes are audited and stale revisions return 409.
- `GET /api/v1/admin/mentees/:id/certificates/:certificate_id`: requires
  `users.export`. Only this mentee's completed-course certificates can be downloaded.
  Detail reads do not create certificates or send course notifications.

The existing mentee PATCH endpoint also accepts `education` (up to 200 characters),
`bio` (up to 1,000), and `interests` (up to 12 strings of 1–50 characters). Interests
are trimmed and deduplicated. Both account and profile revision checks still apply.

Sessions Attended counts completed bookings. Completed/In Progress count enrolled
courses. Overall progress remains the average saved goal progress, consistent with
the management page. Expected completion uses the displayed program's end date;
missing dates and review populations are displayed as unavailable.

Engagement is tracked learner-active days divided by eligible calendar days since
joining, capped at 30, using the platform timezone. Source events are learning
lesson completions, goal progress, session/registration records, resource access,
mentor-message metadata, and the latest recorded authenticated presence. Admin
changes do not count. It is not a reconstruction of unrecorded browsing history.
The 30-day session activity counter uses recorded completion updates.

Mentor interaction totals include learner/mentor message activity in conversations
that the learner belongs to. They do not grant an administrator access to those
conversations or their contents. The Message action opens the acting staff member's
own direct conversation through existing contact permissions and sends no message
automatically. Status, sign-in session revocation, session management and CSV export
reuse their existing permission checks and audit behavior.

Resource usage is recorded going forward: authenticated published-file downloads
create `PlatformResourceAccess` events, and member Learning Area link clicks call
`POST /api/v1/learning/resources/:id/access`. The server chooses the actor, rejects
draft resources, and never trusts a submitted user ID. Distinct resources feed the
lifetime Resources Used counter; events feed the 30-day Resources Accessed counter.
Existing unrecorded visits are not backfilled. Time on Platform is explicitly
untracked rather than inferred from bookings or idle tabs.

Apply the new migration with `bin/rails db:migrate`. Integration coverage:
`bin/rails test test/controllers/api/v1/admin_mentee_details_controller_test.rb`.

## Programs workspace

Admin and Super Admin access `/admin/programs`. All `/api/v1/admin/programs` routes
require `dashboard.read`; mutations, enrollment changes and CSV import additionally
require `dashboard.manage`. Read-only dashboard administrators can inspect records,
filter and export program metadata, but cannot create or modify anything. Viewing
personal mentee pages still requires `users.read`.

- `GET /admin/programs`: paginated programs plus global analytics. Filters: `q`
  (program name/description, assigned mentor, member name or resource title), `tab`
  and `status` (`all|active|draft|archived|ongoing`), `category_id` (`none` for
  uncategorized), `mentor_id`, and `rated_only=true`. Sort by `name|created|enrolled|rating|start`,
  `direction=asc|desc`, `per_page=5|10|25|50`, and `page`. Enrollment trend accepts
  `months=3|6|12` (default 6). Analytics cover all programs; filters scope table/export.
- `GET /admin/programs/options`: searchable `q`, `kind=mentors|mentees|categories`,
  `active_only=true` for assignment choices, maximum 100 matches per type.
- `GET /admin/programs/:id`: real program information, mentors, aggregate progress,
  enrollment and rating figures, plus linked session/resource totals.
- `POST /admin/programs`, `PATCH /admin/programs/:id`: nested `program` with title,
  description, category_id, icon (`graduation|chart|code|sprout|users|briefcase`),
  status (`active|draft|archived`), strict ISO starts_on/ends_on dates, and optional
  mentor_ids (up to 100). Updates require the displayed lock_version. New mentor
  assignments require active Mentor accounts; existing unavailable assignments may
  be retained or removed. Mentor assignments are separate from learner enrollments,
  so removing a dual-role mentor does not withdraw that person's learner enrollment.
- `POST /admin/programs/bulk-status`: program_ids (1–100), status and versions keyed
  by program ID. A stale record rolls back the entire batch. Archiving preserves
  all memberships, progress, assignments, resources and session history.
- `GET /admin/programs/:id/members`: paginated learner enrollments, q by name,
  `status=active|withdrawn|all`. Names, public avatars and program progress are
  returned without account emails or credentials.
- `POST /admin/programs/:id/members`: user_ids, up to 100 active Mentee accounts.
  Rejoining reactivates the same membership and preserves progress/history.
- `PATCH /admin/programs/:id/members/:membership_id`: nested enrollment with integer
  progress (0–100) and lock_version. Completion records a timestamp; reducing
  progress clears the current completion marker. Member IDs are scoped to the program.
- `DELETE /admin/programs/:id/members/:membership_id`: displayed lock_version;
  withdraws logically and retains saved progress and history. Archived programs
  cannot accept new enrollments or progress updates, but permit withdrawal.
- `GET /admin/programs/:id/records/sessions|resources`: paginated linked operational
  records. The UI opens existing authenticated operations dialogs for details,
  session actions and resource downloads under their existing permissions.
- `GET /admin/programs/export`: CSV of filtered or selected program_ids, up to
  10,000 rows; spreadsheet formulas are escaped. No account credentials are exported.
- `GET /admin/programs/import-template`, `POST /admin/programs/import-preview`,
  `POST /admin/programs/import`: UTF-8 CSV up to 256 KB/100 rows. Headers are
  title,description,category,status,starts_on,ends_on,icon. Category names must match
  existing active categories or be empty. Empty status defaults to draft. Preview
  writes nothing. Commit revalidates every row and creates the entire batch or none;
  duplicate titles (existing or within the file) are rejected. Mentors and mentees
  can be assigned after import; import creates no accounts or enrollments.

Routes above use the `/api/v1` prefix. Responses are private/non-cacheable.
Writes are authorized again inside the shared administration lock and audited.
Revisions protect both program and enrollment edits; stale changes return 409.
Existing dashboard program operations remain compatible and synchronize mentor
assignments when mentors are added/removed through the older member controls.

Progress is the average recorded progress of current learner enrollments in this
specific program. It is independent of overall mentee learning goals, and existing
memberships start at zero until program progress is recorded. Learners are accounts
with a current Mentee role, including additional roles. Row Enrolled counts current
memberships. Total Enrollments and the trend count lifetime distinct learner/program
membership records, including withdrawals; rejoining does not inflate the count.
Active Participants counts unique active enrolled accounts with authenticated activity
in the last 30 days. Historical account/role snapshots are not invented. Ratings use
reviews of completed bookings explicitly linked to a program. Ranked programs are
active programs with such reviews, sorted by rating then enrollment count. Empty
review populations and zero comparison baselines return null. Monthly deltas compare
with pre-month cumulative counts; trend growth compares with the cumulative count
before its displayed calendar months. Dates use the configured platform timezone.
Ongoing is a display state for active programs within their start/end schedule.

Apply `bin/rails db:migrate`. The migration preserves existing mentor memberships
as explicit mentor assignments. Test with
`bin/rails test test/controllers/api/v1/admin_programs_controller_test.rb`.

### Program details

`GET /api/v1/admin/programs/:id` includes capacity (null means unlimited),
objectives, target audience, delivery mode (`online`, `in_person`, `hybrid`),
registration/evaluation dates, and current learner enrollment progress counts.
Completed = 100%, in progress = 1–99%, not started = 0%; withdrawn enrollments
and mentor-only memberships are excluded. The center percentage is mean saved
progress. These are enrollment milestones, not automatically issued badges or
certificates. Unconfigured schedule dates are returned as null.

`PATCH /api/v1/admin/programs/:id` accepts these details alongside existing
program fields and requires the displayed `lock_version`. Capacity must be a
positive integer up to 1,000,000, or null, and cannot be reduced below current
learner enrollment. Enrollment checks capacity atomically under the shared
administration write lock. Objectives allow up to 20 strings of 300 characters;
audience allows 500 characters. Registration must finish by the program start;
evaluation must begin on or after its end. Partial dates are permitted.

Program read access requires Admin/Super Admin and `dashboard.read`; changes
require `dashboard.manage`. Mentee emails in the scoped enrollment list are
returned only with `users.read` (otherwise null). Session scheduling also honors
platform matching availability. Existing session and resource endpoints remain
the authority for linked record management and file downloads.

## Sessions management

Admin and Super Admin use `/api/v1/admin/sessions` with `dashboard.read` for
list/detail/options/participant/export reads and `dashboard.manage` for writes.
All responses are private/no-store. Scheduling/import also respects the platform
matching switch. Existing bookings remain the session records; their primary
learner is backfilled into `booking_participants` with unrecorded attendance.
New bookings automatically register their primary learner.

- `GET /admin/sessions`: paged 5/10/25/50; search title, description, mentor,
  program or attendee; filter program/mentor/format/status/tab; sort date/title/
  created, ascending or descending. Also returns global metrics, distribution,
  recorded attendance by scheduled month (3/6/12 months), and top programs.
- `GET /admin/sessions/:id`, `GET /:id/participants`: session details, roster,
  and paged attendance records (20/page). Account emails are not exposed.
- `POST /admin/sessions`, `PATCH /:id`: schedule or edit future pending/confirmed
  sessions. Fields: title, description, mentor_id, mentee_ids (1–100), category_id,
  optional program_id, scheduled_at (future ISO timestamp with offset), duration
  (15–240 whole minutes), format (`online`, `live`, `on_site`), location and
  optional HTTP(S) meeting_url. On-site sessions require location. Edits require
  the displayed microsecond `updated_at`. Program sessions require active learner
  enrollments and must fit within configured program dates. All participant
  overlaps are checked under user locks, including ordinary bookings.
- `PATCH /:id/status`: `{session: {status, updated_at}}`; pending → confirmed or
  cancelled, confirmed → completed (after end) or cancelled. Terminal records
  preserve history. Cancellation keeps attendance but removes it from reports.
- `PATCH /:id/participants/:participant_id`: `{attendance: {attended, updated_at}}`;
  attended is true/false/null, for confirmed/completed sessions after start.
  Null means unrecorded, not absent. Every update advances the session revision.
- `GET /admin/sessions/export`: filtered/selected safe CSV, at most 10,000 records.
  `GET /import-template`, `POST /import-preview`, `POST /import`: UTF-8 CSV up to
  256 KB and 100 rows. Preview is read-only; commit revalidates eligibility,
  program dates/enrollments and overlaps (including within-file overlaps), then
  imports atomically. Attendee IDs use semicolons; imports create no accounts.

Admin-created sessions use private, free offerings. Paid bookings retain their
mentor, primary learner, roster, offering and price when edited; rescheduling
never processes payments. Free mentor reassignment clones the private offering
rather than changing an offering used by other bookings. Session title,
description and category overrides preserve shared offering history. Group
attendees can view their bookings and receive in-app updates; they cannot cancel
an entire group session. Attendance never infers participation from completion.

Total Attendees counts registrations across non-cancelled sessions, not unique
people; the trend counts only recorded present attendance. Upcoming includes
future pending/confirmed bookings; Ongoing is confirmed within its time window.
Ended confirmed sessions appear as Awaiting Completion until staff complete them.
Status charts include Scheduled (pending) separately. Growth compares new session
records in the last 30 days with the preceding 30 days. Top programs counts all
saved sessions, including cancelled ones. Reports use the platform timezone.

### Session Details

`GET /api/v1/admin/sessions/:id/details` returns session metadata, attendance,
feedback highlights/rating, material and recording counts, and learner engagement
counts. `PATCH` updates title/description overrides, objectives (20 × 300 chars),
tags (12 × 40 chars), registration/feedback timestamp windows, and an optional
JPEG/PNG/WebP cover up to 2 MB. Updates require the displayed `updated_at`.
Completed sessions allow overview edits while keeping operational schedule,
attendance, offering and billing history. Schedule timestamps require offsets;
registration closes by session start and feedback opens after session end.

The details endpoints require Admin/Super Admin plus `dashboard.read`; writes
require `dashboard.manage`. Scoped routes under `/admin/sessions/:id`:

- `GET sections/:section` — paged/searchable materials, recordings, engagement,
  feedback, internal notes or audit (20/page).
- `POST assets` — multipart `{asset: {kind,title,description,url,file}}`; exactly
  one URL or file. Materials accept PDF/text/JPEG/PNG/WebP up to 10 MB; recordings
  accept MP4/WebM/MP3/Ogg up to 100 MB, also respecting the platform upload cap.
  At most 100 active assets per session. Links must be HTTP(S) without credentials.
- `DELETE assets/:asset_id` — revision-protected logical removal; access history
  remains. `POST assets/:asset_id/access` opens an external link; `GET .../file`
  downloads the authenticated file. Staff previews do not count as engagement.
- `GET materials-archive` — tar.gz containing material files and a link manifest;
  the combined file size is capped at 50 MB. `GET attendees-export` returns safe
  CSV with names, registration times and nullable attendance, without email.
- `POST notes`, `PATCH/DELETE notes/:note_id` — internal staff notes, with item
  `lock_version` for changes/removal. Actions appear in the session audit log.
- `POST follow-up` — `{follow_up: {message,request_key}}`; sends in-app alerts to
  active registered learners respecting preferences. A UUID-style retry key
  prevents duplicate delivery. The result reports delivered/skipped counts.
- `POST duplicate` — `{session: ...}` using the scheduling payload. Creates a
  future validated session and copies objectives/tags/cover/materials. Attendance,
  recording history, feedback, notes and schedule windows start fresh.

Authenticated session participants use `GET /bookings/:id/session-content`,
`POST /bookings/:id/session-assets/:asset_id/access`, `GET .../file`, and
`PUT /bookings/:id/session-feedback`. Content is scoped to their booking; feedback
is limited to registered learners after completion and within configured windows.
Feedback is unique per learner/session; a new response supersedes that learner’s
legacy booking review in session aggregates, avoiding double counting. Notes and
staff audit history are never included in participant content responses.

Recording opens and material accesses count explicit learner access requests,
including repeated accesses; they do not claim video watch time. Staff/mentor
previews are excluded. Removed assets keep historical counts. Legacy completed
bookings are not assigned fictional attendance, downloads or recording views.

## Learning Resources management

Admin/Super Admin use `/api/v1/admin/resources` with `dashboard.read` for reads,
previews and exports; writes require `dashboard.manage`. Responses are private
and no-store. Existing `PlatformResource` records remain the source for the
learner Learning Area. Types are `course`, `video`, `document`, `link`, `other`;
existing attached resources are classified by stored MIME type during migration.
Course resources are course links or course-material files; this does not replace
the existing lesson/completion catalogue.

- `GET /admin/resources`: server search by title, description, tags, program or
  uploader; type tabs/type/status/program filters; title/date/views sorting;
  5/10/25/50 per page. Includes global counts, additions growth, type distribution,
  recorded engagement by month (3/6/12), and the top accessed published resources.
- `GET /:id`: metadata plus file-download/link-open counts and distinct users.
  `GET /:id/file` authenticates staff downloads without recording a view.
- `POST /admin/resources`, `PATCH /:id`: JSON or multipart `{resource: {...}}`;
  title, description, resource_type, status, platform_program_id, tags, URL,
  file and remove_file. Updates require displayed `lock_version`. New resources
  default to draft. Newly assigned programs must be active; existing inactive
  program associations may be retained. `clear_tags=true` clears multipart tags.
- `POST /bulk-status`: resource_ids (1–100), versions keyed by resource ID,
  status `published`/`draft`/`archived`. Changes are atomic under the shared staff
  write lock; archiving retains content and access history and hides learner access.
- `GET /export`: selected or filtered CSV, at most 10,000 rows, with spreadsheet
  formula escaping. `GET /import-template`, `POST /import-preview`, `POST /import`:
  UTF-8 link metadata CSV, at most 256 KB / 100 rows. Preview is read-only and
  commit revalidates atomically. Tags use semicolons; program IDs come from the
  Programs export. Files are uploaded separately after import.

Resources require a safe HTTP(S) URL without credentials and/or a supported file.
Links use URLs only. Documents support PDF/text/Word/Excel/PowerPoint, videos MP4/
WebM, and Others images/audio/document formats. Course materials accept all
supported formats. Document/Other files are capped at 10 MB; videos/course files
at 100 MB, also respecting the platform upload limit. Actual MIME content is
checked; files are served through authenticated endpoints as attachments.

Views are recorded link opens plus file downloads, including repeat accesses.
New staff previews do not create engagement records. Analytics retain archived
resource access history; top resources exclude drafts and archived entries.
Counts include all saved resources. Growth compares additions in the last 30 days
with the preceding 30 days; engagement periods use the platform timezone. No
historical views, file sizes or uploaders are fabricated for legacy data.

### Learning Resource Details

`GET /admin/resources/:id/details` returns resource metadata, configured duration,
first known publish timestamp, captions/thumbnail availability, program shares,
learner performance, engagement trend, and recent recorded activity. `PATCH`
accepts `{details: {...}}` (JSON or multipart) with displayed `lock_version`:
language code, target_audience, module_name, position, required, awards,
duration_seconds (0–604800), visibility, optional thumbnail/captions and remove
flags. Thumbnail images are JPEG/PNG/WebP up to 2 MB; captions must have a WebVTT
header and be at most 1 MB. Chapter offsets must fit a configured duration.
Legacy publish dates are not inferred from creation timestamps.

Scoped routes under `/admin/resources/:id` require Admin/Super Admin plus
`dashboard.read`; writes require `dashboard.manage`:

- `GET sections/:section` — searchable, paged contents/feedback/engagement/
  versions/audit, 20/page.
- `POST contents`, `PATCH/DELETE contents/:content_id` — ordered text/link
  sections or video chapters, at most 100 sections. Section changes require
  section `lock_version`; titles max 200, bodies 10,000, safe URLs 2,048 chars.
- `POST shares`, `DELETE shares/:share_id` — add/remove additional program
  assignments under the parent resource revision; new shares require active
  programs. Program-only visibility must retain a primary assignment or share.
- `POST versions/:version_id/restore` — restore a captured snapshot as a draft,
  using current parent revision. Metadata, content order, shares and retained
  file/thumbnail/caption blobs are restored. Current validation and active-share
  rules apply. Learner progress, feedback and access history remain intact.
- `POST duplicate` — existing resource payload; creates a draft copy of content,
  metadata, files and shares with fresh learner activity and feedback.
- `DELETE /:id` — revision-protected soft deletion. Learner links and admin library
  listings stop returning the resource; stored versions/activity remain retained.
- `GET captions` — authenticated staff caption download.

Resource saves capture version snapshots (including legacy dashboard edits and
bulk publishing changes). Parent/file writes retain blob attachments for older
versions, allowing restoration after replacements. Unknown historical authors
are labeled System; no fictional version or publishing history is inserted.

Visibility options: `platform` (signed-in users), `program` (active members or
assigned mentors of primary/shared programs), `staff` (administrators with
`dashboard.read`). Draft, archived and deleted resources are never available
through learner endpoints. The Learning Area uses the same access policy.

Learners use `GET /learning/resources/:id/details`, `PUT .../progress`,
`PUT .../feedback`, `POST .../contents/:content_id/access`, and `GET .../captions`.
The existing file/link endpoints enforce this policy too. A real file/link open
records an access and starts progress at 1%; later saved percentages are
self-reported, revision protected, and constrained to 0–100. Feedback requires a
started resource, integer rating 1–5 and comment up to 1,000 characters. Staff
previews cannot submit learner activity or inflate metrics.

Performance uses recorded access events and saved learner progress. The progress
population combines eligible active mentees with users already recorded against
the resource; historical activity is retained when membership changes. Engagement
means started/completed learners over that population; completion rate uses the
same denominator. Awards/Credits is descriptive metadata and does not itself
issue a certificate. Video duration is configured metadata, not inferred watch time.
