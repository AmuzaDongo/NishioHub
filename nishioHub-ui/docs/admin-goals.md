# Goals & Progress

`/admin/goals` matches the supplied dashboard layout in Tailwind: five summary cards, section tabs, progress gauge, historical trend, category donut and paginated goals table. The admin sidebar links to it. Admin and Super Admin accounts require `dashboard.read`; writes additionally require `dashboard.manage`, enforced by the API. Read-only controls are disabled.

## Shared records

Mentee and mentor goals stay in their existing tables and remain connected to My Goals and mentor My Mentorship. Program goals belong directly to a program. Admin identifiers are type-prefixed (`mentee-12`, `mentor-12`, `program-12`) to avoid collisions across tables.

Create/edit supports scope, category, program, active assignee, description, target date, progress and tracking status. Goal scope is fixed after creation. New assignees must have the chosen mentee/mentor role; changed program assignments must select an active program. Existing assignments may be retained for historical/inactive accounts or programs. Assigning a goal does not enroll the account in a program or automatically infer progress from a goal's title.

Current goals and recorded progress are shared with personal pages. Mentor completion checkboxes still synchronize 0/100% with the richer progress fields. Administrator assignments and progress updates use existing in-app notification preferences.

## Status and reporting rules

Statuses are mutually exclusive: 100% is Completed; an overdue unfinished goal is At Risk in the platform timezone; remaining goals use the saved On Track/In Progress/At Risk flag. These four counts sum to Total Goals. The gauge is the mean of current goal percentages, independently of status counts.

All metrics follow the current filters. The Goal Types dropdown filters learning, career, project, personal and other categories. Program Goals lists program-scoped goals; Mentee Progress and Mentor Progress aggregate personal goals by assignee. View Goals opens that account's scoped goals. Searches match goal title/description, assignee and program. Pagination, sorting, status/category/program filters, reset and chart legend filters are functional.

Monthly trend values use the latest recorded percentage at each month end, limited to goals that existed then. The current month ends at the current time. Missing history appears as a gap, not fabricated zero progress. The report includes the number of goals with recorded history for each point. This is the historical progress of the currently filtered goal cohort; reassignment and metadata history are not reconstructed.

Existing mentor goals receive a current baseline during migration; their earlier percentages are not backdated. Total-goal growth compares creation counts in the last 30 days with the preceding 30 days. Trend change compares the latest recorded monthly mean with the recorded baseline preceding the selected window. Changes without a valid baseline are omitted; unsupported historical status growth is omitted.

## Goal actions

View opens the dedicated `/admin/goals/:id` page with metadata, tasks, progress, written updates, private attachments and activity history. See [Goal Details](admin-goal-details.md). Edit and Update Progress use displayed revisions to reject stale changes. Explicit progress notes are retained even when the percentage is unchanged; ordinary metadata-only saves do not invent progress events.

Milestones support add/edit/complete/remove with their own revisions and goal-scoped access. Milestone completion does not change manually recorded goal progress. Completion sets the goal to 100% and records the update. Archive hides the goal from current admin and personal goal pages while retaining stored history/milestones and previously earned achievement history. Archiving/completion/removal require confirmation.

Export downloads selected visible goals (up to 100) or all goals matching the filters (maximum 10,000). Reports downloads current metrics, category counts and historical trend data. CSV text cells are escaped against spreadsheet formulas. Administrative writes and exports are audited.

## API and migration

Apply `20261110060000_expand_admin_goals.rb` using `bin/rails db:migrate`. The migration preserves existing goals, expands mentor progress, introduces program goals, and extends milestones/progress events with exactly one goal foreign key. Added revision counters protect admin saves and milestones.

Routes under `/api/v1/admin/goals`: index/create, `/export`, `/report`, `/:id` show/update/archive, `/:id/milestones` create, and `/:id/milestones/:milestone_id` edit/remove. GET supports `q`, `tab`, `type` (scope), `category`, `status`, `program_id`, `assignee_id`, `sort`, `direction`, `page`, `per_page` and `months` (3/6/12). Admin requests submit goal/milestone snapshots with their displayed `lock_version`.

Existing personal endpoints retain their contracts and ownership checks. Archived goals are excluded from current dashboards and aggregates; personal data export retains stored history.

## Verification

Integration coverage includes roles/read-only access, all three goal scopes, shared owner updates, completion synchronization, revisions, dates/role/program/progress validation, local-date overdue handling, filters, pagination, person aggregates, historical snapshots, milestone scoping, archival, notes and CSV safety. Browser checks cover creation/editing, milestones, progress/history, completion, archival, reporting, all section tabs, shared personal views and desktop/mobile overflow.

Final checks: production build passed and desktop/mobile browser workflows passed without runtime exceptions. The full regression run completed with 364 tests and 2,359 assertions; its two failures were the existing required-phone/no-role user test and the existing email-verification redirect expectation. After tightening the comparison baseline to immediately precede the displayed window, the final admin-goal run passed all 10 tests and 105 assertions. TypeScript reports only the nine existing `StudentProfile`/`EditProfile` errors. Temporary browser fixtures were cleared from the isolated test database and the temporary API, UI and browser processes were stopped.

Subsequent validation: the previously noted Rails failures and profile TypeScript errors were resolved by the [profile fixes across roles](profile-role-fixes.md). The full suite and TypeScript checks now pass.
