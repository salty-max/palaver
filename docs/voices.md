# Palaver's voice

Palaver has no character. Its own words are a plain interface voice: a few
labels, tooltips, chat lines and card notes around the game's own text. Written
31 October 2026, from the shipped words (`i18n/words.json`), after the English
audit. The rules for what is Palaver's and what the game's are in
`docs/architecture.md` and `CLAUDE.md`.

## The voice

- **Plain and short.** Second person where it speaks to the player ("your
  conversations", "the stats your class wants"). No jokes, no exclamation marks,
  no semicolons, British spelling. Every sentence has a verb.
- **Never the game's words.** NPC lines, quest text, titles, rewards, buttons
  and headings are the client's own, by tag (`G.word`). Palaver adds only what
  the game leaves out. It never rewrites or copies a game string.
- **Written to be translated.** One idea a sentence. A command word stays
  English inside a sentence (`/palaver scale`, `value`, `upgrades`): the usage
  line says so to a translator, who keeps them.

## One name per thing

The same word in the label, the tooltip, the chat line, the command and the
store page.

| Thing | Name | Not |
|---|---|---|
| The size of the panel | "Panel size", in percent ("Panel size 110%."). The command stays `scale`. | "Scale 1.1" |
| The text's size | "Text size" (command `font`) | |
| The gold coin | the **best value**: the reward that sells for the most | "sells for most", "highest price" |
| The green arrow | the **best upgrade**: the reward that beats what you wear | "the best for you", "beats by most" |
| The game's page for addons | "the game's Options" | "the options" |
| The addon's window | "Palaver's panel" in a chat line or a tooltip | "here" |
| Another conversation addon | "that addon", named by the game's folder name | |

## The shapes

- **A setting's chat line.** "<Setting> on: what it does now." and "<Setting>
  off: what it does now." The master switch says "On: ..." and "Off: ...".
  What it says is true of the state that results: `/palaver on` with a rival
  addon loaded says that Palaver stays out, never "On".
- **A setting's tooltip.** What it does when on, in a sentence with a verb. What
  it does when off, if the player would wonder, in a second sentence that opens
  "When it is off, ...". Never a bare "Off, ...".
- **A label.** A verb phrase for a switch ("Hide the interface while you talk or
  read", "Mark the best value"), a noun for a choice ("Panel size", "Text
  size").
- **A reward card's note.** One sentence under the item's tooltip, naming why:
  "An upgrade over your <item>, by the stats your class wants." and "Sells for
  the most of these rewards: <price>."

## The keys

The footer's badges are Palaver's short words, "Space" and "Esc", because they
sit in a small badge. Everywhere else a key is named in full: Escape, Space,
Enter, Backspace (the last is the game's own `KEY_BACKSPACE`). The client has
`KEY_SPACE` "Spacebar" and `KEY_ESCAPE` "Escape" in every language: Palaver
keeps its short badge words and its translators fit them to the badge.

Escape is not a setting. It says goodbye with the keys off as well
(Blizzard's windows close on it too), and every line that speaks of the keys
says so.
