# Admin Messages

`/admin/messages` and `/admin/messages/:id` use the existing admin workspace and Tailwind. The reference layout is preserved: inbox filters/search/pagination on the left, conversation and composer in the center, and contact information, shared files and actions on the right. On smaller screens the information panel opens in a dialog, and mobile shows either the inbox or selected conversation. Existing `/messages` links redirect Admin and Super Admin accounts to this workspace while preserving the conversation ID.

## Access and delivery

Administrator access requires `dashboard.read`. Compose, send, broadcasts, settings and conversation actions additionally require `dashboard.manage`. Read-only administrators can read their own conversations and maintain their personal read cursor. The original member write endpoints also enforce staff permissions, preventing an alternate write route.

Administrators only see conversations they belong to. Super Admin does not grant access to other users' private conversations. Messages and attachments retain membership checks and return private/no-store responses. Presence uses real account activity and honors online-visibility preferences. There are no simulated typing, delivery or online indicators.

Compose starts a direct conversation or a group with 2–29 other participants. Existing direct conversations are reused in either participant order. Contact search supports active users, mentor/mentee roles and program participation, including assigned program mentors. Contact-request privacy and blocks are rechecked when sending invitations. Groups can record an optional program and cohort.

Broadcast sends separate direct messages to 1–100 explicitly selected recipients. Recipients cannot inspect the other recipients or their conversations. Delivery is atomic, validates active recipients/contact permissions, and uses a persisted sender/request identifier to prevent duplicate retries. Reusing an identifier with changed recipients/content is rejected. Broadcasts support a title and up to 4,800 content characters; ordinary messages support 5,000 characters.

## Inbox actions and preferences

Star, archive and mute apply only to the current user's membership. Unread filters count conversations with unread incoming messages; the shared unread-message counter counts messages. Archived conversations have their own filter and can be restored.

Delete Conversation hides the current history from this user's inbox. Other participants retain their records. New incoming messages can reopen the conversation, but messages and files before the deletion cursor remain inaccessible to the deleting user through both the admin and member APIs. Deletion and sending serialize on the conversation. Read-cursor updates do not invalidate unrelated star/archive/mute revisions.

Block User applies to direct messaging and new invitations in both directions. Existing history and shared groups remain available. Unblock removes only the current user's block. Inactive direct contacts cannot receive new messages.

Message Settings persists in-app notifications, read-receipt sharing and Enter-to-send behavior. Muted conversations and disabled message notifications suppress new alerts; account-level notification preferences also apply. Disabling receipts hides the user's read cursor from message serializers while retaining their own unread state. Shift+Enter inserts a new line when Enter-to-send is enabled.

The composer supports per-conversation drafts, retry-safe nonces, emoji, uploads and earlier-message pagination. Messages poll while the document is visible. A successful send clears only the matching submitted draft so edits made during sending are retained.

## Files and calls

Shared Content loads all visible attachments with pagination. Downloads use the authenticated member endpoint and never expose storage URLs in message metadata. Supported files are PDF, DOCX, XLSX, UTF-8 text, JPEG, PNG, WebP and MP4, capped at the smaller of the platform limit and 10 MB. Declared/detected MIME types are checked; Office files require their document extension and ZIP signature. HTML/SVG uploads are rejected. Existing participant messaging remains compatible.

Phone actions use the actual contact number through a `tel:` link. Video actions link to an existing confirmed shared session whose joining window is open; otherwise the action is disabled. This page does not invent call rooms or introduce a separate calling provider.

## API and setup

Apply `20261111040000_expand_admin_messaging.rb` with `bin/rails db:migrate`. It adds membership state/revisions/deletion cursors, messaging blocks, user preferences, optional conversation program/cohort metadata and persisted broadcast requests.

Endpoints under `/api/v1/admin/messages`:

- `GET /` inbox (`page`, `tab`, `q`); `POST /` direct/group composition.
- `GET /contacts` (`q`, `page`, `role`, `program_id`).
- `GET/PATCH /preferences`; `POST /broadcast`.
- `GET /:id`; `GET/POST /:id/messages`; `PATCH /:id/read`.
- `PATCH /:id/state`; `PATCH /:id/block`; `GET /:id/content`.

Inbox pages contain eight conversations; message history loads fifty at a time; shared-content pages contain ten files. Inbox/preferences changes submit displayed revisions. Sending uses `client_nonce` for duplicate protection. Attachment downloads continue through `/api/v1/conversations/:id/messages/:message_id/attachment` with the same visibility constraints.

## Verification

Integration coverage includes roles/read-only access, membership isolation, inbox flags and revisions, read cursors, per-user deletion and revival, attachment privacy, cross-route blocking, mute/preferences/receipt behavior, private atomic broadcasts, idempotency, contact privacy, and real spreadsheet uploads. Existing conversation tests are retained.

Browser verification covers text/file sending, private downloads, star/archive/mute/block/unblock, settings, direct/group composition, broadcasts, per-user deletion, legacy admin routing, read-only controls, nonmember administrators, member redirects and desktop/mobile overflow. No application JavaScript exceptions were observed. QA used temporary test accounts in the isolated database.

Final validation on November 11, 2026: **408 Rails tests, 2,970 assertions, zero failures/errors/skips**. TypeScript, targeted ESLint and production build checks passed. Existing Browserslist freshness and bundle-size warnings remain. Temporary QA servers were stopped and test fixtures cleared from the isolated database.
