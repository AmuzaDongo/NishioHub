# Admin Reports & Analytics

Route: `/admin/reports`. Admin and Super Admin accounts require `dashboard.read`.
The page uses the shared admin shell and Tailwind utilities to preserve the supplied
reference: report navigation, five metrics, growth/role/completion charts, achievement
trend, goal-category progress, insights, and top-program table.

## Data and reporting periods

The default is year to date in the platform timezone, ending today. Presets are 7,
30, and 90 days. Custom ranges accept 1–366 days, with no future end date.
Search and program filters apply on the server. Every report section supports CSV
export; detailed datasets support pagination. Export is limited to 10,000 rows;
spreadsheet formula prefixes are escaped.

- User, program, and resource totals count retained records created before the end
  of the period. Their comparison baseline is the retained count before its start.
- User growth is cumulative by month, clipped to the selected range. Role totals
  use current roles, counting each account once with staff precedence.
- Event counts use start dates in the selected period. Registration and confirmed
  attendance are current outcomes for those events.
- Achievements count active recognition records issued in the period, including
  automatic and custom sources. Revoked records are excluded.
- Program completion and average progress use current progress of enrollments
  whose membership was created during the selected period. These are cohort
  outcomes, not historical enrollment-progress snapshots.
- Learning reports count recorded resource accesses and completions in the period.
- Goal category progress uses the latest recorded progress event at the selected
  cutoff, retaining goals archived after that cutoff. Missing history displays —.
- A missing previous baseline displays “No baseline”, never an invented percentage.

## Saved reports and scheduling

Custom reports save a private name, dataset, whitelisted column list, and filters.
Saved-report previews and exports use those saved filters independently of the
page controls. Revisions protect against stale edits. Each owner may save up to
50 custom reports and 50 schedules.

`dashboard.manage` is required to create, edit, delete, or run schedules and custom
reports. Detailed user reports additionally require `users.read`, including when
previewing. User CSV exports, scheduled generation, and artifact downloads also require
`users.export`.
Schedules and artifacts are scoped to the authenticated owner. Other administrators
cannot read them. Mutations, exports, and downloads are audited.

Schedules support daily, weekly, and monthly delivery, at a local hour/minute in
the platform timezone captured when created. Monthly days are restricted to 1–28.
Relative periods are evaluated at execution time; fixed custom dates remain fixed.
Generated CSV files appear in the owner's report history. An in-app notification
links to the report history; there is no email delivery dependency. Notification
preferences can suppress the alert while the artifact remains available.

Run Now generates a report without moving the next recurring delivery. Pause stops
recurring execution. Resume recalculates the next occurrence. Failed reports show
an error and can be retried. Revoked administrator/management permissions pause a
due schedule. Ownership and dataset permissions are checked again for downloads.

## Deployment

Apply migration `20261111050000_create_reporting_workspace.rb` with `bin/rails db:migrate`.
Keep Active Storage configured with persistent, private storage for report artifacts.

Schedules enqueue `ReportScheduleJob` through Active Job. The default async adapter
only retains jobs while its process lives. For reliable delivery after restarts,
run `bin/rails reports:run_due` every minute through the deployment scheduler, or
use a persistent Active Job adapter with a periodic invocation of that task as a
recovery sweep. Due runs are serialized per schedule and keyed by their scheduled
timestamp. A delayed stale job does not duplicate a rescheduled run. After an
outage, one catch-up run is generated and the next future occurrence is selected.
This implementation does not install OS cron entries or configure an external worker.

## Verification

Reporting integration tests cover administrator and read-only access, all seven
sections, timezone cutoffs, disjoint roles, current enrollment progress, filters,
invalid dates/pagination, saved-report ownership/revisions/columns, CSV escaping,
private downloads, due-run idempotence, permission revocation, time validation,
resource access counts, confirmed event attendance, historical goal cutoffs, and
separate user-export permissions.
