#!/bin/sh
set -eu

usage() {
  echo "usage: publish_site.sh --source SITE_DIR --review-receipt FILE --remote-root ABSOLUTE_DIR --site-slug SLUG [--apply]" >&2
  exit 2
}

source_dir=
review_receipt=
remote_root=
site_slug=
apply=0
remote_host=infra-admin@100.82.43.93

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source) [ "$#" -ge 2 ] || usage; source_dir=$2; shift 2 ;;
    --review-receipt) [ "$#" -ge 2 ] || usage; review_receipt=$2; shift 2 ;;
    --remote-root) [ "$#" -ge 2 ] || usage; remote_root=$2; shift 2 ;;
    --site-slug) [ "$#" -ge 2 ] || usage; site_slug=$2; shift 2 ;;
    --apply) apply=1; shift ;;
    *) usage ;;
  esac
done

[ -n "$source_dir" ] || usage
[ -n "$review_receipt" ] || usage
[ -n "$remote_root" ] || usage
[ -n "$site_slug" ] || usage
[ -d "$source_dir" ] || { echo "source is not a directory: $source_dir" >&2; exit 2; }
[ -f "$source_dir/index.html" ] || { echo "source has no index.html: $source_dir" >&2; exit 2; }
[ -f "$review_receipt" ] || { echo "review receipt is not a file: $review_receipt" >&2; exit 2; }

case "$remote_root" in
  /srv/?*|/var/www/?*|/home/infra-admin/www/?*|/opt/insecure-sites/?*) ;;
  *)
    echo "remote root must be a dedicated subtree under /srv, /var/www, /home/infra-admin/www, or /opt/insecure-sites" >&2
    exit 2
    ;;
esac
case "$remote_root" in
  */../*|*/..|*//*|*[!A-Za-z0-9_./-]*) echo "unsafe remote root: $remote_root" >&2; exit 2 ;;
esac
case "$site_slug" in
  ""|.*|*..*|*[!A-Za-z0-9_-]*) echo "unsafe site slug: $site_slug" >&2; exit 2 ;;
esac

managed_dir=$remote_root/$site_slug

source_abs=$(cd "$source_dir" && pwd -P)
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM
manifest_path=$temp_dir/payload.txt
digest_path=$temp_dir/payload.sha256
snapshot_dir=$temp_dir/snapshot
snapshot_manifest=$temp_dir/snapshot-payload.txt
snapshot_digest_path=$temp_dir/snapshot-payload.sha256
mkdir -p "$snapshot_dir"
python3 "$script_dir/validate_site.py" "$source_abs" \
  --manifest "$manifest_path" --digest-file "$digest_path"
rsync --archive --files-from="$manifest_path" --relative "$source_abs/" "$snapshot_dir/"
python3 "$script_dir/validate_site.py" "$snapshot_dir" \
  --manifest "$snapshot_manifest" --digest-file "$snapshot_digest_path"
cmp -s "$manifest_path" "$snapshot_manifest" || { echo "snapshot manifest changed during preparation" >&2; exit 1; }
cmp -s "$digest_path" "$snapshot_digest_path" || { echo "snapshot content changed during preparation" >&2; exit 1; }
payload_digest=$(tr -d '\n' < "$snapshot_digest_path")
python3 "$script_dir/verify_review_receipt.py" "$review_receipt" "$payload_digest"
release_nonce=$(python3 -c 'import secrets; print(secrets.token_hex(8))')
release_name=$payload_digest-$release_nonce
release_dir=$managed_dir/releases/$release_name

echo "source:      $source_abs/"
echo "snapshot:    $snapshot_dir/"
echo "digest:      $payload_digest"
echo "ssh target:  $remote_host"
echo "remote root: $remote_root/"
echo "managed dir: $managed_dir/"
echo "release dir: $release_dir/"
echo "served link: $managed_dir/current"
echo "payload:"
sed 's/^/  /' "$manifest_path"

if [ "$apply" -eq 0 ]; then
  echo "mode:        dry-run (snapshot and receipt verified; no remote writes)"
  ssh "$remote_host" sh -s -- "$remote_root" "$site_slug" "$release_name" <<'REMOTE'
set -eu
remote_root=$1
site_slug=$2
release_name=$3
test -d "$remote_root"
root_real=$(realpath "$remote_root")
test "$root_real" = "$remote_root"
managed_real=$(realpath -m "$remote_root/$site_slug")
case "$managed_real" in "$root_real"/*) ;; *) exit 1 ;; esac
if [ -e "$managed_real" ] || [ -L "$managed_real" ]; then
  test -d "$managed_real"
  test ! -L "$managed_real"
fi
releases=$managed_real/releases
if [ -e "$releases" ] || [ -L "$releases" ]; then
  test -d "$releases"
  test ! -L "$releases"
  releases_real=$(realpath "$releases")
  test "$releases_real" = "$releases"
else
  releases_real=$releases
fi
release_real=$(realpath -m "$releases/$release_name")
test "$release_real" = "$releases_real/$release_name"
current=$managed_real/current
if [ -e "$current" ] || [ -L "$current" ]; then
  test -L "$current"
  current_real=$(realpath "$current")
  case "$current_real" in "$managed_real"/releases/*) ;; *) exit 1 ;; esac
fi
REMOTE
  exit 0
fi

echo "mode:        apply (versioned release; atomic current link)"
ssh "$remote_host" sh -s -- "$remote_root" "$site_slug" "$release_name" <<'REMOTE'
set -eu
remote_root=$1
site_slug=$2
release_name=$3
test -d "$remote_root"
root_real=$(realpath "$remote_root")
test "$root_real" = "$remote_root"
managed_root=$(realpath -m "$remote_root/$site_slug")
case "$managed_root" in "$root_real"/*) ;; *) exit 1 ;; esac
if [ -e "$managed_root" ] || [ -L "$managed_root" ]; then
  test -d "$managed_root"
  test ! -L "$managed_root"
fi
mkdir -p -- "$managed_root"
test -d "$managed_root"
test ! -L "$managed_root"
releases=$managed_root/releases
if [ -e "$releases" ] || [ -L "$releases" ]; then
  test -d "$releases"
  test ! -L "$releases"
else
  mkdir -- "$releases"
fi
releases_real=$(realpath "$releases")
test "$releases_real" = "$releases"
release_dir=$(realpath -m "$releases/$release_name")
test "$release_dir" = "$releases/$release_name"
current=$managed_root/current
if [ -e "$current" ] || [ -L "$current" ]; then
  test -L "$current"
  current_real=$(realpath "$current")
  case "$current_real" in "$managed_root"/releases/*) ;; *) exit 1 ;; esac
fi
[ ! -e "$release_dir" ] && [ ! -L "$release_dir" ]
mkdir -- "$release_dir"
REMOTE
ssh "$remote_host" sh -s -- "$remote_root" "$site_slug" "$release_name" <<'REMOTE'
set -eu
remote_root=$1
site_slug=$2
release_name=$3
root_real=$(realpath "$remote_root")
test "$root_real" = "$remote_root"
managed_root=$(realpath "$remote_root/$site_slug")
test "$managed_root" = "$root_real/$site_slug"
test -d "$managed_root"
test ! -L "$managed_root"
releases=$managed_root/releases
test -d "$releases"
test ! -L "$releases"
releases_real=$(realpath "$releases")
test "$releases_real" = "$releases"
release_dir=$(realpath "$releases/$release_name")
test "$release_dir" = "$releases/$release_name"
test -d "$release_dir"
test ! -L "$release_dir"
REMOTE
rsync --archive --verbose --checksum --itemize-changes \
  --files-from="$snapshot_manifest" --relative \
  "$snapshot_dir/" "$remote_host:$release_dir/"
ssh "$remote_host" sh -s -- "$remote_root" "$site_slug" "$release_name" <<'REMOTE'
set -eu
remote_root=$1
site_slug=$2
release_name=$3
root_real=$(realpath "$remote_root")
test "$root_real" = "$remote_root"
managed_root=$(realpath -m "$remote_root/$site_slug")
case "$managed_root" in "$root_real"/*) ;; *) exit 1 ;; esac
test "$managed_root" = "$root_real/$site_slug"
test -d "$managed_root"
test ! -L "$managed_root"
releases=$managed_root/releases
test -d "$releases"
test ! -L "$releases"
releases_real=$(realpath "$releases")
test "$releases_real" = "$releases"
release_dir=$(realpath "$releases/$release_name")
test "$release_dir" = "$releases/$release_name"
test -d "$release_dir"
test ! -L "$release_dir"
test -f "$release_dir/index.html"
test ! -e "$managed_root/current.next"
ln -sfn "$release_dir" "$managed_root/current.next"
mv -Tf "$managed_root/current.next" "$managed_root/current"
REMOTE
