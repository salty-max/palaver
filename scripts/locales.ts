/**
 * i18n/<locale>/ → addon/Palaver/Text_<locale>.lua, one for every language the
 * game has (a stub where there is no translation yet, so the TOC never names
 * a missing file): each client loads its own, through Text_[TextLocale].lua in
 * the TOCs, and English stays wherever a translation says nothing (Locale.lua).
 * The family's core (scripts/locales-lib.ts, the kit's copy) reads the words,
 * merges the kit's own (i18n/kit/, translated once for every addon), checks
 * them and writes the files.
 *
 *   bun scripts/locales.ts            write the Text files
 *   bun scripts/locales.ts --check    fail if one isn't up to date, a word has
 *                                     no translation, a translation drops or
 *                                     reorders a blank, or prose has a semicolon
 *   bun scripts/locales.ts --keys     write i18n/words.json, every word to translate
 */
import { join } from "node:path";
import { json, q, run } from "./locales-lib";

const ROOT = new URL("..", import.meta.url).pathname;
const I18N = join(ROOT, "i18n");

// The game's own names a language's file carries, every language's whole
// (English one of them): the quests' kinds (i18n/quest_types.json, written
// by scripts/quests.ts from the client's QuestInfo).
function namesLua(locale: string): string[] {
  const types: Record<string, Record<string, string>> = json(join(I18N, "quest_types.json"));
  const mine = types[locale];
  if (!mine) throw new Error(`i18n/quest_types.json names nothing in ${locale}: bun scripts/quests.ts`);
  const lines = ["ns.names({", "  questTypes = {"];
  for (const [id, name] of Object.entries(mine).sort(([a], [b]) => Number(a) - Number(b))) lines.push(`    [${id}] = ${q(name)},`);
  lines.push("  },", "})");
  return lines;
}

run({ root: ROOT, addon: "addon/Palaver", names: namesLua });
