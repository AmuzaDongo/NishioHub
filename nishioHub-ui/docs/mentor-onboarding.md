# Mentor onboarding

Public landing: `/become-a-mentor` (also `/mentor-onboarding`). Application: `/mentor/application`. Admin review: `/admin/mentor-applications`. Conduct and safeguarding documents: `/mentor-guidelines` with policy version `2026-11-15`.

The public page follows the supplied design using Tailwind: shared header, purple photographic hero, five steps, eligibility/requirements/benefits cards and the final yellow application CTA. Watch How It Works opens the guided steps; it does not pretend a video is configured. The stated 1–3 day review time is an estimate.

Home and public navigation/footer Become a Mentor links open the onboarding page. Login and mentor registration preserve only the fixed `/mentor/application` return destination; arbitrary redirects remain disallowed. Existing public event return links continue to work.

## Workflow

Authenticated accounts of any existing role can create their own draft and save background, expertise, experience, motivation, references and policy consent. Drafts and change requests are editable. Submission requires every field, all three documents and current policy consent. Submitted applications are locked. Admins may approve, request changes with feedback, or reject with feedback. Requested changes permit editing and resubmission; rejection is final in this workflow, with a support link for questions.

Approval preserves existing roles and adds Mentor when needed, creates or verifies the mentor profile, records the reviewer and decision timestamp and sends an in-app notification. A newly created profile starts unpublished and not accepting bookings; public home/directory/profile endpoints respect publication and active-account status; the mentor completes profile and availability through the existing profile page. Verified mentors use that page directly. Application documents are never copied into the public mentor profile.

Admin review requires `users.read`; decisions additionally require `users.update`. Self-review is blocked. Only a Super Admin may change an administrator applicant. Inactive applicants cannot be approved. Application mutations and decisions use revision checks; submission and decisions use the shared administration lock. Audit records cover submission, decisions and administrator document downloads.

## Documents

Government ID, CV and qualification/experience evidence accept PDF, JPEG or PNG files, up to 5 MB each (also subject to the platform upload limit). The server checks detected MIME type. Draft uploads/replacements/removal require the latest revision and are locked after submission. Upload responses reload the application only after commit so file bytes persist and attachment touches return the current revision.

Private document endpoints stream authenticated downloads with attachment disposition, `private, no-store` and `nosniff`. Responses contain file metadata, not signed storage URLs or blob identifiers. Other users cannot select an applicant by supplying a user ID. Admins cannot read another user's unsubmitted draft. Real-commit tests verify uploaded bytes and revisions after three sequential uploads.

## API

- `GET/PATCH /api/v1/me/mentor-application`
- `POST /api/v1/me/mentor-application/submit`
- `GET/POST/DELETE /api/v1/me/mentor-application/documents/:kind`
- `GET /api/v1/admin/mentor-applications` (status/search/pagination)
- `GET /api/v1/admin/mentor-applications/:id`
- `GET /api/v1/admin/mentor-applications/:id/documents/:kind`
- `POST /api/v1/admin/mentor-applications/:id/review`

Migration: `20261114010000_create_mentor_applications.rb`, applied locally to development and the isolated test database. Apply it in other deployment environments before using these routes.

## Image assets

Built-in imagegen was used. The hero is a fictional promotional photograph, not a real verified mentor portrait. Optimized asset: `public/images/onboarding/mentor-hero.webp`.

Source: `/home/dongo/.codex/generated_images/01a1b749-277d-7543-a1b0-86c136c971dd/exec-cf4a60db-9da3-4dda-9bcd-15443a95ea7f.png`.

Hero prompt: Use case: photorealistic-natural. Asset type: mentor onboarding website hero photograph. A smiling Black Ugandan male professional mentor in his early thirties, short neat hair, closely trimmed beard and black glasses, navy blazer over light blue shirt, sitting at a desk with a silver laptop, hands loosely clasped, looking warmly toward the left. Bright modern library workspace with soft green indoor plants and books, warm natural daylight. Wide landscape 3:2 composition, subject center-right, full head visible with room above, laptop lower right, soft background left for website copy. Professional commercial educational photography, navy and violet complementary palette, realistic anatomy. No text, logos, watermark, graphics or decorative overlays. Fictional promotional character, not a real mentor.

Additional transparent illustration: `public/images/onboarding/graduation-books.webp`, generated with the built-in imagegen tool. Source: `/home/dongo/.codex/generated_images/01a1b749-277d-7543-a1b0-86c136c971dd/exec-0d26b853-0a35-4cb7-a7e8-160347d901d0.png`.

Illustration prompt: Use case: stylized-concept. Small polished 3D educational website illustration: two stacked closed books, one violet and one warm golden yellow, with a rich purple graduation cap and golden tassel resting on top. Friendly high-quality rounded 3D render, subtle soft contact shadow, three-quarter front view, centered isolated object. No text, no letters, no logo, no border, genuinely transparent background. Compact horizontal composition suitable for the lower right corner of a mentor eligibility card.

## Verification

- Full Rails suite: 455 tests, 3,718 assertions, zero failures/errors/skips. Approval/publication tests verify that a newly approved profile stays off public pages until the mentor publishes it.
- TypeScript and production build pass. Targeted ESLint has zero errors; the existing mentor-profile effect dependency warning remains.
- Browser: actual login return, mentor registration selection, saved form, three real document uploads, private document download, submission locking, admin changes request, resubmission, approval and mentor-profile access pass, with no JavaScript exceptions.
- Reference layout inspected at 1216px desktop, 1024px tablet and 390px mobile without horizontal overflow.
- QA accounts and files were confined to the isolated test environment; the temporary accounts were removed before the final regression run.

The application page now follows the dedicated Mentor Application Dashboard reference. See `mentor-application-form.md` for the expanded version 2 personal/professional fields, profile photo and review flow. Existing submitted applications retain their earlier requirements.
