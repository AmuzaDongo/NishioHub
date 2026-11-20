# Admin dashboard navigation

The dashboard keeps the existing design and opens the dedicated management pages:

- Total Users and Mentors open Users & Roles, retaining the Mentor role filter.
- Mentees, Sessions, and Events metrics open their management pages.
- Top Programs opens program details; View All opens the program list.
- Upcoming Events opens event details; View All selects the Upcoming tab.
- Search results open their respective record pages; user results filter by account ID.
- Add User, Create Program, Schedule Session, Create Event, and Upload Resource
  navigate to the corresponding management page and open its creation form once,
  after checking permissions. The action query parameter is then consumed.
- User growth and role distribution open Reports & Analytics with the dashboard's
  selected reporting period. Goal and session insights open Goals & Progress and Sessions.
- Related activity records link to the relevant page. Certificate activities open
  the certificate list because their internal numeric IDs differ from public identifiers.
  Activity History remains a dashboard dialog.
- Report table names/titles link to user records or their detail pages. Custom
  previews link records when the selected columns include their IDs.
- Older `/admin?panel=programs|sessions|resources|events` and
  `/admin?tab=bookings` links redirect to the current pages.

All destination APIs retain their authorization checks. Creation controls remain
disabled for read-only administrators.

Verified with the real isolated API in Chrome: metrics, all five creation forms,
program detail/list, upcoming-event tab, preserved report period, report detail
links, goal/session insights, related activities, and read-only controls. No
JavaScript exceptions occurred. TypeScript, targeted ESLint, and production build
checks were also run.
