# Public home page

The Tailwind home page follows the supplied mentorship-journey reference: purple
announcement/header, photographic hero, journey stages, discover/connect/grow,
feature cards, real mentor profiles, schools/organizations section, call to action,
and footer. Mobile navigation and horizontal overflow are handled responsively.
Brand name, logo, favicon, support email, registration controls, and public event
visibility come from platform settings.

Public visitors see explicitly labeled example goals/progress in the hero. Signed-in
mentees see their actual saved goals and average progress through the existing goals
API. Featured mentors come from active, verified mentor profiles, including additional
mentor roles. No online presence, fake mentor names, or private account information
is invented by the page. Missing avatars use initials.

Public catalog routes are `/programs`, `/learn`, and `/community-events`, backed by
`GET /api/v1/platform/catalog?kind=programs|learning|events&q=&page=`. They show active
program summaries, course summaries without lesson content, and published future
events when public events are enabled. Pagination/search run on the server. Cards
link visitors to registration and authenticated learners to existing event/course
workflows. Public program discovery does not automatically enroll a visitor.
`GET /api/v1/platform/home` serves featured mentors and upcoming public events.

Become a Mentor links preselect Mentor on registration; default learner CTAs choose
Mentee. Existing accounts route to the relevant dashboard/account. Registration
role query parameters accept Mentor/Mentee only; server registration protections
remain authoritative. Journey/footer anchors scroll to their matching sections.
Social links open share dialogs rather than inventing platform social accounts.

Partnership links open the existing Contact form with partnership preselected.
Submissions now persist through `POST /api/v1/platform/inquiries`, show a receipt
reference, and create an in-app notice for active staff with `system.manage`.
They do not send email. The old simulated submission has been removed. Anonymous
submissions are validated and limited to five per source IP per hour using a hashed
IP and a transaction lock. Request parameters are redacted from controller logs.
Staff can review requests at `/admin/inquiries`, linked from the admin account menu
and notifications. That API/page requires administrator `system.manage` access.

Apply migration `20261112000000_create_public_inquiries.rb` with `bin/rails db:migrate`.

## Illustration assets

Built-in `imagegen` mode produced the hero and a five-panel journey illustration.
The selected artwork is stored in the repository as compressed WebP, around 330 KB
combined. Originals remain in the generator's output directory. The journey image
is displayed as five CSS background crops; real mentor cards never use these portraits.

- `public/images/home/mentorship-hero.webp`
- `public/images/home/journey-portraits-v2.webp`

Hero prompt:

> Create a high quality photorealistic website hero photograph, wide landscape 3:2,
> no text no logos no interface overlays. Ugandan mentorship in a sunlit modern
> school library: a warm smiling adult Black Ugandan woman mentor with braided
> updo hair wearing a rich purple blazer sits at a wooden table helping two Black
> Ugandan children aged around 11-13, a girl with neat braids wearing light lavender
> school shirt and purple sleeveless uniform and a boy in lavender shirt. They
> collaborate around a tablet, notebooks and laptop. On the far right laptop screen
> shows an adult Black male mentor in glasses on a video call, believable single-person
> video portrait without legible UI text. Beautiful natural expressions, empowering
> respectful educational scene, purple school color accents, bright green foliage
> through windows, bookshelves, clean warm daylight, professional commercial
> photography, lifelike anatomy, all faces unobstructed. Important composition all
> three people and device centered/right, photo fills frame edge to edge, no borders,
> no lettering. This is an illustrative promotional scene, not a real user's photograph.

Journey prompt:

> Create a photorealistic editorial portrait contact sheet for a Ugandan mentorship
> website. Exactly FIVE equal width vertical panels side by side, ordered left to
> right, no gaps, no borders, no text no logos. Each panel has one different Black
> Ugandan person photographed outdoors in warm natural daylight at school/university/
> campus, softly blurred greenery and architecture. Panel 1: cheerful primary school
> boy age 10 in lavender collared shirt and dark purple school vest with backpack.
> Panel 2: smiling secondary school girl age 16 in lavender shirt and purple school
> vest, neat braids, backpack. Panel 3: friendly university student young man age 22
> wearing pale blue shirt, backpack. Panel 4: confident young professional woman
> age 26 with natural braids, tan blazer over black blouse. Panel 5: accomplished
> male founder age 40, glasses, dark suit, smiling. Compose matching chest-up
> portraits of the same scale with every face centered horizontally within its panel,
> heads near the TOP THIRD of frame, whole face and shoulders visible. Educational,
> respectful, aspirational commercial photography, lifelike anatomy. Use the entire
> canvas as five precise equal-width strips. Do not merge subjects across panels.
> These are illustrative editorial fictional people, not real user profiles.


Journey refinement prompt (built-in image editing of the first contact sheet):

> Edit this five-panel contact sheet. Preserve the five equal-width vertical panels,
> the five fictional Ugandan people in the same left-to-right age order, their purple
> school uniforms and professional clothing, warm campus setting and photorealistic
> quality. The only required change is CAMERA DISTANCE: zoom OUT substantially in
> every panel to medium-long waist-up portraits with much more campus background
> around each person. Each person's head, from hair to chin, must occupy at most
> 25 percent of the panel width and at most 15 percent of total image height,
> positioned centered horizontally near the TOP QUARTER of the image. Make the
> people smaller within each panel so a website can crop a short wide card from the
> upper part while retaining the whole face. All five whole heads, hair, chins and
> shoulders must be visible with generous space. Show upper torso and backpack/
> clothing below, evenly lit. NO text, NO borders, NO graphic overlays. Exact equal
> five-panel photographic contact sheet.
