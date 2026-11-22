#!/usr/bin/env bash
set -euo pipefail
base=${1:-/var/www/nishioHub}
[[ $base =~ ^/[a-zA-Z0-9/_-]+$ ]] || exit 1
exec 9>"$base/.deploy.lock"
flock -w 1200 9
sha=$(cat "$base/.deployed-sha")
[[ $sha =~ ^[a-f0-9]{40}$ ]] || exit 1
export RELEASE_SHA="$sha" CERTBOT_DIR="$base/certbot"
compose=(docker compose -p nishiohub --env-file "$base/.env" --project-directory "$base/releases/$sha" -f "$base/releases/$sha/docker-compose.yml")
"${compose[@]}" run --rm --no-deps certbot -c 'exec certbot renew --webroot -w /var/www/certbot --non-interactive'
"${compose[@]}" exec -T nginx nginx -s reload
