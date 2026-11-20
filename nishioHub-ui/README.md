# Shadcn-UI Template Usage Instructions

## technology stack

This project is built with:

- Vite
- TypeScript
- React
- shadcn-ui
- Tailwind CSS

All shadcn/ui components have been downloaded under `@/components/ui`.

## File Structure

- `index.html` - HTML entry point
- `vite.config.ts` - Vite configuration file
- `tailwind.config.js` - Tailwind CSS configuration file
- `package.json` - NPM dependencies and scripts
- `src/app.tsx` - Root component of the project
- `src/main.tsx` - Project entry point
- `src/index.css` - Existing CSS configuration

## Components

- All shadcn/ui components are pre-downloaded and available at `@/components/ui`

## Styling

- Add global styles to `src/index.css` or create new CSS files as needed
- Use Tailwind classes for styling components

## Development

- Import components from `@/components/ui` in your React components
- Customize the UI by modifying the Tailwind configuration

## Note

The `@/` path alias points to the `src/` directory

# Commands

**Install Dependencies**

```shell
pnpm i
```

**Start Preview**

```shell
pnpm run dev
```

**To build**

```shell
pnpm run build
```

## Administration dashboard

Admin and Super Admin accounts reach the API-backed dashboard at `/admin`.
The page preserves the supplied purple dashboard layout with responsive metric
cards, growth and role charts, system health, activity, programs, upcoming events
and quick actions. Date presets and custom reporting ranges fetch real records.
Search opens authorized account or operational details.

Programs, sessions, events and resources in the sidebar open paginated management
panels. Quick actions create programs, schedule sessions, create events, publish
links/files, or open the existing Add User form. Program membership can be edited;
records detect concurrent edits. One-off sessions stay private and do not process
payments. Published files appear in the mentee Learning Area and download through
an authenticated API request. Health labels distinguish configured services from
actual probes. Unsupported administration modules remain visibly disabled.

Existing category management is available at `/admin/categories` (also linked
from Learning Resources). Users & Roles and System Settings retain their own pages.
Set `VITE_API_BASE_URL` to your API's `/api/v1` URL, migrate the API database, then
run `npm run dev` or `npm run build`.

## Mentee management

`/admin/mentees` is available to Admin and Super Admin and linked from the shared
admin sidebar. The reference layout is implemented with Tailwind utility classes;
no new page stylesheet is needed. It includes live status tabs, searchable mentor
and program filters, sorting, pagination, row/visible-page selection, detail and
edit dialogs, account status actions, CSV preview/import/export, and engagement
charts. Filters apply to table/export; metric definitions are displayed in the UI.
Mentor assignment and primary program enrollment are persisted, and stale profile
or account edits require reloading instead of silently overwriting newer data.

## Mentee details

The management table's View actions open `/admin/mentees/:id`. The dedicated page
uses Tailwind utilities and the existing shared admin shell to preserve the supplied
profile summary, progress ring, satisfaction card, section tabs and overview panels.
Tabs support direct URLs such as `?tab=goals`; section search and pagination load
real records. Empty and unavailable metrics have explicit states.

Edit Mentee updates profile, education, interests, bio and assignments. The camera
control uploads an authorized profile photo. Message opens the acting staff member's
conversation without sending content. More includes status changes, CSV export and
sign-in session revocation. Sessions can be managed through the existing operations
dialog; achievements include authorized certificate downloads. Usage definitions
and untracked time are explained in the interface.

## Programs

`/admin/programs` is the Tailwind-based Admin/Super Admin Programs workspace, linked
from the shared sidebar. It follows the supplied layout with KPI cards, status tabs,
searchable category/mentor filters, sortable program table, selection, pagination,
category donut, enrollment trend and reviewed-program ranking. Records without
ratings display an unavailable value instead of a fabricated score.

Program dialogs create/edit metadata and mentor assignments; detail views manage
learner enrollments and progress, preserve withdrawn history and expose linked
sessions/resources. Existing operations dialogs handle session/resource actions.
CSV export follows filters/selection. Import has a template, row preview and atomic
commit. A read-only dashboard administrator sees disabled management controls.
Legacy program records remain supported after applying the API migration.

### Program details

`/admin/programs/:id` is the Tailwind Program Details workspace. Program names,
view actions, and rankings in the Programs list open this route. It preserves
the admin shell and reference layout: summary, progress ring, overview/schedule,
mentor cards and mentee table. Overview, Sessions, Mentors, Mentees, Resources,
Achievements and Settings are addressable through `?tab=` links.

Edit Program manages dates, capacity, objectives, audience, mode and mentors.
Mentees supports search, active/withdrawn history, enrollment, progress updates
and withdrawal. The Achievements tab displays saved program completion
milestones. Sessions/resources use the existing operational forms with this
program preselected. Read-only permissions disable writes; private mentee
emails/profile links require `users.read`. Empty, loading and error states use
API data, without demonstration counts or invented progress.

### Sessions management

`/admin/sessions` uses Tailwind and the shared admin shell to match the Sessions
reference: four metrics, status tabs, filters, paged table, status donut,
attendance trend, and program ranking. The sidebar Sessions item opens this page.

Admin/Super Admin can schedule and edit future sessions with searchable mentor,
program, category and attendee selectors; date/time inputs use the configured
platform timezone. Session details support meeting links and paged nullable
attendance. Status actions confirm, complete after end, or cancel while retaining
records. Read-only accounts can inspect/export but cannot schedule or change
attendance. CSV import provides template download, validation preview and atomic
commit; exports honor filters or current-page selection.

The displayed counters and charts use persisted API data. Total Attendees means
learner registrations; attendance charts use explicit Present records. Existing
ended confirmed sessions are labeled Awaiting Completion. Empty/error/loading
states and horizontal table scrolling support desktop and mobile layouts.

### Session Details

`/admin/sessions/:id` preserves the Session Details reference layout in Tailwind:
thumbnail/title/program/mentor summary, attendance ring, eight tabs, overview,
quick actions, schedule, engagement counters and feedback highlights. Sessions
list view actions navigate here. Tabs are addressable with `?tab=`.

Editing uses the shared SessionEditor for future sessions and the overview editor
for completed sessions. Duplicate opens a prefilled editor for a new future date
and copies materials/overview while starting with fresh participation history.
Materials/recordings support file or link entry, authenticated download/preview,
and confirmed removal. Notes are revision-protected staff records. Quick actions
provide material archives, attendee CSV, explicit in-app follow-up and feedback.
Readonly permissions disable writes while retaining read/export access.

Learner booking cards include Materials & Feedback. These read booking-embedded
service/mentor snapshots, so private offerings remain accessible even when absent
from public catalogues. Fresh navigation waits for authentication initialization.
Learner content access and feedback drive the staff engagement reports; no
illustrative statistics are inserted into the application.

### Learning Resources management

`/admin/resources` uses Tailwind and the shared admin shell to match the reference:
five metrics, six type tabs, program/type/status/search controls, a paged table,
type distribution, engagement chart and top resources. The sidebar links here.

Resource forms support program assignment, tags, safe content links, file uploads,
publishing, drafts and archive status. Detail dialogs expose actual metadata,
authenticated downloads, media previews and access counts. Bulk status changes
require confirmation and displayed revisions. CSV imports provide a template,
validation preview and atomic commit; exports honor filters or selection.

Published resources appear in the existing learner Learning Area. Draft/archive
transitions hide them while retaining content/history. Staff previews do not add
engagement. Readonly staff can inspect/export but cannot mutate resources. The
page includes loading/error/empty states and mobile scrolling for the table/tabs.

### Learning Resource Details

`/admin/resources/:id` matches the supplied Resource Details layout with Tailwind:
preview, metadata/performance summary, seven tabs, quick actions, related
information, engagement trend, learner progress donut and recent activity.
Resource list view actions open this route. Tabs use `?tab=`.

The shared ResourceEditor handles core editing and draft duplication. Additional
information includes language, module/position, audience, required flag, credits,
duration, visibility, thumbnail and WebVTT captions. Contents supports ordered
sections, external links and chapter offsets. Versions can restore metadata,
content and retained files as a draft. Program sharing, unpublish and soft delete
are API-backed and revision protected; readonly staff retain inspection access.

Copy Resource Link targets `/learning/resources/:id`. The learner page is linked
from Shared Learning Resources and provides authorized content, captions, file/
link access, explicit progress controls and feedback. Its activity drives the
admin reports; admin previews are excluded. Access, empty, error/loading states
and responsive tab/table scrolling are supported. No example statistics or
completion certificates are fabricated.
