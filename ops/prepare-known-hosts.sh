#!/usr/bin/env bash
# Accept a trusted server public key or traditional known_hosts entries on stdin.
# No keys are fetched from the network and no key contents are logged.
set -euo pipefail
umask 077
host=${1:?Provide SERVER_HOST}
port=${2:-22}
output=${3:?Provide the destination known_hosts file}
[[ $host =~ ^[a-zA-Z0-9.-]+$ && $port =~ ^[0-9]+$ ]] || { echo 'Invalid SSH hostname or port' >&2; exit 1; }
lookup="$host"
[[ $port == 22 ]] || lookup="[$host]:$port"
temporary=$(mktemp)
trap 'rm -f "$temporary"' EXIT
tr -d '\r' | awk 'NF && $1 !~ /^#/' > "$temporary"
if [[ ! -s $temporary ]]; then
  echo '::error::SERVER_KNOWN_HOSTS is empty.' >&2
  exit 1
fi
# A raw server public key deliberately pins that key to the configured endpoint.
# Traditional known_hosts entries retain their original host restrictions.
awk -v host="$lookup" '
  $1 ~ /^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-nistp256@openssh.com)$/ {print host, $1, $2; next}
  {print}
' "$temporary" > "$output"
chmod 600 "$output"
if ! ssh-keygen -l -f "$output" >/dev/null 2>&1; then
  echo '::error::SERVER_KNOWN_HOSTS is not a valid server host key. Copy the entire /etc/ssh/ssh_host_ed25519_key.pub line from the trusted server console, not its SHA256 fingerprint.' >&2
  exit 1
fi
if ! ssh-keygen -F "$lookup" -f "$output" >/dev/null; then
  echo '::error::The full known_hosts entries do not match SERVER_HOST and SERVER_PORT. Alternatively, supply the raw server public key from /etc/ssh/ssh_host_ed25519_key.pub so the workflow can add the endpoint automatically. Check the production environment secret too.' >&2
  exit 1
fi
