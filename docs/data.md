# Palaver's data

The quest facts from wow-data (moved from CLAUDE.md on 20 October 2026).

- `scripts/quests.ts`: the quest facts from wow-data's databases, each game's
  own (`--check` in `bun run check`; the daily `game-data.yml`, once the
  repository is on GitHub): a quest's level, its kind (the client's
  QuestInfo: elite, dungeon, raid, PvP), its place in its chain, packed in a
  number by its id; and `i18n/quest_types.json`, the kinds' names, the
  client's own, in every language (`scripts/locales.ts` puts them in each
  Text file, English one of them). A chain is the game's NextQuestInChain
  alone: a prerequisite is no chain ("Dwarven Outfitters" opens eleven of
  Coldridge's quests, none its part 2); the Defias Brotherhood comes out 7
  parts, Northshire's kobolds 5, Stalvan's legend 13.
