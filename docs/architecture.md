# Palaver's architecture

The addon file by file (moved from CLAUDE.md on 20 October 2026; the map
stays there). The quest facts' data: `docs/data.md`.

## The package

- `addon/Palaver`: one package for every game (`Palaver_Vanilla.toc`: Classic
  Era, 11509; `_TBC.toc`: TBC Anniversary, 20506; `_Camelot.toc`: Forever,
  16001), the same but for the interface and each game's quest facts
  (`Quests_Classic.lua`, TBC Anniversary's too, `Quests_Forever.lua`). Loads
  `Kit.lua` (the kit's copy, `bun run kit:sync`; never edit it),
  `Locale.lua`, `Text_[TextLocale].lua`, `Quests_<game>.lua`, `Game.lua`,
  `Rewards.lua`, `Panel.lua`, `Hud.lua`, `Camera.xml`, `Camera.lua`,
  `Core.lua`, `Settings.lua`.

## The files

- `Game.lua`: what the game says, read into plain pages (gossip, greeting,
  detail, progress, complete), and the answers, through the same calls
  Blizzard's windows make (Blizzard_UIPanels_Game's GossipFrameShared.lua,
  QuestFrame.lua, QuestInfo.lua: read them before changing a call, Gethe's
  wow-ui-source, classic_era and the Forever commit). A function one game
  lacks is checked before use (Forever: coins only in C_CurrencyInfo, spells
  through C_QuestInfoSystem; Classic: GetRewardSpell). Buttons and headings
  use the game's own interface strings (`G.word`: ACCEPT, REWARDS...), so
  every client language gets the game's wording. The offer page's facts
  (`G.facts`: the data above, and the game's suggested group,
  GetSuggestedGroupNum, which Blizzard's Classic window no longer shows).
  Books, letters and plaques (`G.book`: Blizzard's ItemTextFrame.lua's
  calls, a page in HTML read as plain text, the writer of a letter, the
  page number; Next and Close the game's words, Prev a page back).
- `Panel.lua`: the panel. It only shows: hiding it itself never ends a
  conversation, but its window's close button (or anything else hiding it)
  does, as Escape. The family's window (K.gameWindow; K.dialog where a game
  has none): the speaker's name in the title bar (SetTitle), their face in
  the corner (SetPortraitToUnit, the book's icon for a book or an item's
  quest: Blizzard's GossipFrameShared's calls), a quest's title in gold
  beside the face (a book's page number there in a small line), the kit's
  panel (K.panel) from 62 units down (clear of the face, Yonder's 58), the
  keyed buttons under it. No parent: it stays when the interface is hidden (Hud.lua),
  at UIParent's scale times Palaver's, followed on UI_SCALE_CHANGED; its
  keys' listener (Core) the same; its tooltip Palaver's own while the
  interface is hidden (the game's goes with it). The offer's facts a line
  above its text (the level in the game's difficulty colour, the kind in
  gold); a book's page back a square footer button with the spellbook's
  arrow (mocks: `../ideas/palaver/E-facts.png`, `F-book.png`, in the gold
  box then; the family's window: `I-family-palaver.png`). Space or Enter
  on a page longer than the panel scrolls a panel's height first (`readOn`,
  on: no quest accepted with its rewards unseen; a click answers at once). One height for every page, Blizzard's quest window's (424
  interface units: it follows the UI scale as the game's windows do; a
  long text scrolls). Not in UISpecialFrames (the game hides those at moments of
  its own, which cut trainer conversations short in the prototype).
- `Rewards.lua`: the marks on a choice of two rewards or more (the user's
  pick from DialogueUI's options, 18 October 2026), on the offer and the
  hand-in. A gold coin (UI-GoldIcon) on the one that sells for most (a stack
  at its count, none on a tie), a green arrow (UI-MicroStream-Green, flipped)
  on the best for the character, by Palaver's own rule: no other addon
  asked, Pawn included (the user's call, 18 October 2026: no dependency on
  another addon, even an optional one). Class weights, a hybrid by the tree
  holding ten points and more than half, as Hearthtale's Life.lua reads it,
  else the tree it levels in; GetItemStats against what is worn, a two-hand
  weapon against both hands, an off hand only for one who dual wields;
  trinkets never. An upgrade only: no arrow when nothing beats what is worn.
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
- `Settings.lua`: the page in the game's Options (AddOns tab), as the
  siblings have theirs (Second Wind's): every setting /palaver changes,
  through the same `ns.core.set` (what each changes at once: Palaver muted or
  not, the size, the camera put back, the marks again). Account-wide, no
  profiles: a reading panel's settings. `/palaver settings` opens it.
- `Hud.lua`: the game's interface hidden while a conversation or a book
  lasts (`hideUI`, on by default since 18 October 2026, saved files of
  before switched on once by `version`; DialogueUI's fade helper the
  reference): a quarter second's fade, then SetUIVisibility. Back at once
  for a fight (PLAYER_REGEN_DISABLED comes before the lock), a popup of the
  game's (StaticPopup_Show hooked), a cinematic, a page that fails, the
  setting off, and before the window a gossip option opens: GOSSIP_CLOSED's
  interactionIsContinuing after an option picked (UIParent_OnShow closes
  every window open, the vendor's with it, if it comes back after). Never
  touched in combat, and one the player hid (Alt+Z) left alone.
- `Camera.lua` (and `Camera.xml`, the unseen actor that measures the NPC):
  DialogueUI's "zoom in", its default settings played as they are (read
  line by line from its Code/Camera.lua, Peterodox's YUI-Dialogue on GitHub,
  22 October 2026). On by default, as DialogueUI's (the user's call the
  same day; saved files of before switched on once by `version` 3;
  `/palaver camera` turns it off). While a conversation lasts, someone to look at (an
  NPC): the game's interaction focus on the speaker, the view over the
  shoulder (1.5, times 4.8 on a mount: 7.2) so the NPC stands beside the
  panel, a one-second eased tilt (the focus's pitch pull 0 to 1, the pitch
  limit 88 to 15 unrounded, then released to 88, the field of view from the
  player's to 75, kept on Forever on a mount or gliding, and put back there
  on mounting mid-conversation: DialogueUI means to, but its restore reads
  the wrong table and never does), a zoom in, never
  out, by the NPC's measured height (DialogueUI's bands: under 2 tall, 2
  yards; under 2.6, 3...), waited for however long the model takes (a model
  without a size: no zoom; an NPC the game won't let be measured, C_Secrets:
  4 yards). No one to look at (an object's quest, an item's, an NPC whose
  identity is secret): the view slides aside by how far out it is
  (DialogueUI's line, 0.4314 a yard), the zoom to 3, in or out. Its side
  the panel's (dragged left: the other shoulder, -1, -0.3 on a mount),
  followed when the panel moves; a mount and a druid's form (DialogueUI's
  offsets by GetShapeshiftFormID) followed while it lasts. It stays through a
  fight, as DialogueUI's does. Each setting it changes is written to
  PalaverSettings.cameraBackup as it changes (a crash never restores: the
  next login does, the zoom aside). The game's experimental-settings warning
  (Accept or Disable, Disable resetting every test_ setting) kept quiet:
  Classic Era's on UIParent, muted only while the camera is changed;
  Forever's on Blizzard_Game's own frame (GameEvent, 12.1), let go for the
  session at the camera's first use, as DialogueUI does (a handler an addon
  put back would be the addon's, run by the game's popups). Back at once
  when the conversation ends, at a logout, a quit or a camp's countdown. Not
  for a book (DialogueUI's book doesn't move it either). Each conversation
  numbered: a model of an older one ignored. Every way into it guarded (its
  start, stop, tilt, slide, events, the model's load): an error of its own
  puts the camera back and leaves it still for the session, kept once for
  `/palaver errors` with the stack where it was thrown, the conversation
  going on (the interface hidden before the camera starts). Not taken from DialogueUI: its
  DynamicCam hand-off (no other addon's API) and its camera options (the
  zoom multiplier, the field of view off, the mount's offset off, the
  sideways-only mode, none in instances), not approved.

## Tests

- `addon/test/wowmock.lua` (the kit's copy, `kit:sync`): frames, events,
  timers, the character, the Options page; `addon/test/game.lua`: Palaver's
  world on it (Blizzard's windows as each client registers them, the gossip
  and quest APIs over a scripted NPC, keys, the camera's settings, TBC); `addon/test/sim.lua`: the flows through it, on
  Classic Era, TBC, Forever and a French client (`bun run check` runs all).
  The simulation proves the flow, not the drawing: render the look first
  (`../ideas/palaver/mock.py`, the game's textures and fonts) and test in
  the game before calling a visual change done.

## Languages

- Languages: Palaver's own words through `L` (`i18n/<locale>/words.json`,
  `bun run locales`; French, German and Spanish, the last two flagged), the
  game's words for its buttons and headings, the NPCs' and quests' text the
  game's own in the client's language.
