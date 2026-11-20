# nishioHub — Backend Migration (Complete)

**Status: complete.** The legacy Python/FastAPI backend has been removed. The
Rails 8.1.4 API is the only backend in this project.

## Architecture

- `nishioHub-ui/` — React + Vite frontend.
- `nishioHub-api/` — Rails 8.1.4 API-only backend (PostgreSQL, JWT, bcrypt).
- PostgreSQL — the only datastore.

The frontend calls the Rails API directly through `VITE_API_BASE_URL`. There is
no Python service, no proxy, and no second backend.

## What was removed

- `nishioHub-API/` — the entire FastAPI service: `app/`, `migrations/`,
  `alembic.ini`, `requirements.txt`, `.env.example`, `.gitignore`, `README.md`,
  and `media/`.
- Its Python test suite, Dockerfile/entrypoint, and Python environment files.
- FastAPI/Python references in the project docs and the Rails test name.

No docker-compose file existed in the package, so there was no compose service
to remove.

## Run it

Backend:

```bash
cd nishioHub-api
bin/setup
cp .env.example .env
# edit .env: DATABASE_URL, SECRET_KEY, EMAIL_TOKEN_SECRET
bin/rails db:create db:migrate db:seed
bin/rails server -p 3000
```

Frontend:

```bash
cd nishioHub-ui
npm ci
npm run dev
```

`nishioHub-ui/.env.development` points at `http://127.0.0.1:3000/api/v1`.
For production, set `VITE_API_BASE_URL` to the deployed Rails API.

## Endpoint reference

The Rails API is the current contract. The "legacy route" column records the
removed FastAPI path for historical reference.

| Legacy route (removed) | Rails route (current) | Status | Notes |
|---|---|---|---|
| `POST /api/v1/auth/register` | `POST /api/v1/auth/register` | 200 | JSON body. `role_id` is validated; blank defaults to the `user` role; unknown returns `400 {"detail":"Invalid role_id"}`. |
| `POST /api/v1/auth/login` | `POST /api/v1/auth/login` | 200 | Form-encoded `username` + `password`. Returns `access_token`, `refresh_token`, `token_type`. |
| `POST /api/v1/auth/refresh` | `POST /api/v1/auth/refresh` | 200 | `refresh_token` query param (body also accepted). Returns a new access token. |
| `POST /api/v1/auth/logout` | `POST /api/v1/auth/logout` | 200 | Revokes the refresh token. `404` when unknown. |
| `GET /api/v1/users/` | `GET /api/v1/users` | 200 | Returns only the caller. |
| `GET /api/v1/users/me` | `GET /api/v1/users/me` | 200 | `UserOut` shape. |
| `GET /api/v1/users/verify-email` | `GET /api/v1/users/verify-email` | 307 | Redirects to `/email-verified`. |
| `GET /api/v1/roles/mentor-mentee` | `GET /api/v1/roles/mentor-mentee` | 200 | Public. |
| `GET /api/v1/roles/` | `GET /api/v1/roles` | 200 | Admin only. `403` for non-admin and for a user with no role. |
| `POST /api/v1/roles/` | `POST /api/v1/roles` | 201 | Admin only. `400` on duplicate name. |
| `PUT /api/v1/roles/{id}` | `PUT /api/v1/roles/:id` | 200 | Admin only. `404` when missing. |
| `DELETE /api/v1/roles/{id}` | `DELETE /api/v1/roles/:id` | 200 | Admin only. Nullifies users' `role_id` instead of deleting users. |
| `GET /api/v1/category/` | `GET /api/v1/category` | 200 | `skip` / `limit` (max 100). |
| `POST /api/v1/category/` | `POST /api/v1/category` | 201 | Public. |
| `GET /api/v1/category/{id}` | `GET /api/v1/category/:id` | 200 | `404` when missing or inactive. |
| `PUT /api/v1/category/{id}` | `PUT /api/v1/category/:id` | 200 | `404` when missing or inactive. |
| `DELETE /api/v1/category/{id}` | `DELETE /api/v1/category/:id` | 200 | Soft delete (`is_active = false`). |
| `GET /api/v1/users/profile/` | `GET /api/v1/users/profile` | 200 | `skip` / `limit`. |
| `POST /api/v1/users/profile/` | `POST /api/v1/users/profile` | 201 | `ProfileOut` shape. |
| `GET /api/v1/users/profile/{id}` | `GET /api/v1/users/profile/:id` | 200 | `404` when missing. |
| `PUT /api/v1/users/profile/{id}` | `PUT /api/v1/users/profile/:id` | 200 | `404` when missing. |
| `DELETE /api/v1/users/profile/{id}` | `DELETE /api/v1/users/profile/:id` | 200 | Returns `{"detail":"Profile deleted"}`. |
| `POST /api/v1/users/profile/{id}/upload-image` | same | 200 | Multipart `file`; `400` for non-images. |
| `GET /api/v1/dashboard/` | `GET /api/v1/dashboard` | 200 | `{"message":"Dashboard summary"}`. |
| `POST /api/v1/notification/` | `POST /api/v1/notifications` | 200 | Mounted in Rails. |
| `GET /api/v1/notification/` | `GET /api/v1/notifications` | 200 | Mounted in Rails. |
| `GET /api/v1/statistics/` | `GET /api/v1/statistics` | 200 | Mounted in Rails. |
| `POST /api/v1/uploads/` | `POST /api/v1/uploads` | 200 | Filename is sanitized. |

Errors use `{"detail": "..."}`. Validation errors return `422` with
`{"detail": ["..."]}`.

## Schema notes

The migrations reproduce the original domain model:

| Table | Columns | Notes |
|---|---|---|
| `roles` | `id` (integer PK), `name` (varchar 50, unique, not null) | Seeded with `admin, moderator, mentor, mentee, user`. |
| `users` | `id`, `full_name` (100, not null), `email` (100, unique, not null), `hashed_password` (128, not null), `is_active` (default true), `is_verified` (default false), `role_id` (FK roles, nullable), `created_at`, `updated_at` | `role_id` stays nullable so a role-less user is representable; authorization returns `403` instead of raising. |
| `profiles` | `id`, `phone_number` (20, unique, not null), `gender` (10, not null), `birth_date` (date, not null), `address` (255, not null), `city` (100, not null), `country` (100, not null), `profile_picture` (255), `bio` (text), `user_id` (FK users, unique, not null), timestamps | 1:1 with `users`. |
| `categories` | `id`, `name` (100, unique, not null), `is_active` (default true), timestamps | Soft delete via `is_active`. |
| `refresh_tokens` | `id`, `token` (text, unique, not null), `user_id` (FK users, on delete cascade, not null), `created_at`, `expires_at` (not null), `revoked` (default false) | `token` is `text` because a JWT can exceed 255 characters. |
| `notifications` | `id`, `title`, `message`, `read` (default false) | No timestamps. |

Integer primary keys and integer foreign keys are used to match the original
`Integer` columns (Rails would otherwise default to `bigint`).

`db/seeds.rb` seeds the five roles and the five frontend categories.

## Authentication notes

- Access token: HS256 JWT, claims `sub` (email) and `exp` (60 minutes).
- Refresh token: HS256 JWT, claims `sub` and `exp` (7 days), stored in
  `refresh_tokens`. Logout sets `revoked = true`. Refresh does not rotate the
  token.
- Passwords use bcrypt directly (`BCrypt::Password`).
- `SECRET_KEY` and `EMAIL_TOKEN_SECRET` come from the environment.
- The admin guard returns `403 {"detail":"Administrator access required"}` for a
  user with no role. It never raises.

## Rails 8 notes

- Resolved versions: Rails 8.1.4, Ruby 3.3.6, Puma 8.0.2, pg 1.7.0,
  bcrypt 3.1.22, jwt 2.10.3, rack-cors 3.0.0, bootsnap 1.26.1, Rack 3.2.8.
- `Gemfile`: `ruby "3.3.6"`, `gem "rails", "8.1.4"`, `puma >= 6.0`,
  `rack-cors ~> 3.0`.
- `config.load_defaults 8.1`; `db/schema.rb` is `ActiveRecord::Schema[8.1]`;
  migrations use `ActiveRecord::Migration[8.0]`.
- `config/environments/*.rb` use `config.enable_reloading` instead of the
  removed `config.cache_classes`.
- `bin/setup`, `bin/docker-entrypoint`, `.dockerignore`, and a Ruby 3.3.6
  Dockerfile are present.
- Solid Cache, Solid Queue, Solid Cable, Thruster, and Kamal are intentionally
  skipped: this is a stateless JSON API with no background jobs, websockets, or
  asset pipeline.
- Test suite: 47 runs, 110 assertions, 0 failures, 0 errors, 0 skips.

## Remaining gaps

- No services, bookings, reviews, conversations, or messages tables/endpoints.
  The frontend remains mock-backed for those flows.
- No user-directory endpoint, so `Profile` can only reliably show the current
  user.
- No password-change endpoint. `Settings` reports that password changes are not
  available in this build.
- No payment, meeting, or realtime messaging integration.
- Rails was verified in development and test only; the Docker image was not
  built in this environment.
