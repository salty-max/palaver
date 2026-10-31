# Palaver

A World of Warcraft addon: DialogueUI's way of talking to NPCs (a panel
beside them, the NPC left in view, large text, the answers as lines, two
buttons with their keys) in the family's look (Hearthtale, the Codex, Yonder,
Second Wind): their window (the kit's K.gameWindow, its body dark), the
speaker's face in its corner as Blizzard's quest and gossip windows have it,
titles in the display face and gold, the bag's slots for items. Decided 18
October 2026, after a first prototype (`../conversations`, "Conversations",
by another agent) was rejected: its camera and its interaction controller
broke in the game. The gold dialog box (mock A) was the first look; the user
switched to the family's window the same evening (mocks G and I in
`../ideas/palaver/`).
On GitHub (salty-max/palaver, public, 19 October 2026). Released on GitHub,
CurseForge (1754439) and Wago (ZKbqbO61) since 21 October, v0.2.2 the
latest. Classic Era (11509) and Forever (16001), one package. Read the
family's CLAUDE.md (`../CLAUDE.md`) first.

## Where things are

| What | Where |
|---|---|
| The addon file by file: the package, Game, Panel, Rewards, Core, Settings, Hud, Camera, the tests, languages | `docs/architecture.md` |
| The quest facts from wow-data (`scripts/quests.ts`: level, kind, chain) | `docs/data.md` |
| The release pipeline, artwork, what isn't done yet | `docs/releases.md` |
| The mocks and the renderer of the look | `../ideas/palaver/` (`mock.py`) |
| Blizzard's windows, read before changing a call | the pinned wow-ui-source through `bun wow-data/bin/ui.ts frame|find` (`wow-data/docs/ui-source.md`): GossipFrameShared.lua, QuestFrame.lua, QuestInfo.lua, ItemTextFrame.lua |
| Palaver's own words: the voice, one name per thing, the line shapes | `docs/voices.md` |
| The store page | `addon/CURSEFORGE.md` |

## Commands

```bash
bun run check        # kit, quests, languages, lint, the simulation on three clients, TOCs
bun run check:ci     # what CI and the release gate run: no family folder (the kit, the saved ids and the generators' checks aside)
bun scripts/root.ts --run addon-kit/q.ts check -- bun run check   # the same, quiet, stamping the tree for the push
bun run package      # dist/Palaver-<version>.zip for a test in the game
bun run kit:sync     # after a change to the kit (Kit.lua, Media, scripts/root.ts)
bun run locales      # after a new L["..."] (then --keys for i18n/words.json)
bun run quests       # the quest facts again, after wow-data's databases change
scripts/release.sh --version X.Y.Z [--hold] NOTES.md   # check, tag, push; Actions publish
```

## Hard rules

- No other addon's API, even optional (Pawn removed, the user's call, 18
  October 2026). Another conversation addon loaded (DialogueUI, Immersion,
  Storyline): Palaver stays out and says so.
- Only the player ends a conversation (Escape, Goodbye, Decline). Hiding the
  panel never does. Keys act on release, on the page they were pressed on,
  never in combat, while typing or with a modifier.
- The game's own calls, as Blizzard's windows make them, and the game's own
  interface strings for buttons and headings. A function one game lacks is
  checked before use.
- Never in UISpecialFrames. The interface hidden (Hud) never in combat, back
  at once for a fight, a popup, a cinematic or a failing page.
- The camera on by default, as DialogueUI's (the user's call, 22 October
  2026; saved files of before switched on once, `version` 3). Its moves are
  DialogueUI's, read from its Code/Camera.lua (Peterodox's YUI-Dialogue):
  a change to them is checked there first. Every setting it changes is
  saved as it changes, restored at the next login after a crash.
- The quest facts come from wow-data only (`scripts/quests.ts`, through
  `scripts/root.ts`); `Quests_*.lua` and `i18n/quest_types.json` are
  generated, never edited by hand.
- The simulation proves the flow, not the drawing: render the look first
  (the game's textures and fonts) and test in the game before calling a
  visual change done.
- `Kit.lua`, `Media/`, `scripts/root.ts` (and `root.py`), `scripts/locales-lib.ts`, `scripts/package-lib.ts`,
  `i18n/kit/` (the kit's words, translated once), `wow.yml`, `stylua.toml` and
  `addon/test/wowmock.lua` (the tests' game) are the kit's copies: edit addon-kit, then `bun run kit:sync`. The addon's
  own globals for selene are `palaver.yml`.
- Every word through `L`, no semicolons in what players read, in any
  language.
- Conventional Commits, lowercase subjects, no AI trailers. Commit locally;
  ask before any push, release or deploy. The pre-push hook wants a check
  stamp on the tree (q), which `release.sh` makes after the version bump.
