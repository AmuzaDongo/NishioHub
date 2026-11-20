# Mentor application form

Route: `/mentor/application`. Uses Tailwind and the shared public header. The layout follows `NishioHub Mentor Application Dashboard.png`: purple mentor hero and quote, eligibility/benefits sidebar, application card, four-step progress bar, three numbered form sections, photo upload, expertise chips, learner checkboxes, policy agreement, Save Draft and Next: Review & Submit.

## Form and review

- Personal information: application name, contact email, international telephone, city/district, gender and date of birth. New drafts prefill name/email/telephone from the signed-in account. These are application contact snapshots; saving them does not change login credentials or the account name.
- Professional details: qualification, occupation, optional organization and experience range. Exact existing years are preserved when within the chosen range; otherwise the range minimum is used. The API rejects inconsistent year/range values.
- Expertise: up to 12 distinct tags, custom areas, target learner groups and a 100–300 word bio, up to 2,000 characters. Experience and field validation run on the server as well as in the UI.
- One agreement records Code of Conduct, Child Safeguarding Policy and Terms of Service acceptance. Policy version: `2026-11-15`.
- The progress buttons navigate the first three form sections. Next validates and saves the draft, then opens Review & Submit. The review includes all saved fields, private supporting documents and references. Missing requirements block submission.
- The existing review process remains: submitted applications lock, admins can request changes or reject with feedback, and authorized approval grants Mentor while preserving existing roles. Newly approved profiles remain unpublished until the mentor publishes them.

## Photo and documents

Profile photos accept JPG/PNG up to 2 MB. Government ID, CV and qualification/experience evidence accept PDF/JPG/PNG up to 5 MB each, also subject to the platform upload limit. All uploads are MIME-checked, scoped to the account and protected by revisions.

The form saves current draft changes before uploads or document removal. Photo previews use authenticated blob downloads and revoke browser object URLs. Signed storage URLs are not included in application responses. Supporting documents remain private; they are never copied to public profiles. Only the approved profile photo is attached to the mentor profile. Mentor portrait rendering prefers that photo while preserving the separate account avatar.

Sign-in and mentor registration preserve the application destination, including the header actions. Anonymous users can see the reference layout and are directed to sign in before saving. Personal fields and previews clear after logout; delayed responses cannot replace a different account’s form state.

## Compatibility and administration

Migration: `20261115000000_expand_mentor_application_form.rb`, applied locally to development and the isolated test database. Existing records retain form version 1 so submitted applications remain reviewable. New drafts use version 2; saving the new fields upgrades a legacy draft. Clients cannot downgrade the form version. Admins see all new personal/professional fields, consent, learner groups and the downloadable photo alongside the existing private documents.

Assets are reused from the completed onboarding page: `public/images/onboarding/mentor-hero.webp` and `public/images/onboarding/graduation-books.webp`. Their generation prompts and provenance are in `mentor-onboarding.md`.

## Verification

API tests cover field persistence, unchanged credentials, required photo/bio/consent, strict dates and contact formats, list validation, old application compatibility, revision checks, committed uploads and approval portrait selection. Browser verification covers draft reload, photo upload, tags, review, private document downloads, requested changes, resubmission, approval, mentor profile access, logout clearing and responsive layouts.

Final checks: 455 Rails tests, 3,718 assertions, zero failures/errors/skips. TypeScript, targeted ESLint and production build pass. Temporary QA accounts were removed before the final regression suite. On mobile, the application card appears before the supporting sidebar cards.


## Phone number normalization

Application contacts accept local Ugandan numbers such as `0772 345 678` / `772345678`, or international numbers such as `+256 772 345 678`. Formatting spaces, parentheses and hyphens are removed, `00` international prefixes are accepted, and a pasted full country code is not added twice. An explicitly international number keeps its own country. Clearing the field keeps the selected country code. Application phone values are stored in international format; account phone values are preserved.

Older account numbers are normalized when prefilling a new draft. Unusable old values leave the application contact field empty and editable instead of preventing the application page from opening. Invalid updates still return an example-based error. Browser checks cover local-number account login, pasting, country switching, clearing, other international codes, correction after rejection, saving and reloading.


## Phone input library

The form now uses `react-phone-number-input` (installed version 3.4.18) through `src/components/ui/phone-input.tsx`. The library owns country selection, formatting, parsing and E.164 values; the old custom selector and input parser were removed. Uganda is the default country. The wrapper remembers the library’s current country when clearing and converts its empty `undefined` value to the form’s empty string.

The existing violet borders and country-code presentation use Tailwind. Emoji flags are rendered locally without an external flag CDN. Frontend review validation uses the library’s `isPossiblePhoneNumber`; Rails retains its existing contact normalization for older account/API values. See the [official component documentation](https://github.com/catamphetamine/react-phone-number-input#readme).

Browser verification passed for Ugandan national and international entry, Kenyan/US/German country selection, empty-field country retention, E.164 saving, reload and mobile sizing, without JavaScript exceptions. TypeScript, targeted ESLint and production build pass. `package.json` and `package-lock.json` include the new dependency.
