# Loading states

Shared Tailwind components live in `src/components/loaders`.

- `BrandLoader` appears in the HTML startup shell and the one-time `StartupGate`. The gate waits for initial account hydration and branding, with a two-second limit on waiting for branding. It stays open afterward, including during login and route changes.
- `MentorCardSkeletonGrid` renders six placeholders on Find Mentors. Existing results stay visible during refresh; failures expose a retry action.
- `ProgramCardSkeletonGrid` covers public program, learning, and event listings.
- `DashboardSkeleton` provides overview, list, and detail layouts for administrative data. `TableSkeleton` can be used standalone; `TableSkeletonRows` belongs inside an existing table section.
- `PageLoader` covers account forms, conversations, and other content panels. Keep the surrounding page navigation visible while data loads.
- `ProgressLoader` shows the current application step and the percentage of required fields, photo, supporting documents, references, and agreements completed. Selecting a step does not mark its requirements complete.
- `ButtonLoader` disables the underlying button while loading and exposes `aria-busy`. Mentor application submission also has a synchronous in-flight guard, with the label “Submitting Application...”.

Skeletons announce one loading status per region. Decorative placeholders are hidden from assistive technology, and animation respects reduced-motion preferences. Loading, error, and empty states remain distinct. No additional dependencies are required.

Validation: `npm run typecheck`, `npm run lint`, and `npm run build`.

Browser verification used held, mocked API responses to check six mentor placeholders, empty-state recovery, navigation without repeating startup branding, application completion, disabled submission and single-request behavior, administrative skeletons, and mobile sizing. No JavaScript exceptions occurred.
