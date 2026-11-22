# Production deployment

Pushes to `main` automatically deploy the exact tested commit. Pull requests run checks only. Manual workflow runs deploy only from `main`. The workflow tests the UI and Rails API, validates Compose, builds both production images, then sends a Git archive over verified SSH to `/var/www/nishioHub/releases/<commit>`. The existing checkout stays in place; no force reset or server-side GitHub token is needed.

## One-time server setup

1. Install Docker Engine and the current Compose plugin (`docker compose`, minimum v2.20), Git, curl, tar, and flock. Give the deployment account access to Docker and ownership of `/var/www/nishioHub`. Docker group membership grants administrative access; use a dedicated deployment account.
2. Point DNS A records for `nishiohub.com`, `www.nishiohub.com` and `api.nishiohub.com` to the server. If AAAA records exist, they must reach this server too. Allow inbound TCP 80 and 443, plus your SSH port. An existing host Nginx/Apache must release 80/443 before the container proxy starts.
3. Copy `ops/production.env.example` to `/var/www/nishioHub/.env`, fill every required value, and run `chmod 600 /var/www/nishioHub/.env`. Reuse the existing PostgreSQL password and Rails master key. Generate independent random values for the three application secrets (for example `openssl rand -hex 64`). Set a real `LETSENCRYPT_EMAIL`. SMTP is optional. Do not commit production secrets.
4. Configure GitHub Actions secrets (repository secrets or the `production` environment): `SERVER_HOST`, `SERVER_USER`, `SERVER_SSH_KEY`, `SERVER_KNOWN_HOSTS`, optionally `SERVER_PORT` (default 22). The SSH public key must be authorized on the server. Verify the server host-key fingerprint through a trusted channel before adding its known-hosts entry. Optional variable `DEPLOY_PATH` changes the base directory. The environment must permit `main`; leave manual approval disabled for fully automatic deployments.
5. Push the committed deployment changes to `main`, or run the workflow from `main`. This workspace is not deployed until the changes are committed/pushed and server prerequisites are satisfied.

The first deployment starts an HTTP-only ACME proxy if certificates are absent, requests one Let's Encrypt certificate covering all three names, then enables HTTPS. Certbot failure stops deployment. The production proxy never needs a self-signed certificate. PostgreSQL and API ports are not published to the host.

## Release sequence and recovery

The server script serializes runs with `flock`, builds SHA-tagged images before replacing applications, waits for PostgreSQL, creates a custom-format `pg_dump` backup, and migrates without seeding development accounts. It then replaces the API/UI, waits for real health checks, recreates Nginx to refresh upstream addresses, and checks both HTTPS endpoints with certificate verification. Only after success does `.deployed-sha` change.

The existing `nishiohub_postgres_data` volume is retained. New volumes persist Active Storage, general uploads and profile uploads. On the first migration to this setup, if an old API container exists and these volumes do not, the script copies its files before replacing it. No data volume is removed by deployment. If legacy data used another project/volume name, reconcile it before running: do not start a fresh database over an existing production installation.

A failure after application activation restores the last successful release's images/configuration. Failed builds or migrations leave the previous application running. **Database schema changes are not automatically reversed.** Use backward-compatible migrations (expand/contract); rolling back code cannot undo a destructive migration. Backups are in `backups/` with restricted permissions. Copy backups off-server and test restores; deployment does not delete backups, releases or images automatically.

To redeploy a retained release manually:

```bash
bash /var/www/nishioHub/releases/COMMIT_SHA/ops/deploy.sh /var/www/nishioHub COMMIT_SHA
```

This runs forward migrations from the selected release; it does not execute database down-migrations. Inspect migration compatibility before manually selecting an older release. The automatic rollback only restarts retained images and does not run migrations.

## Certificate renewal

Run the renewal helper daily as the deployment user using cron. It shares the deployment lock and reloads Nginx only after successful renewal:

```cron
20 3 * * * /bin/bash -c 'b=/var/www/nishioHub; r=$(cat "$b/.deployed-sha"); exec "$b/releases/$r/ops/renew-certificates.sh" "$b"' >> /var/www/nishioHub/certificate-renewal.log 2>&1
```

For a custom deployment base, adjust both cron paths. Verify issuance/renewal with Certbot's `renew --dry-run` after the first successful deployment.

## Validation and operations

```bash
bash -n ops/deploy.sh ops/renew-certificates.sh
python3 -m unittest discover -s ops/tests -v
docker compose --env-file ops/production.env.example config --quiet
```

Production Compose commands must use the active release file, production env file and fixed project name `nishiohub`, not an arbitrary checkout. `/up` verifies API boot and PostgreSQL access; UI `/healthz` verifies its serving container. HTTPS probes verify the proxy and certificate paths. Read service logs to diagnose failures, without printing the production environment or complete Compose configuration.

The local deployment tests simulate success, build failure, migration failure, activation rollback and initial certificate provisioning. GitHub CI performs actual Docker builds. A live TLS issuance cannot be tested without server access and correctly configured public DNS.

References: [Compose startup health checks](https://docs.docker.com/compose/how-tos/startup-order/), [Compose wait options](https://docs.docker.com/reference/cli/docker/compose/up/), [GitHub deployment environments](https://docs.github.com/en/actions/concepts/workflows-and-actions/deployment-environments).

The API CI job is pinned to `ubuntu-24.04` to retain the prebuilt Ruby 3.3.6 required by the Gemfile, lockfile and Docker image. Moving the runner to a newer Ubuntu image requires a coordinated Ruby-version update; changing only `ruby-version` would conflict with the application’s exact Ruby requirement.

## Fixing SSH host-key verification

`SERVER_SSH_KEY` identifies the deployment account. `SERVER_KNOWN_HOSTS` identifies the **server**; they are different keys. The known-hosts secret must contain complete `hostname key-type base64-key` lines, not only a `SHA256:...` fingerprint or an account's `authorized_keys` entry. It must match the exact `SERVER_HOST` and SSH port. A DNS name and its IP address are separate known-hosts names.

First, use your hosting provider's trusted server console to obtain the server fingerprint:

```bash
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub -E sha256
```

On your computer, collect the host key using the same host and port as the workflow (replace the example values):

```bash
deploy_host=YOUR_SERVER_HOST
deploy_port=22
ssh-keyscan -T 10 -p "$deploy_port" -t ed25519 "$deploy_host" > server-known-hosts
ssh-keygen -lf server-known-hosts -E sha256
```

Compare the SHA256 fingerprint with the trusted console output. **Only if they match**, copy the full contents of `server-known-hosts` into the GitHub Actions secret `SERVER_KNOWN_HOSTS`. If you configured secrets in the `production` environment, update that environment's secret; it overrides a repository secret with the same name. For a nonstandard port, the host field must be `[YOUR_SERVER_HOST]:PORT`; `ssh-keyscan -p` formats it automatically.

Commit/push the workflow validation change and rerun deployment. The workflow now rejects malformed or mismatched entries before SSH and explicitly uses the provided key and known-hosts file. It keeps `StrictHostKeyChecking=yes`. Never trust a freshly scanned key without checking its fingerprint, and never disable strict checking to bypass this failure. For a replaced/rebuilt server, verify its new fingerprint before changing the secret.
