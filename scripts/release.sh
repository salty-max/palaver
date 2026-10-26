#!/usr/bin/env bash
# Cut a release: the family's (addon-kit/release.sh), with this addon's
# folders: bump the version, check, commit, tag, push (atomic: main and the
# tag together). GitHub Actions then packages and publishes it
# (.github/workflows/release.yml): the GitHub release, CurseForge and Wago.
# A stop before the push puts everything back.
#
#   scripts/release.sh --version X.Y.Z [--hold] [--dry-run] NOTES.md
#
#   NOTES.md         release notes (markdown): the tag's message, then the
#                    changelog on GitHub, CurseForge and Wago
#   --version X.Y.Z  required, preflight suggests one
#   --hold           the GitHub release alone (repository variable
#                    HOLD_STORES); the stores later, by hand:
#                    gh workflow run release.yml -f tag=vX.Y.Z
set -euo pipefail
cd "$(dirname "$0")/.."
kit=$(bun scripts/root.ts addon-kit)
exec bash "$kit/release.sh" --folders "addon/Palaver" "$@"
