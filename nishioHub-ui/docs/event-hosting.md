# Host an Event

The public page is `/host-an-event`, linked from the Events landing page and the For Schools menu. It follows the reference's purple hero, two-column benefits and registration layout, event-type cards, and closing banner using Tailwind. The hero reuses the existing local mentorship photograph; branding follows platform settings.

The landing page is public, but the form requires a logged-in mentor, school, or organization account. Schools can use their assigned organization account; a separately assigned school role is also accepted. Guests see a login action that returns to this page after authentication. Accounts with other roles see an eligibility message. Primary and additional roles are checked in the UI and API, with no administrator exemption. Account changes reset local form data. It uses the shared `react-phone-number-input` field with Uganda as the default country, inline validation, live character counts, a future-date picker, policy acceptance, a disabled submission button, and a confirmation reference. Connection errors retain entered details. Identical retries reuse the submission key; changed form data starts a new request.

`POST /api/v1/platform/event-hosting-requests` requires a valid bearer token and an eligible account role. Logged-out, invalid-token, and inactive-account requests return 401; authenticated accounts without an eligible role return 403. It accepts:

```json
{
  "event_request": {
    "name": "GreenTech Uganda",
    "email": "events@example.org",
    "phone_number": "+256772345678",
    "event_type": "workshop",
    "title": "Digital Skills Workshop",
    "description": "A practical digital skills workshop for learners and teachers.",
    "preferred_date": "2027-12-15",
    "location": "Kampala",
    "additional_information": "Projector access requested.",
    "terms_accepted": true,
    "submission_key": "a unique UUID v4"
  }
}
```

Types: `workshop`, `webinar`, `mentorship`, `career_talk`, `community_event`. The response contains `reference` and `detail`. The server validates lengths, date, international phone format, event type, consent, and request key. A new request returns 201; an identical retry returns 200 with the original reference; conflicting reuse returns 409. Public contact and hosting requests share the existing five-per-hour IP throttle. Notifications and duplicate prevention are transactional.

Requests are stored as `PublicInquiry` records with category `event_hosting`, an authenticated `requester_id`, structured `event_details`, a review status, and a revision number. Submission keys remain bound to the submitting account. The general contact endpoint rejects the event-hosting category.

## Review and publication

Admin and Super Admin staff with `system.manage` receive an in-app notification and review requests at `/admin/inquiries`.

- **Approve & Create Draft:** requires `dashboard.read` and `dashboard.manage` as well. Staff confirm future start/end times, format, location, and optional capacity. Times use the platform timezone. Approval creates one linked **draft** event, owned by the host, and records the reviewer and decision time. Public listings exclude the draft. Staff use **Finalize Draft Event** to open the existing event editor, add or revise details, then use **More → Publish event** when ready.
- **Request Changes:** requires feedback, notifies the host, and allows that host to edit and resubmit the proposal. Resubmission returns the request to Pending Review and alerts staff again.
- **Reject Request:** requires feedback and closes that request. A host can submit a new proposal separately.

Hosts can view status, staff feedback, and the published event link in **My Event Requests** on `/host-an-event`. Requests are private to the submitting account. Primary and additional hosting roles are supported. In-app notifications link to this section; decision and publication alerts respect existing notification preferences and platform notification settings.

Only Pending Review requests can receive a decision. Approved and rejected requests are terminal; event cancellation/publication is managed through the linked event. Reviews and resubmissions require the current `lock_version` so stale tabs cannot overwrite decisions or create duplicate events. Draft creation, approval, notifications, and audit records run in one database transaction.

Legacy hosting requests are linked to existing accounts using the previously stored server-assigned `submitted_by_id`. Requests without a surviving eligible account cannot be approved; staff can contact the organizer or reject them. Existing contact and partnership requests keep their Mark Reviewed action.

## Workflow API

- `GET /api/v1/me/event-hosting-requests?page=1`: authenticated account's requests, 20 per page, with current status, feedback, revision, and linked event summary.
- `PATCH /api/v1/me/event-hosting-requests/:id`: eligible owner resubmits an updated `event_request` plus `lock_version`, only when Changes Requested.
- `POST /api/v1/admin/inquiries/:id/decision`: authorized staff send a `review` object containing `decision` (`approved`, `rejected`, `changes_requested`), `note`, and `lock_version`. Approval also supplies `event` with `starts_at`, `ends_at` (ISO 8601 with timezone offsets), `format`, `location`, and optional `capacity`. Publication status, event title, description, and organizer are assigned by the server.

Migrations: `20261115010000_add_event_hosting_to_public_inquiries.rb` and `20261116000000_add_event_request_approval.rb`. Run `bin/rails db:migrate` in other environments before deploying.

Validation: UI typecheck, lint, and production build; full Rails suite (472 tests, 3,975 assertions). Coverage includes role restrictions, private request lists, review permissions, stale decisions, one-draft creation, transaction rollback, required feedback, owner resubmission, publication visibility and notifications. A production-build browser check against the real API verified request → changes → resubmission → approval → draft editing → publication, host notifications, rejection feedback, platform timezone conversion, and mobile sizing. Temporary accounts and records were isolated to the test database and cleaned up afterward.
