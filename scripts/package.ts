/**
 * The addon's package: the family's (scripts/package-lib.ts, the kit's copy):
 * addon/Palaver as it is, one zip for every game, each game loading its own
 * TOC; its TOCs checked.
 *
 *   bun scripts/package.ts           dist/Palaver and dist/Palaver-<version>.zip
 *   bun scripts/package.ts --no-zip  the folder only (to copy into a game)
 *   bun scripts/package.ts --check   the TOCs only
 */
import { join } from "node:path";
import { run } from "./package-lib";

// (each game's own files: the quests' facts)
run({ root: join(import.meta.dir, ".."), name: "Palaver", games: { classic: ["Quests_Classic.lua"], forever: ["Quests_Forever.lua"] } });
