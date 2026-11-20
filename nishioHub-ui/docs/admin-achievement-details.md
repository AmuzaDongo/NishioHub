# Achievement Details

The achievements list opens `/admin/achievements/:id` using the existing composite award identifiers. The Tailwind page follows the supplied design: learner/program/status cards, recognition icon, six tabs, information and progress panels, certificate preview, metrics and activity timeline.

Overview, Criteria & Progress, Certificate, Related Goals, Activity Log and Notes load saved data. Header search queries the current section or searches all sections from Overview/Certificate. Notes, goals and activity are paginated.

Custom award records support explicit audited corrections to title, description, icon, color, program, cohort, criteria text and final score. Corrections use optimistic revisions and retain the original recipient, type, definition, issuer and issuance date. New awards snapshot definition criteria; older missing snapshots remain unknown. Automatic achievements follow their source records and cannot be manually overwritten here. Revoked awards retain readable history and notes but cannot be edited or download certificates.

Custom criteria record a category, completed units, target units and completion timestamp. They support scoped add/edit/remove actions and produce real progress metrics. Automatic course criteria use actual catalog lessons and completion records; program/session/badge criteria follow their recorded source accomplishments. Missing assessments, projects, scores and cohorts show “Not recorded” or a dash. Criteria never automatically issue or revoke an award.

Related goals are explicitly linked to the learner's existing goals. Another learner's goals cannot be selected; reassigned goals are hidden from old relationships. Linking/unlinking does not change goal progress. Staff notes support revisions, search, editing and soft removal. The activity timeline combines scoped administrative audits, recorded lesson/evidence completions and issuance records.

Course-completion records can preview their existing course certificate. A missing certificate can be issued idempotently for a completed course. Custom certificate awards use their stable issued record. Preview/SVG downloads are authenticated. PDF download renders the authenticated SVG into a standalone one-page PDF in the browser, preserving Unicode names and artwork without server browser/font dependencies. PDF output is image-based. Share copies a restricted admin page link; it does not publish learner information or bypass access checks. More actions include record CSV export, SVG download and custom award revocation.

Admin/Super Admin access requires `dashboard.read`; writes require `dashboard.manage`. Read-only controls are disabled, and the API independently enforces award scope, goal ownership, revisions and current permissions. Responses are private/no-store. CSV cells are spreadsheet-safe and certificate XML is escaped.

Apply migration `20261111030000_create_achievement_details.rb`. New endpoints under `/api/v1/admin/achievements/:id`: `GET/PATCH /details`, `GET /sections/:section`, criteria and notes CRUD, eligible-goal lookup, goal link/unlink, `GET/POST /details/certificate` and `GET /record`. The existing award API remains compatible.

Integration coverage includes all source kinds, roles/read-only access, honest missing metrics, explicit corrections, criteria and note scope/revisions, goal ownership/reassignment, certificate privacy/idempotency, activity scope and CSV safety. Browser checks cover the overview, corrections, criteria/note CRUD, private preview/PDF and responsive layout. The downloaded PDF's cross-reference offsets and single-page structure were checked, and Poppler rendered it successfully.

Final validation on November 11, 2026: the combined Rails suite passed **408 tests and 2,970 assertions** with zero failures/errors/skips. TypeScript, targeted ESLint and production build passed. The certificate PDF was rendered successfully by Poppler. Temporary QA servers and token fixtures were removed after verification.
