# Public Programs

`/programs` now uses the supplied Programs for Every Stage layout: public navigation, purple hero, benefit strip, six stage controls, program cards, theme filters and closing CTA. Styling uses Tailwind.

## API and data

- `GET /api/v1/platform/programs` accepts `stage`, `theme`, `q`, `page`, `per_page` (4, 8 or 12), and optional `featured` (true/false). Filters combine; search escapes SQL wildcards. Sorting is stable: featured first, title, ID. Only active programs are public.
- `GET /api/v1/platform/programs/:id` returns public descriptions, uploaded banner URL, stages, themes, objectives, delivery mode and schedule. Draft/archived programs return 404 even for admins using this public endpoint. Member identities and enrollment/progress data are not exposed.
- `POST /api/v1/platform/programs/:id/inquiries` accepts `inquiry: {name,email,message,submission_key}`. It validates contacts and UUID v4, snapshots the program ID/title server-side, persists a public inquiry, returns a tracking reference and notifies authorized inbox staff. It uses the existing atomic shared contact throttle and idempotent retries. Client-provided program references are ignored.

Join inquiries are **not enrollments or seat reservations**. Staff follows up about eligibility and school/guardian involvement where relevant, then uses existing admin enrollment controls. No public self-enrollment bypass was introduced.

The admin inbox displays the program reference and a link to `/admin/programs/:id`. Admins/super admins need the existing permissions to read inquiries, edit programs and enroll people.

## Program administration

Migration `20261117020000_add_public_program_discovery.rb` adds `audience_stages`, `themes` and `featured` to programs, plus the inquiry program snapshot. All defaults are empty/false; existing program text is not guessed into audience classifications.

The program list editor and program details editor expose **Public Program Listing** controls. Supported audience stages: primary, secondary, university, career, professionals. Themes: career_guidance, academic_support, digital_skills, entrepreneurship, leadership, wellbeing, industry_exposure, innovation. Arrays must contain unique supported values. Existing authorization, revision checks, banner uploads and enrollments are preserved.

Existing programs remain visible under All Programs. Staff should tag them for stage/theme discovery and select featured programs. No mock program records were added to development data. Uploaded banners are used directly; missing banners use clearly labeled illustrative local artwork.

## UI behavior

Filters, pagination and selected program IDs are encoded in the URL. `?program=123` opens details directly; `?overview=true` opens the illustrated overview. View All resets filters and expands the page size from four to eight. Skeletons, error/retry, empty states and disabled pending actions are implemented. Inquiry forms protect against duplicate clicks and reuse submission keys for unchanged retries. Administrative visitors see a manage-program link in place of the inquiry form.

The shared `Header` compatibility export was restored after an existing import/export mismatch blocked production builds. Its navigation wrapper uses `display: contents` so it does not occupy a full viewport above legacy page content.

## Artwork

Saved asset: `public/images/programs/programs-stages-hero.webp`. Created with the built-in imagegen tool and compressed with ImageMagick. This is illustrative promotional artwork, not evidence of actual program participants.

Generation prompt:

> Use case: photorealistic-natural. Asset type: wide website Programs hero. Primary request: four smiling Black Ugandan people representing stages of learning and mentorship, standing together outside a bright school campus: a primary-school girl with braids in a purple uniform with backpack, a secondary-school boy in a white shirt purple tie and backpack, a young adult woman graduate in black graduation gown and mortarboard with gold trim, and a professional man with glasses in a navy suit with arms folded. Warm optimistic editorial promotional photography, natural skin texture, sunlight and green trees, 2:1 landscape framing, waist-up group with all heads fully visible. No text, logos or watermark. Illustrative promotional artwork, not documentary evidence of real program participants.

## Verification

498 Rails tests / 4,346 assertions passed, including filter validation and SQL wildcard escaping, draft visibility, metadata permissions, join inquiry references, idempotency and no automatic enrollment. TypeScript, ESLint and the production build passed. Headless Chrome exercised uploaded banners, combined stage/theme filters, search and empty states, direct program details, overview, inquiry receipts and admin inbox navigation, metadata editing and public refresh, banner retention, and responsive layout with no JavaScript exceptions. Temporary QA data was removed afterward.
