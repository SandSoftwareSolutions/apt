#!/usr/bin/env bash
# Builds a signed apt repository in ./site from the .deb files attached to the latest GitHub releases
# of the repositories listed in sources.txt.
#
#   GPG_KEY_ID=<fingerprint> scripts/build-repo.sh           # uses the key in the current GnuPG home
#   KEEP_RELEASES=5 scripts/build-repo.sh                    # versions kept per package (default 5)
#
# Needs: gh (GitHub CLI), apt-ftparchive and dpkg-scanpackages (apt-utils, dpkg-dev), gpg, gzip.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
SUITE="${SUITE:-stable}"
COMPONENT="main"
ARCHES=(amd64 arm64)
KEEP="${KEEP_RELEASES:-5}"
SITE="$ROOT/site"
: "${GPG_KEY_ID:?set GPG_KEY_ID to the fingerprint of the signing key}"

rm -rf "$SITE" .download
mkdir -p "$SITE" .download

# 1. Download the .deb files of the newest releases (drafts and pre-releases are skipped).
while read -r repo; do
  case "$repo" in ''|\#*) continue ;; esac
  echo "[fetch] $repo"
  tags="$(gh release list --repo "$repo" --exclude-drafts --exclude-pre-releases --limit "$KEEP" --json tagName --jq '.[].tagName')"
  for tag in $tags; do
    gh release download "$tag" --repo "$repo" --pattern '*.deb' --dir .download --clobber 2>/dev/null || echo "  (no .deb in $tag)"
  done
done < sources.txt

shopt -s nullglob
debs=(.download/*.deb)
[ "${#debs[@]}" -gt 0 ] || { echo "no .deb files found; refusing to publish an empty repository" >&2; exit 1; }

# 2. Lay out the pool and verify that every package is a well formed deb with the expected name.
for deb in "${debs[@]}"; do
  pkg="$(dpkg-deb -f "$deb" Package)"
  [ -n "$pkg" ] || { echo "$deb has no Package field" >&2; exit 1; }
  dest="$SITE/pool/$COMPONENT/${pkg:0:1}/$pkg"
  mkdir -p "$dest"
  cp "$deb" "$dest/"
done

# 3. Package indexes per architecture.
for arch in "${ARCHES[@]}"; do
  dir="$SITE/dists/$SUITE/$COMPONENT/binary-$arch"
  mkdir -p "$dir"
  (cd "$SITE" && dpkg-scanpackages --arch "$arch" pool > "dists/$SUITE/$COMPONENT/binary-$arch/Packages" 2>/dev/null)
  gzip -9nk "$dir/Packages"
done

# 4. Release file and signatures.
apt-ftparchive \
  -o "APT::FTPArchive::Release::Origin=Sand Software Solutions" \
  -o "APT::FTPArchive::Release::Label=Sand Software Solutions" \
  -o "APT::FTPArchive::Release::Suite=$SUITE" \
  -o "APT::FTPArchive::Release::Codename=$SUITE" \
  -o "APT::FTPArchive::Release::Architectures=${ARCHES[*]}" \
  -o "APT::FTPArchive::Release::Components=$COMPONENT" \
  -o "APT::FTPArchive::Release::Description=Foundry and Assay from Sand Software Solutions" \
  release "$SITE/dists/$SUITE" > "$SITE/dists/$SUITE/Release"

gpg_sign=(gpg --batch --yes --pinentry-mode loopback --default-key "$GPG_KEY_ID")
"${gpg_sign[@]}" --armor --detach-sign --output "$SITE/dists/$SUITE/Release.gpg" "$SITE/dists/$SUITE/Release"
"${gpg_sign[@]}" --clearsign --output "$SITE/dists/$SUITE/InRelease" "$SITE/dists/$SUITE/Release"

# 5. Public key and the page that explains how to use the repository.
gpg --batch --armor --export "$GPG_KEY_ID" > "$SITE/key.asc"
cp "$ROOT/index.html" "$SITE/index.html"
touch "$SITE/.nojekyll"

echo "Repository built in $SITE:"
find "$SITE" -type f | sed "s#$SITE/##" | sort
