#!/bin/sh
# Adds (or removes) the Sand Software Solutions apt repository on Debian, Ubuntu and derivatives.
#
#   curl -fsSL https://sandsoftwaresolutions.github.io/apt/setup.sh | sudo sh
#   curl -fsSL https://sandsoftwaresolutions.github.io/apt/setup.sh | sudo sh -s -- --remove
#
# What it does, and only this:
#   1. downloads the repository's public signing key to /etc/apt/keyrings/sandsoftwaresolutions.asc
#   2. writes /etc/apt/sources.list.d/sandsoftwaresolutions.list, limited to that key (signed-by)
#   3. runs "apt-get update"
# It installs no package. Read it first if you like; it is short on purpose.
#
# Options: --dry-run (print what would happen), --remove (undo it), -h
set -eu

BASE="https://sandsoftwaresolutions.github.io/apt"
KEYFILE="/etc/apt/keyrings/sandsoftwaresolutions.asc"
LISTFILE="/etc/apt/sources.list.d/sandsoftwaresolutions.list"
FINGERPRINT="CB6C C8F3 21CC A896 3632  AE9C 76A7 F0CC AAD7 49B7"

dry=0; remove=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry=1 ;;
    --remove) remove=1 ;;
    -h|--help) sed -n '2,13p' "$0" 2>/dev/null || echo "see https://sandsoftwaresolutions.github.io/apt/"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }
run() { if [ "$dry" = 1 ]; then say "[dry run] $*"; else "$@"; fi; }

command -v apt-get >/dev/null 2>&1 || { say "This needs apt (Debian, Ubuntu or a derivative)." >&2; exit 1; }
[ "$dry" = 1 ] || [ "$(id -u)" = 0 ] || { say "Run this as root: curl -fsSL $BASE/setup.sh | sudo sh" >&2; exit 1; }

if [ "$remove" = 1 ]; then
  run rm -f "$LISTFILE" "$KEYFILE"
  run apt-get update -qq
  say "Removed the Sand Software Solutions repository. Installed packages stay; remove them with apt remove."
  exit 0
fi

arch="$(dpkg --print-architecture 2>/dev/null || echo unknown)"
case "$arch" in
  amd64|arm64) ;;
  *) say "Packages exist for amd64 and arm64; this system is $arch." >&2; exit 1 ;;
esac
command -v curl >/dev/null 2>&1 || { say "This needs curl: apt-get install curl ca-certificates" >&2; exit 1; }

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
say "Downloading the signing key ..."
curl -fsSL "$BASE/key.asc" -o "$tmp"
grep -q "BEGIN PGP PUBLIC KEY BLOCK" "$tmp" || { say "The downloaded key does not look like a PGP key; stopping." >&2; exit 1; }

run install -d -m 0755 /etc/apt/keyrings
if [ "$dry" = 1 ]; then say "[dry run] install key as $KEYFILE"; else install -m 0644 "$tmp" "$KEYFILE"; fi
line="deb [signed-by=$KEYFILE] $BASE stable main"
if [ "$dry" = 1 ]; then say "[dry run] write $LISTFILE: $line"; else printf '%s\n' "$line" > "$LISTFILE"; fi
run apt-get update -qq

say
say "Done. Key fingerprint: $FINGERPRINT"
say "Install the tools with:  apt install foundry assay"
