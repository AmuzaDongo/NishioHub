# Profile and validation fixes across roles

The two stale Rails expectations and nine profile TypeScript errors are resolved. Required phone validation remains in place for every account, including accounts without a role. The no-role model test now supplies valid unrelated account fields. Email verification tests assert the existing JSON confirmation contract instead of an unsupported redirect.

`/edit-profile` now reads and saves real account data through `/api/v1/me/settings`. The former simulated save and invented flat auth-user professional fields have been removed. Common biography, location and website are persisted in the new account-profile fields migration (`20261111000000_add_account_profile_fields.rb`). Mentor title, experience, rate, skills and languages use the persisted mentor profile. Mentee school and grade use the persisted mentee profile. Effective roles, including secondary roles and normalized role names, control available fields; they are never editable through this endpoint.

Profile writes are atomic: invalid professional or learner details roll back common account changes. Nonmentors cannot create a mentor profile by submitting professional fields. Email changes retain current-password verification, session rotation and verification reset. Bios remain synchronized when saved through the canonical mentor editor. Legacy location data remains available until explicitly replaced.

Photo upload and removal use the authenticated account endpoints, with actual file validation and shared avatar fallback removal. Photo changes save immediately; other fields use Save Changes. Generic and administrative account biographies persist even when no legacy Profile row exists.

The shared header handles a null role safely. Shared Settings navigation and labels reflect the real account role. Profile pages no longer display invented school/class/location/bio data or select the first user when a requested profile does not exist. User/profile types describe actual API data instead of adding fictitious auth fields or suppressing compiler errors.

Run `npm run typecheck` to check both application and Vite configuration types, and `npm run build` for production output.

Validation: 371 Rails tests, 2,607 assertions, zero failures/errors. Application and configuration TypeScript checks pass. Production build passes. Browser checks cover mentee, mentor, Admin, Super Admin, moderator, organization, founder, user, custom, roleless and multi-role accounts: save/reload persistence, professional/learner field visibility, generic profile display, avatar upload/removal, truthful role labels and mobile overflow. Temporary browser fixtures were removed from the isolated test database; temporary API/UI/browser processes were stopped.
