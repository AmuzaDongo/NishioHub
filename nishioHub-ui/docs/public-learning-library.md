# Public learning resource library

`/learn` follows the supplied learning resources design using Tailwind: purple/yellow hero and search, five format controls, category sidebar, featured cards, learning paths, recently added and popular resources. Public resource summaries open in a preview dialog. Existing courses remain available through **Browse Courses** at `/learn/courses`; learner course enrollment is unchanged.

## Data and access

`GET /api/v1/platform/learning-resources` supports `q`, `category`, `path`, `format`, `sort` (featured/recent/popular/title), `page`, `per_page` (3/6/9/12), `featured` and authenticated `saved` filtering. It returns matching cards, recent/popular lists and actual category totals. Search escapes wildcard characters, filters combine, sorting is stable and results are paginated.

Only published, non-archived, non-deleted, platform-visible resources appear. Staff/program-only resources never enter this public catalog, including for administrative visitors. The API exposes summaries and safe metadata rather than resource URLs, filenames, content bodies or learner identities. Thumbnails use a controlled publication-gated endpoint, not permanent blob URLs:

- `GET /api/v1/platform/learning-resources/:id`
- `GET /api/v1/platform/learning-resources/:id/thumbnail`

Full learning material remains behind the existing authenticated `/learning/resources/:id` page and API. Access/progress/feedback restrictions are preserved. No anonymous file/content access was added.

Popularity uses recorded resource opens/downloads; previewing a summary does not fabricate an access. Counts and durations come from real records. Missing page counts/durations/levels are not invented. Uploaded thumbnails take precedence; resources without thumbnails use format icons. The default grid prioritizes administrator-featured records, with truthful “Explore Resources” copy when the cards are not all featured.

## Bookmarks

- `GET /api/v1/me/resource-bookmarks`: own currently public saved IDs.
- `PUT /api/v1/me/resource-bookmarks/:id`: idempotently save a public library resource.
- `DELETE /api/v1/me/resource-bookmarks/:id`: remove only the current user's bookmark.

All active signed-in roles can save resources. Publication changes are checked under a resource lock; user/resource uniqueness is enforced in the database. Saved lists hide withdrawn/private resources. Unsave can clean up an old bookmark without exposing private resource information. UI pending guards prevent duplicate clicks, and IDs/query caches are scoped to the current account.

Guest save/access actions return through login to the same summary. The auth return allowlist accepts only fixed `/learn`, `/learn?saved=true` and numeric `/learn?resource=ID` destinations; arbitrary return URLs are not accepted. Signing in does not silently save or download anything.

## Administration

Migration: `20261119020000_add_public_learning_library.rb` adds `library_details` JSON metadata and the `resource_bookmarks` table. Existing resource metadata defaults to Other Resources with automatic format and All Levels; existing records are not guessed into new categories.

At **Admin Resource Details → Edit Information**, the Public Learning Library controls manage:

- Category: academic, digital, career, entrepreneurship, mentorship, teaching, exams, research, general.
- Learning paths: primary, secondary, university, career, entrepreneurs.
- Format: auto, study_material, video, toolkit, career_guide, learning_path, other.
- Difficulty: all, beginner, intermediate, advanced.
- Optional page count and featured status.

The existing thumbnail, duration and visibility fields remain in the same editor. Metadata is validated, audited and versioned, and can be saved with thumbnail uploads while retaining the protected resource file. Duplicate/restore operations include library metadata. An old version without metadata restores the default metadata. Existing dashboard.read/dashboard.manage permissions and optimistic revisions apply.

## Artwork

Saved asset: `public/images/learning/library-hero.webp`, created using the built-in imagegen tool and compressed with ImageMagick. It is illustrative promotional artwork, not documentation of actual learners. No resource content or activity counts were generated.

Generation prompt:

> Use case: photorealistic-natural. Asset type: wide public learning resource library hero photograph. A friendly Black Ugandan male mentor with glasses and navy casual shirt, a smiling Black African teenage girl with braids wearing a purple hoodie, and a Black African teenage boy in a white shirt and purple sweater vest, learning together around an open laptop in a bright school library. Wide landscape 2:1 composition, all three heads and laptop visible, faces centered within the right two-thirds, warm natural daylight, green plants and bookshelves softly blurred. Authentic editorial promotional photography with purple brand accents, no logos, text, or watermark. Illustrative artwork, not documentation of real students.

## Verification

506 Rails tests passed, plus a focused check preserving an existing protected file during metadata/thumbnail editing. TypeScript, ESLint and production build passed. Headless Chrome verified real thumbnails, category/path/search filters, hidden-content exclusion, login return, bookmark persistence/removal, saved-only filtering, protected resource/download actions, mobile overflow, and admin metadata changes appearing publicly. Temporary QA users/resources were removed after testing.
