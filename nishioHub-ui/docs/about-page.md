# About page

`/about` uses the shared public header and the supplied purple/white reference layout. Mission, vision, values, story, impact, audience and leadership sections use Tailwind. The About dropdown also links to `/about#story` and `/about?view=team`.

## Public API

`GET /api/v1/platform/about` returns only:

- `impact.learners`: active accounts with the mentee role, including additional roles.
- `impact.mentors`: active mentor accounts with verified, published mentor profiles.
- `impact.resources`: published, non-archived, non-deleted platform-visible resources.
- `impact.events`: published, non-deleted events, including past events. Zero while public events are disabled.
- `impact.organizations`: active school/organization accounts, counted once. This is explicitly labeled as accounts, not claimed partnerships.
- `story_video_url`: optional official story video URL.
- `team`: explicitly published name, title, biography and photo URL. Account identities, emails and private team drafts are excluded.

The UI loads these values using React Query with skeletons, retries and periodic refresh. No screenshot totals or invented staff profiles are seeded.

## Story and team management

Authorized admins/super admins with `system.manage` see **Manage About Content** in the leadership panel. The editor uses the existing versioned, audited `GET/PATCH /admin/system_settings` API and supports up to 20 curated team profiles, draft/public status, removal and an optional HTTPS MP4/WebM video. Photos must use HTTPS. Unknown team fields and invalid URLs are rejected server-side. No database migration is needed; these use the existing settings JSON field.

**Watch Our Story** opens the configured video with native playback controls. If none is configured, or playback fails, it opens a three-chapter illustrated story with Previous/Next navigation. Direct entry at `/about?view=story` is supported. **Meet Our Team** opens published profiles, or a truthful empty state linked to the contact page.

Audience cards link to school partnerships, programs, mentor discovery and mentor onboarding. Impact cards link to the related catalog or partnership page. The header search action opens mentor discovery.

## Artwork

New asset: `public/images/about/mentorship-about-hero.webp`, created with the built-in imagegen tool and compressed with ImageMagick. It is illustrative promotional artwork, not documentation of an actual session. Other portraits/story imagery reuse existing local assets.

Generation prompt:

> Use case: photorealistic-natural. Asset type: wide About page hero photograph for an African mentorship platform. Primary request: a warm Black Ugandan male mentor wearing glasses and a navy blazer guiding three smiling Black African teenage learners in purple school sweaters and white shirts around a laptop in a sunlit school library. Include a girl with braided hair, a boy in white shirt and purple tie, and a learner seen in profile at far right. Natural editorial lifestyle photograph with authentic faces and professional quality. Landscape 2:1 composition, heads and laptop visible, open welcoming atmosphere, lush greenery and shelves softly blurred. Purple and navy brand accents, warm daylight. No text, no logos, no watermarks. Illustrative promotional artwork, not a real documented session.

## Verification

494 Rails tests / 4,288 assertions passed, including public count visibility, unpublished team privacy, URL/field validation, role authorization, audited publication and stale-update conflicts. TypeScript, lint and production build passed. Headless Chrome verified story chapter navigation/deep links, team empty state, admin publishing and persistence, private draft exclusion, unpublishing and desktop/mobile layout without horizontal overflow or JavaScript exceptions. Temporary QA accounts/content were cleaned up and the normal production build was restored.
