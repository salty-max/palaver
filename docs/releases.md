# Palaver's releases, artwork and what's not done

(Moved from CLAUDE.md on 20 October 2026.)

## Releases

- Releases (prepared 19 October 2026, as Keyring's): `.pkgmeta` (the BigWigs
  packager: addon/Palaver alone), `.github/workflows/release.yml` (a tag
  vX.Y.Z: the sims, the package checked to be the folder, then GitHub,
  CurseForge and Wago; HOLD_STORES=true holds the stores), `ci.yml` (every
  push: locales, lint, the four sims, the package), `game-data.yml` (daily),
  `scripts/release.sh [--version X.Y.Z] [--hold] NOTES.md`. The store page
  `addon/CURSEFORGE.md` (title "Palaver: Quest & NPC Dialogue", the summary
  the TOCs' Notes, the siblings, Ko-fi, DialogueUI credited), put up by
  `bun ../addon-kit/store.ts` once the projects exist.

## Artwork

`assets/logo-master.png` is the original generated logo, with 1024px and
512px PNG exports and the exact prompt in `assets/logo-prompts.json`.
`addon/Palaver/Media/Logo.tga` is the uncompressed 256px game texture,
rounded as the siblings' (radius 34), used by all three TOCs' IconTexture.
The mark is a parchment speech bubble with a gilded brass rim, turquoise
enamel and three gold conversation dots. NPC portraits stay the NPCs'.

## Not yet

- A minimap button, a welcome page: the kit has them when wanted.
- The CurseForge and Wago projects (their ids in the TOCs: X-Curse-Project-ID, X-Wago-ID; secrets
  CURSEFORGE_TOKEN and WAGO_API_TOKEN; INBOX_EVENTS_TOKEN too, for the daily
  data job's word to the phone), then the first release: the user's go for
  each. Then Palaver in Ravenpost's inbox (`src/digest.ts`, `src/stats.ts`)
  and in the siblings' store pages.
