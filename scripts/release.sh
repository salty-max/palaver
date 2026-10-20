#!/usr/bin/env bash
# Cut a release: bump the addon's version, check, commit, tag, push. GitHub
# Actions then packages and publishes it (.github/workflows/release.yml): the
# GitHub release, CurseForge and Wago Addons.
#
#   scripts/release.sh [--version X.Y.Z] [--hold] [--dry-run] NOTES.md
#
#   NOTES.md         release notes (markdown): the tag's message, then the
#                    changelog on GitHub, CurseForge and Wago
#   --version X.Y.Z  default: the TOCs' version, patch + 1
#   --hold           the GitHub release alone (repository variable
#                    HOLD_STORES); the stores later, by hand:
#                    gh workflow run release.yml -f tag=vX.Y.Z
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="" NOTES="" DRY=0 HOLD=0
while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --hold) HOLD=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -*) echo "unknown option $1" >&2; exit 2 ;;
    *) NOTES="$1"; shift ;;
  esac
done
die() { echo "release: $*" >&2; exit 1; }
[ -n "$NOTES" ] && [ -s "$NOTES" ] || die "give a non-empty release notes file"

git fetch -q origin --tags
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || die "not on main"
[ -z "$(git status --porcelain)" ] || die "the working tree isn't clean"
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "main isn't in sync with origin/main"

TOCS=(addon/Palaver/*.toc)
current=$(sed -n 's/^## Version: *//p' "${TOCS[0]}" | tr -d '\r')
if [ -z "$VERSION" ]; then
  IFS=. read -r ma mi pa <<<"$current"
  VERSION="$ma.$mi.$((pa + 1))"
fi
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "not a version: $VERSION"
TAG="v$VERSION"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "$TAG already exists"

echo "release $TAG: addon $current → $VERSION$([ "$HOLD" = 1 ] && echo ", GitHub only (stores held)")"
[ "$DRY" = 1 ] && { echo "(dry run: nothing changed)"; exit 0; }

perl -pi -e "s/^## Version: .*/## Version: $VERSION/" "${TOCS[@]}"
# The whole check on the bumped tree, the one pushed: q stamps it, and the
# pre-push hook refuses a tree without a stamp.
bun scripts/root.ts --run addon-kit/q.ts check -- bun run check

git add -A
# Nothing to commit when the TOC already had this version (the first release).
git diff --cached --quiet || git commit -q -m "chore(release): $TAG"
git tag -a "$TAG" --cleanup=verbatim -F "$NOTES"
# The stores held back or not: read by the release's workflow, so set first.
if [ "$HOLD" = 1 ]; then
  gh variable set HOLD_STORES --body true >/dev/null
else
  gh variable delete HOLD_STORES >/dev/null 2>&1 || true
fi
git push -q origin main "$TAG"
echo "pushed $TAG"
