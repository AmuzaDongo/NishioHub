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

`SERVER_SSH_KEY` identifies the deployment account. `SERVER_KNOWN_HOSTS` identifies the **server**; they are different keys. The secret accepts either the raw server public key (recommended below), or complete `hostname key-type base64-key` lines. It does not accept a `SHA256:...` fingerprint or an account's deployment key. It must match the exact `SERVER_HOST` and SSH port. A DNS name and its IP address are separate known-hosts names.

The simplest setup is to run this **on the trusted server console**:

```bash
cat /etc/ssh/ssh_host_ed25519_key.pub
```

Copy the entire single line (`ssh-ed25519 AAAA... optional-comment`) into `SERVER_KNOWN_HOSTS`. The workflow now builds the correct hostname/port label from `SERVER_HOST` and `SERVER_PORT`. No network-scanned key is trusted automatically. This requires the updated workflow and `ops/prepare-known-hosts.sh` to be committed and pushed first. A rerun of an old workflow commit will still use the old validation.

Update the `production` environment secret if one exists, since it takes precedence over a repository secret. The raw public-key format avoids DNS-name-versus-IP and custom-port formatting mistakes. Existing full known-hosts entries remain supported and keep their host restrictions.

If you prefer the full known-hosts format, use your hosting provider's trusted server console to obtain the server fingerprint:

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

## Fixing Permission denied (publickey)

Host verification has passed at this point. Authentication uses `SERVER_SSH_KEY` (the deployment account's **private** key). `SERVER_KNOWN_HOSTS` is a different key: the server's public host key. Do not use `/etc/ssh/ssh_host_ed25519_key` as the deployment identity.

On the computer holding your deployment private key, derive its matching public key:

```bash
ssh-keygen -y -f /path/to/deployment_private_key
```

On the trusted server console, set `deploy_user` to the exact GitHub `SERVER_USER` value, then prepare its SSH files:

```bash
deploy_user='YOUR_SERVER_USER'
deploy_home=$(getent passwd "$deploy_user" | cut -d: -f6)
test -n "$deploy_home" || exit 1
deploy_group=$(id -gn "$deploy_user")
sudo install -d -m 700 -o "$deploy_user" -g "$deploy_group" "$deploy_home/.ssh"
sudo touch "$deploy_home/.ssh/authorized_keys"
sudo chown "$deploy_user:$deploy_group" "$deploy_home/.ssh/authorized_keys"
sudo chmod 600 "$deploy_home/.ssh/authorized_keys"
sudo nano "$deploy_home/.ssh/authorized_keys"
```

Append the derived deployment public key as one complete line; keep existing keys. Do not paste the server host key or a fingerprint there. Ensure the account's home is owned appropriately and not writable by other users. The complete matching private key belongs in GitHub `SERVER_SSH_KEY`, including its BEGIN/END lines, with real newlines. The current noninteractive workflow requires a key without a passphrase; an encrypted key needs a separate agent/passphrase integration. Never share the private key in chat or logs.

Test using the same user, host, port and private key from a trusted computer. If rejected, inspect the server's `journalctl -u ssh` (or `sshd` on some distributions). The logs distinguish wrong users, bad permissions and SSH access policies. If root login is disabled, use an authorized non-root deployment account; do not enable password authentication to bypass this error. Check the `production` environment's secrets, since they override repository secrets. The workflow now validates private-key format and tests account authentication before creating release directories.

## Fixing release-directory permission denied

SSH authentication is successful if `mkdir` reports permission denied. Run this once from a server console with sudo access. Replace `YOUR_SERVER_USER` with the exact GitHub `SERVER_USER` value:

```bash
deploy_user='YOUR_SERVER_USER'
deploy_group=$(id -gn "$deploy_user") || exit 1
base=/var/www/nishioHub
sudo mkdir -p "$base/releases" "$base/backups"
sudo chown "$deploy_user:$deploy_group" "$base" "$base/releases" "$base/backups"
sudo chmod 750 "$base" "$base/releases" "$base/backups"
# If the production environment file already exists:
if sudo test -f "$base/.env"; then
  sudo chown "$deploy_user:$deploy_group" "$base/.env"
  sudo chmod 600 "$base/.env"
fi
sudo -u "$deploy_user" test -w "$base/releases" && echo 'Release directory is writable'
```

Use your configured base path if `DEPLOY_PATH` differs. These commands change only the deployment directories and environment file, not their contents recursively. Do not use `chmod -R 777` or recursively chown PostgreSQL volumes, certificate directories, or all of `/var/www`. Then rerun deployment. Docker access is a separate prerequisite: `sudo -u "$deploy_user" docker info` must succeed on the server.
