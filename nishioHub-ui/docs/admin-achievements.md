# Admin Achievements

The sidebar opens `/admin/achievements`. The Tailwind page preserves the supplied dashboard layout: four metric cards, six tabs, type distribution, issuance trend, top badges, recent awards, summary tiles and top programs. Tables and tabs scroll inside their containers on small screens.

## Working flows

- **Overview** shows real filtered metrics, recent records and clickable chart legends/top badges/programs.
- **Achievements List** supports search, type/program/status/learner/badge filters, sorting, pagination, selected exports, award details and revocation. View opens the dedicated [Achievement Details](admin-achievement-details.md) page.
- **Badges** combines the eight existing automatic badge definitions with custom badges. Custom definitions support create/edit/archive/restore and issuance. Catalog search does not incorrectly reset award counts when a definition is renamed.
- **Certificates** includes completed-course certificates and custom administrator-issued certificates. Both download as private SVG documents.
- **Awarded Users** aggregates awards by learner and opens their filtered award list.
- **Analytics / Reports** exports filtered totals, monthly counts and top programs as CSV.

Create Achievement saves a reusable definition and optionally issues it to selected learners in the same transaction. Saving a definition without recipients does not increase award totals. Award Existing issues a saved custom definition. Recipients must be active mentees, including accounts with an additional mentee role; batches support 1–100 recipients. An optional active program and award date can be selected. Blank dates use the current time; explicit dates use midnight in the platform timezone. Future and invalid dates are rejected.

Each issued award snapshots its title, description, kind, icon and color. Editing its definition affects future awards. Archiving a definition prevents further issuance while retaining awards. Revocation requires a reason and displayed revision, retains the administrative record, removes the award from current learner achievements and blocks its certificate download. A revoked award can be reissued as a new record. Duplicate active awards for the same definition/learner are rejected atomically, including batches.

Custom badges/certificates/recognition appear in the existing My Achievements API and UI. Issuance and revocation deliver in-app notifications according to the learner's preferences. Automatic badge criteria are shared with the existing learner catalog; admin reads do not manufacture awards or certificates. Automatic accomplishments are corrected through their source workflows.

## Metrics

Total Achievements counts individual active recognition records, not distinct learners. Course completion and its certificate are separate records, consistent with My Achievements. Sources include completed catalog courses, valid course certificates, the eight existing badge rules, completed mentorship sessions, completed program memberships with recorded completion timestamps, and custom awards.

Learners Awarded counts distinct recipients. Badges counts available definitions (eight built-in plus active custom skill-badge definitions); it is a catalog total. Certificates Issued counts valid active certificate records. Type segments are disjoint and sum to the active total. Records without an explicit program remain Independent; program attribution is never inferred from a learner's unrelated memberships.

Monthly counts use recorded issuance dates in the platform timezone. Trend comparisons use equal adjacent calendar windows and remain absent when the previous window is empty. Card comparisons measure growth of the current active award set since a 30-day cutoff, rather than reconstructing historical revocations. Revoked rows remain searchable; active metrics exclude them. No screenshot totals or fabricated percentages are used.

## API and access

Apply migration `20261111020000_create_admin_achievements.rb` with `bin/rails db:migrate`. It adds reusable achievement definitions and snapshot awards with revisions, stable identifiers, issuer references, revocation metadata and a unique active definition/learner index.

Admin and Super Admin require `dashboard.read`; all mutations additionally require `dashboard.manage`. Read-only buttons are disabled, and the API independently rechecks permissions inside serialized transactions. Downloads are authenticated and private/no-store. Certificate text is XML-escaped; CSV exports protect spreadsheet formula cells.

Endpoints under `/api/v1/admin/achievements`:

- `GET /` dashboard/list; `POST /` create definition with optional `user_ids`, `program_id`, `awarded_on`.
- `GET /definitions`; `PATCH /definitions/:definition_id`; `POST /definitions/:definition_id/award`.
- `GET /:id`; `POST /:id/revoke`; `GET /:id/certificate`.
- `GET /export`; `GET /report`.

List parameters: `q`, `tab` (`overview`, `all`, `badges`, `certificates`, `users`, `analytics`), `kind`, `status` (`active`, `revoked`, `all`), `program_id`, `user_id`, `definition_key`, `sort`, `direction`, `page`, `per_page` (5/10/20/50), `months` (3/6/12), `include_archived`. Definitions additionally support `custom_only`. Selected award exports accept up to 100 `award_ids`; exports are capped at 10,000 filtered awards.

## Validation

Integration coverage includes Admin/Super Admin/member/read-only access, all automatic badge rules, primary/additional mentee roles, real completion records, platform timezone boundaries, catalog revisions/renaming/archive, batch rollback, duplicate prevention, date/recipient/program validation, notifications, learner integration, revocation/reissue, private escaped certificates, filtering, pagination, aggregates and CSV safety.

Browser checks cover create-and-award, detail/revoke, custom badge edit/award/archive/restore, certificate issue/download, all six tabs, filtering/pagination, selected CSV/report downloads, regular/read-only admin access, member redirects, learner badge/certificate visibility, and desktop/mobile overflow. No JavaScript exceptions were observed. Temporary QA records used the isolated test database, not development data.

Final validation on November 11, 2026: **392 Rails tests, 2,815 assertions, zero failures/errors/skips**. `npm run typecheck` and `npm run build` passed. The build retains the existing Browserslist freshness and bundle-size warnings. Temporary QA servers were stopped and fixtures cleared from the isolated test database.
