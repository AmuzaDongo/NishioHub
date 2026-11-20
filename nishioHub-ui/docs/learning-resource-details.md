# Public learning resource details

Published platform resources now open at `/learn/:id` from the learning library. Legacy `/learn?resource=:id` links redirect to this page. Private/program resources retain `/learning/resources/:id` and their existing authorization rules.

The public page renders actual publication metadata, learning outcomes, takeaways, audience, author details, approved comments and related published resources. File/link contents stay authenticated. Preview access is recorded separately from file downloads; administrative previews do not inflate learner statistics.

Administrators with resource management permission can configure **Edit Information → Public Resource Page**. Author information is explicitly public; account names and email addresses are not copied. Configure topic, license/usage terms, learning outcomes, takeaways, intended audiences, and optional author profile information. Thumbnail and captions continue to use existing resource fields.

In **Contents**, attach supporting documents, spreadsheets, images or audio within the platform limit (maximum 10 MB per supplement). Enable **List this supporting resource title publicly** to show the title and file type/size on the public page. This defaults to off for existing content. Downloads and content links still require sign-in. Supporting files are retained in resource versions and copied when duplicating a resource.

Any active signed-in account may submit a comment with an explicit public display name. Comments start pending. Administrators use the resource **Comments** tab to approve, reject or hide comments; approval requires management permission. Only approved comments from active accounts are listed publicly. Users can view and delete their own recent submissions. Submissions use idempotency keys and are limited to ten per account per hour.

Apply API migration `20261119030000_add_resource_pages_and_comments.rb` before deploying the UI. No demo counts, author verification, Excel content or downloadable files are fabricated. Missing optional metadata is represented honestly.

Validation: full Rails suite (511 tests), TypeScript, lint, production build, and desktop/mobile browser checks for public details, login return, bookmarks, downloads, comment moderation and administrator metadata editing.

## Video playback

Video links now use the shared `PlatformVideo`/`MediaLink` components. YouTube watch, short, live and embed links normalize to a privacy-enhanced embedded player; Vimeo links normalize to its embedded player, preserving unlisted video hashes. Direct video file URLs use native HTML video controls. Only exact allowed provider hosts become frames. Provider frames are sandboxed without popup or top-navigation permissions.

Public resource videos play in the hero after the existing authenticated details/access requests. Protected resource links, administrative resource previews, session recordings, event recordings and program/about introductions also play internally. Supporting documents retain their existing links and downloads. Unknown URLs explicitly marked as videos are tried as native video and show an in-platform error if unplayable; no automatic redirect to the host is offered.

Source parser checks: `node tests/video-source.test.mjs`. Browser checks verified login return, public inline playback, protected resource video dialogs and no new browser pages. External provider network playback/availability is outside these local checks.

Provider documentation: [YouTube embedded player parameters](https://developers.google.com/youtube/player_parameters), [Vimeo embedding](https://help.vimeo.com/hc/en-us/articles/12426259908881-How-to-embed-my-video).

Video playback controls are overlaid on resource banners and event recording images; duplicate watch buttons were removed from resource details and program/about introductions. Public, learner and administrator resource video previews use the shared video-only dialog. Program/about videos, session recordings and event video links use the same dialog. It has no visible title, description, padding, grid gap or border; an accessible hidden title and overlaid close button remain. Players keep a responsive 16:9 frame that fits the viewport. Native file captions and chapter start positions are preserved.

Desktop/mobile browser checks measure the player against the dialog rectangle, verify 16:9 proportions and zero padding, and exercise banner login return, close/reopen, administrator previews and an uploaded WebM test file. Tailwind's explicit `aspect-[16/9]` utility is used because the installed legacy aspect-ratio plugin does not emit `aspect-video`.

## Vidstack player

The shared video player now uses `@vidstack/react` 1.15.7 with its default video controls. Source normalization selects the YouTube, Vimeo or HTML video provider explicitly, including MIME types for authenticated blob downloads. WebVTT captions and initial chapter positions pass through to Vidstack. Banner actions and the existing edge-to-edge, accessible dialog stay in place. Provider cookies remain disabled, and embedded providers keep a sandbox without popup/top-navigation permission.

`patches/@vidstack+react+1.15.7.patch` fixes an upstream teardown issue: YouTube/Vimeo void command methods leave pending promises that are rejected without observers when the provider is destroyed. The patch observes only those pending teardown cancellations before rejecting them; callers awaiting the original promises still receive cancellation. This avoids global error suppression. The version is pinned, and `postinstall` reapplies the patch using `patch-package`, which is included for production installs. Revalidate/regenerate the patch when upgrading Vidstack.

Vidstack's YouTube provider intentionally overscans its internal iframe to hide native provider controls. Browser geometry checks therefore measure the visible Vidstack player frame, not that clipped iframe. Source parsing tests cover provider selection, signed file URLs, WebM blob types, private Vimeo hashes and start times.

References: [Vidstack React installation](https://vidstack.io/docs/player/getting-started/installation/react/), [default video layout](https://vidstack.io/docs/player/components/layouts/default-layout/). Vidstack currently receives security fixes only through January 2028; the upstream project recommends Video.js 10 for new projects. This integration retains Vidstack as requested.
