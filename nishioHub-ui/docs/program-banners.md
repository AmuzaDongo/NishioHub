# Program banners

Program covers are stored with Active Storage and managed through the existing program API. No database migration is needed for the attachment.

- Add/Edit Program, Program Details → Edit Program, and the dashboard program editor accept JPEG, PNG, or WebP images up to 2 MB, subject to the platform upload cap. The image preview, replacement, removal, and undo-removal controls save with the rest of the form.
- Saving uses multipart data when uploading or removing an image. Ordinary edits continue to use JSON and preserve the saved cover. Multipart array fields retain mentor assignments and support explicit clearing.
- Saved covers appear in the admin program list, the program details header, the public Programs cards, and the public program details dialog. Programs without a cover retain their existing icon.
- Admin and Super Admin accounts require `dashboard.read` and `dashboard.manage` to change a banner. Staff with read permission can view draft and archived covers. Only active programs expose images publicly.
- `POST /api/v1/admin/programs` and `PATCH /api/v1/admin/programs/:id` accept `program[banner]` and `program[remove_banner]`, alongside existing fields. Updates require the current `lock_version`. The dashboard program endpoints use the same service and upload rules.
- Responses include `banner_url`, `banner_filename`, and the resulting revision. Public catalog records expose the cover as `image`.
- `GET /api/v1/platform/programs/:id/banner?version=…` serves active-program images publicly and other images to authorized staff. It uses `no-store` and `nosniff`, exposes no storage credentials, and returns 404 for missing or unavailable covers. The admin React component fetches protected images using the current session and cleans up object URLs.
- Banner-only changes advance the revision so the browser requests the replacement image. Query invalidation refreshes program lists, details, dashboard records, and the public catalog after a save.
- Invalid MIME types, oversized files, conflicting upload/removal requests, failed form validation, and stale revisions preserve the saved image. Audit records describe the change without retaining uploaded file objects or temporary file paths.

Validation commands: `npm run typecheck`, `npm run lint`, `npm run build`, and `ruby bin/rails test`. Coverage includes actual image bytes, replacement, removal, rollback, stale revisions, public/private visibility, permissions, multipart arrays, and dashboard quick actions.

Verified with the 487-test Rails suite and a final 26-test banner/dashboard run. A real-API browser check covered creation, local preview, persisted images on admin/public views, replacement, invalid-file handling, private draft images, undo/removal, and mobile layout. Test records were isolated to the test database and removed afterward. TypeScript, lint, and the production build also passed.
