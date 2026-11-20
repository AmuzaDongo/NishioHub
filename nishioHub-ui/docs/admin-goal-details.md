# Goal Details

The goals list opens `/admin/goals/:id`, with composite IDs such as `mentee-12`, `mentor-12` and `program-12`. Legacy `?goal=` links redirect to this page. The page uses Tailwind and the existing admin workspace, preserving the reference's hero, progress ring, tab strip, information cards, tasks, updates and attachments. It adapts to mobile without widening the document.

## Data and actions

All scopes use the existing goal, milestone and progress-event records shared with personal goal pages. Tasks are milestones; checking a task does not overwrite manually recorded goal progress. Priority supports Low, Medium and High. The existing goal editor and progress dialog are reused.

Overview, Tasks, Progress, Updates, Attachments and Activity Log load persisted data. Task/update/attachment/activity lists support search and pagination; the header searches across tasks, updates and attachments on Overview and Progress. Written notes support editing/removal with revisions; progress events remain immutable. The activity log includes goal-scoped admin audits and progress events.

The progress chart displays the latest 100 recorded events. Its comparison is the percentage-point difference from the last recorded snapshot at least 30 days ago; unavailable baselines remain absent. Completion dates are recorded when progress reaches 100%, cleared on reopening, and backfilled only from an identifiable historical completion event. Unknown historical dates/durations display “Not recorded.” Days Taken uses platform calendar dates. Task completion rate is independent of goal progress.

Duplicate creates a goal of the same scope at 0% with incomplete copied tasks, active attachment copies and the cover. Old written updates/history are excluded. A new creation event is recorded. Task deadlines shift by the goal-deadline difference when both deadlines exist; otherwise they are cleared. Assignments must select active accounts/programs. Archiving hides the goal and its files from current endpoints while retaining stored history.

## Access and files

Admin and Super Admin access requires `dashboard.read`. Mutations additionally require `dashboard.manage`. Read-only controls are disabled; the API independently enforces permissions, ownership scope, goal archival and optimistic revisions. Metadata and files return private/no-store responses.

Files are served through authenticated endpoints without exposing storage URLs. Attachments accept a file or an HTTP(S) link without credentials. Supported files: PDF, DOCX, XLSX, UTF-8 text, JPEG, PNG and WebP, capped at the smaller of the platform upload limit and 10 MB. Covers accept JPEG/PNG/WebP up to 2 MB. Up to 100 active attachments are allowed. Removal hides the attachment while preserving its stored record. Duplicates have independent attachment records sharing the underlying blob. PDF/text/image previews use authenticated blobs; Office documents download for viewing. Report CSV exports saved metrics and protects spreadsheet formula cells.

## API and migration

Run `bin/rails db:migrate` to apply `20261111010000_create_goal_details.rb`. It adds priority/completion dates and goal-scoped updates/attachments with exactly-one-goal constraints.

New endpoints under `/api/v1/admin/goals/:id`:

- `GET /details`, `GET /sections/:section` (`tasks`, `updates`, `attachments`, `activity`; `q` and `page`).
- `POST /updates`, `PATCH/DELETE /updates/:update_id`.
- `POST /attachments`, `DELETE /attachments/:attachment_id`, authenticated `GET /attachments/:attachment_id/file`.
- `GET/PATCH /cover`, `POST /duplicate`, `GET /report`.

Existing goal and milestone endpoints remain compatible. Writes submit displayed revision counters. The file/cover endpoints accept multipart forms.

## Validation

Integration tests cover all goal scopes, Admin/Super Admin/member/read-only permissions, task metrics/search/pagination, note revisions/scoping, file/link validation, private downloads, cover upload/reset, duplication/reset/date shifts, completion/reopening/legacy dates, local-date durations, historical baselines, archive protection, scoped audit history and spreadsheet-safe reporting.

Browser verification covers desktop/mobile overflow, shared editor, task completion, note create/edit/search/remove, file preview/download/upload/remove, cover upload/reset, link create/remove, report download, progress/activity/search tabs, duplicate/archive, list navigation and read-only controls. No JavaScript exceptions were observed.

Final validation on November 11, 2026: full Rails suite **381 tests, 2,715 assertions, zero failures/errors/skips**; `npm run typecheck` and `npm run build` passed. Build output retains the existing Browserslist freshness and bundle-size warnings. Temporary browser servers were stopped and test fixtures cleared from the isolated database.
