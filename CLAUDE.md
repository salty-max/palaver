# Palaver

A World of Warcraft addon: DialogueUI's way of talking to NPCs (a panel
beside them, the NPC left in view, large text, the answers as lines, two
buttons with their keys) in the family's look (Hearthtale, the Codex, Yonder,
Second Wind): the game's dark dialog box with its gold border (the kit's
K.dialog), titles in the display face and gold, the bronze ring around the
speaker's face, the bag's slots for items. Decided 18 October 2026, after a
first prototype (`../conversations`, "Conversations", by another agent) was
rejected: its camera and its interaction controller broke in the game.
Mock-ups the user chose (frame A, the gold border): `../ideas/palaver/`.
Local only so far: no GitHub repository, no store page.

## Layout

- `addon/Palaver`: one package for every game (`Palaver_Vanilla.toc`: Classic
  Era, 11509; `_TBC.toc`: TBC Anniversary, 20506; `_Camelot.toc`: Forever,
  16001), the same but for the interface. Loads `Kit.lua` (the kit's copy,
  `bun run kit:sync`; never edit it), `Locale.lua`, `Text_[TextLocale].lua`,
  `Game.lua`, `Rewards.lua`, `Panel.lua`, `Camera.xml`, `Camera.lua`, `Core.lua`.
- `Game.lua`: what the game says, read into plain pages (gossip, greeting,
  detail, progress, complete), and the answers, through the same calls
  Blizzard's windows make (Blizzard_UIPanels_Game's GossipFrameShared.lua,
  QuestFrame.lua, QuestInfo.lua: read them before changing a call, Gethe's
  wow-ui-source, classic_era and the Forever commit). A function one game
  lacks is checked before use (Forever: coins only in C_CurrencyInfo, spells
  through C_QuestInfoSystem; Classic: GetRewardSpell). Buttons and headings
  use the game's own interface strings (`G.word`: ACCEPT, REWARDS...), so
  every client language gets the game's wording.
- `Panel.lua`: the panel. It only shows: hiding it never ends a
  conversation. One height for every page, Blizzard's quest window's (424
  interface units: it follows the UI scale as the game's windows do; a
  long text scrolls). Not in UISpecialFrames (the game hides those at moments of
  its own, which cut trainer conversations short in the prototype).
- `Rewards.lua`: the marks on a choice of two rewards or more (the user's
  pick from DialogueUI's options, 18 October 2026), on the offer and the
  hand-in. A gold coin (UI-GoldIcon) on the one that sells for most (a stack
  at its count, none on a tie), a green arrow (UI-MicroStream-Green, flipped)
  on the best for the character: Pawn's verdict when Pawn is ready
  (PawnIsReady, PawnIsItemAnUpgrade's largest upgrade among the usable
  choices, as its quest advisor; Pawn's 10,000% for an empty slot never
  printed), else Palaver's rough rule (class weights, a hybrid by the tree
  holding ten points and more than half, as Hearthtale's Life.lua reads it,
  else the tree it levels in; GetItemStats against what is worn, a two-hand
  weapon against both hands, an off hand only for one who dual wields;
  trinkets never). An upgrade only: no arrow when nothing beats what is worn.
  Each says why on the card's tooltip. Worked out again when the game tells
  an item late (GET_ITEM_INFO_RECEIVED) or the gear changes; a mark that
  fails drops the marks and keeps the page (PalaverErrors). Unusable rewards
  red, as the game's window. The mock: `../ideas/palaver/D-reward-marks.png`.
- `Core.lua`: the conversation. Blizzard's windows muted once at login, as
  DialogueUI does (QuestFrame's events, GossipFrame's, Forever's
  CustomGossipFrameManager's; only those that were registered, restored
  exactly by `/palaver off`). A close the game sends (GOSSIP_CLOSED,
  QUEST_FINISHED) is acted on a moment later, if no page came since and the
  NPC is no longer talking (C_PlayerInteractionManager), longer after the
  player's answer: a gossip leads to a quest without the panel leaving. A
  close that goes on (GOSSIP_CLOSED's interactionIsContinuing) or a service
  window (vendor, trainer, flight map...) steps the panel aside without a
  word to the game. Only the player ends one: Escape (CloseQuest or
  CloseGossip, as Blizzard's windows when closed), Goodbye or Decline (their
  buttons' calls). Mirrors Blizzard: a lone option the game would skip is
  skipped, a quest from an item is closed (the game accepts it), one reward
  is the choice, a paid turn-in asks the game's own confirmation (TBC and
  Forever) with QuestInfoFrame.itemChoice set. Keys on release and only on
  the page they were pressed on (a held Space never accepts the next quest),
  never in combat, while typing or with a modifier, Escape left to a game
  popup when one is open. A page that fails to draw: the error kept in
  PalaverErrors, the conversation replayed to Blizzard's handler, the rest
  of the session Blizzard's, said once in chat. Another conversation addon
  loaded (DialogueUI, Immersion, Storyline): Palaver stays out, says so.
- `Camera.lua` (and `Camera.xml`, the unseen actor that measures the NPC):
  DialogueUI's "zoom to the NPC", read from its Camera.lua. Off by default
  (`/palaver camera`, until the user has tried it in the game). While a
  conversation lasts: the game's interaction focus on the speaker, the view
  over the shoulder (1.5, mounted 4.8) so the NPC stands beside the panel,
  a one-second tilt (the focus's pitch pull 0 to 1, the pitch limit 88 to 15,
  then released to 88), a zoom in, never out, by the NPC's measured height
  (DialogueUI's bands: under 2 tall, 2 yards; under 2.6, 3...), 4 yards when
  no size comes within half a second. Each setting it changes is written to
  PalaverSettings.cameraBackup as it changes (a crash never restores: the
  next login does, the zoom aside), the game's experimental-settings warning
  silenced only while it lasts. Back at once when the conversation ends, in
  combat and at logout. Not for an item's quest (the player is the "npc").
  Each conversation numbered: a slow model or timer of an older one ignored.
- `addon/test/game.lua`: a small game (frames, events, Blizzard's windows
  as each client registers them, the gossip and quest APIs over a scripted
  NPC, timers, keys); `addon/test/sim.lua`: the flows through it, on
  Classic Era, TBC, Forever and a French client (`bun run check` runs all).
  The simulation proves the flow, not the drawing: render the look first
  (`../ideas/palaver/mock.py`, the game's textures and fonts) and test in
  the game before calling a visual change done.
- Languages: Palaver's own words through `L` (`i18n/<locale>/words.json`,
  `bun run locales`; French, German and Spanish, the last two flagged), the
  game's words for its buttons and headings, the NPCs' and quests' text the
  game's own in the client's language.

## Not yet

- The HUD hidden while talking (DialogueUI's option): the panel would need a
  parent other than UIParent first.
- Settings beyond `/palaver` (scale, font, keys, camera, value, upgrades,
  reset, on, off, errors),
  a minimap button, a welcome page: the kit has them when wanted.
- Releases: a GitHub repository, `.pkgmeta`, the release workflow, store
  pages: when the user decides.

## Commands

```bash
bun run check        # kit, languages, lint, the simulation on four clients, TOCs
bun run package      # dist/Palaver-<version>.zip for a test in the game
bun run kit:sync     # after a change to ../addon-kit/Kit.lua
bun run locales      # after a new L["..."] (then --keys for i18n/words.json)
```

## Conventions

The family's (`../CLAUDE.md`): Conventional Commits, lowercase subjects, no AI
co-author trailers; commit locally, ask before any push, release or deploy;
no semicolons in what players read, in any language.
