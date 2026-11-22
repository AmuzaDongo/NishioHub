#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
base=${1:-/var/www/nishioHub}
sha=${2:?Provide the full release commit SHA}
[[ $base =~ ^/[a-zA-Z0-9/_-]+$ && $sha =~ ^[a-f0-9]{40}$ ]] || { echo 'Invalid deployment path or SHA' >&2; exit 1; }
release="$base/releases/$sha"
[[ -f "$release/docker-compose.yml" && -f "$base/.env" ]] || { echo 'Release or production .env missing' >&2; exit 1; }
exec 9>"$base/.deploy.lock"
flock -w 1200 9
export CERTBOT_DIR="$base/certbot" RELEASE_SHA="$sha"
mkdir -p "$base/backups" "$CERTBOT_DIR/www" "$CERTBOT_DIR/conf"
compose() { docker compose --project-name nishiohub --env-file "$base/.env" --project-directory "$release" -f "$release/docker-compose.yml" "$@"; }
previous=''
[[ ! -f "$base/.deployed-sha" ]] || previous=$(cat "$base/.deployed-sha")
[[ -z $previous || $previous =~ ^[a-f0-9]{40}$ ]] || exit 1
activated=false
failed() {
  status=$?
  trap - ERR
  echo "Deployment $sha failed (exit $status)." >&2
  compose ps >&2 || true
  if $activated && [[ -n $previous && -f "$base/releases/$previous/docker-compose.yml" ]]; then
    echo "Restoring application release $previous; database migrations are not reversed." >&2
    release="$base/releases/$previous"
    export RELEASE_SHA="$previous"
    compose up -d --no-build --wait --wait-timeout 180 api ui && compose up -d --no-build --no-deps --force-recreate --wait --wait-timeout 60 nginx || echo 'Automatic application rollback failed; inspect the server.' >&2
  fi
  exit "$status"
}
trap failed ERR
compose config --quiet
compose build --pull api ui
# Existing PostgreSQL data stays in the original nishiohub_postgres_data volume.
compose up -d --wait --wait-timeout 120 db
backup="$base/backups/pre-${sha}-$(date -u +%Y%m%dT%H%M%SZ).dump"
compose exec -T db pg_dump -U nishiohub -d nishiohub_production -Fc > "$backup.tmp"
mv "$backup.tmp" "$backup"
# Preserve uploads from a legacy API container before introducing persistent volumes.
old_api=$(docker ps -aq --filter label=com.docker.compose.project=nishiohub --filter label=com.docker.compose.service=api | head -1)
for mapping in api_storage:storage api_uploads:public/uploads profile_uploads:public/media/profiles; do
  volume="nishiohub_${mapping%%:*}"
  if ! docker volume inspect "$volume" >/dev/null 2>&1; then
    copy=$(mktemp -d "$base/.upload-copy.XXXXXX")
    source_dir="$copy"
    if [[ -n $old_api ]]; then
      if [[ ${mapping#*:} == storage ]]; then
        docker cp "$old_api:/app/storage/." "$copy/"
      else
        docker cp "$old_api:/app/public/." "$copy/"
        relative=${mapping#*:}
        source_dir="$copy/${relative#public/}"
      fi
    fi
    docker volume create "$volume" >/dev/null
    if [[ -d $source_dir ]]; then
      if ! docker run --rm -v "$volume:/target" -v "$source_dir:/source:ro" alpine:3.22 cp -a /source/. /target/; then
        # This volume was created by this run and has never been used by the API.
        docker volume rm "$volume" >/dev/null
        echo "Upload import failed; the legacy API data is still intact." >&2
        false
      fi
    fi
    find "$copy" -depth -delete
  fi
done
compose run --rm --no-deps api bin/rails db:migrate
activated=true
compose up -d --no-build --wait --wait-timeout 240 api ui
if [[ ! -s "$CERTBOT_DIR/conf/live/nishiohub.com/fullchain.pem" ]]; then
  compose -f "$release/ops/compose.bootstrap.yml" up -d --no-deps --force-recreate --wait --wait-timeout 60 nginx
  compose run --rm --no-deps certbot -c 'exec certbot certonly --webroot -w /var/www/certbot --non-interactive --agree-tos --email "$LETSENCRYPT_EMAIL" --cert-name nishiohub.com -d nishiohub.com -d www.nishiohub.com -d api.nishiohub.com'
fi
# Recreate the proxy so upstream addresses and renewed certificates are current.
compose up -d --no-build --no-deps --force-recreate --wait --wait-timeout 60 nginx
curl --fail --silent --show-error --retry 5 --retry-connrefused --resolve nishiohub.com:443:127.0.0.1 https://nishiohub.com/healthz >/dev/null
curl --fail --silent --show-error --retry 5 --retry-connrefused --resolve api.nishiohub.com:443:127.0.0.1 https://api.nishiohub.com/up >/dev/null
printf '%s\n' "$sha" > "$base/.deployed-sha.tmp"
mv "$base/.deployed-sha.tmp" "$base/.deployed-sha"
echo "Deployment $sha is healthy. Backup: $backup"
