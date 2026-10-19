# Palaver: Quest & NPC Dialogue

<!-- Project description for curseforge.com and Wago (bun addon-kit/store.ts).
The project's title on the stores: "Palaver: Quest & NPC Dialogue" (the
addon's own name stays Palaver). -->

<!-- Summary (the project's summary on CurseForge and Wago, and the TOCs' Notes):
Quests and conversations with NPCs in a panel beside them, read and answered from the keyboard. -->

Palaver replaces the game's quest and gossip windows with a large, readable panel beside the NPC you're talking to. Their words, their quests and your answers sit in one window, the NPC's face in its corner and the NPC still in view. Read at your own pace, then answer with a key.

For Classic Era (including Hardcore and Season of Discovery), TBC Anniversary and World of Warcraft: Forever, in one download.

## Talking to NPCs

- **Space** (or Enter) answers yes: Accept, Continue, Complete Quest.
- **Escape** says goodbye.
- **1 to 9** pick a line, or the reward to take when a quest offers a choice.

A key acts when you let it go, and only on the page you pressed it on, so a held Space never accepts the next quest by accident. On a page longer than the panel, Space scrolls down first, so you never accept a quest with its rewards unseen. In combat, while typing or with a modifier held, the keys stay the game's. A click on any answer works too, and you can drag the window wherever you like.

## What the quest window keeps quiet

A quest's offer shows a line of facts above its text:

- its **level**, in the colour of how hard it is for you,
- whether it's **elite**, a **dungeon**, a **raid** or **PvP**,
- where it sits in its **chain**, like part 2 of 7,
- the group size the game suggests.

## Choosing a reward

When a quest offers a choice of rewards, two marks help you pick:

- a **green arrow** on the one best for your character, weighing the stats your class wants against what you wear,
- a **gold coin** on the one that sells for the most.

Hover a marked reward to see why. The arrow only marks a real upgrade, needs no other addon, and the marks never choose for you. Rewards your character can't use show in red, as in the game's window.

## Books, letters and plaques

Books, letters and plaques open in the same panel, in the same large text. Space turns the page and Backspace turns back.

## The interface out of the way

While you talk or read, the game's interface fades out, so only Palaver's window and the one you speak to stay on screen. It comes back at once for a fight, a vendor, a trainer or a question from the game. Keep it on screen with `/palaver hud` or in the options.

For a closer look, `/palaver camera` moves the view in on whoever speaks, over your shoulder, sized to the NPC, and puts it back when the conversation ends. It's off until you turn it on.

## Compatibility

One download covers Classic Era, Hardcore, Season of Discovery, TBC Anniversary and World of Warcraft: Forever.

The game's own windows are muted while Palaver runs and restored exactly with `/palaver off`. If DialogueUI, Immersion or Storyline is installed, Palaver stays out of its way and says so in chat.

The NPCs' words, the quests and the game's buttons are the game's own, in your client's language. Palaver's own few words speak English, French, German and Spanish. German and Spanish are first translations: corrections are welcome on GitHub. Other clients get English for those few words.

## Settings and commands

Every setting is on Palaver's page under **Options > AddOns > Palaver**, or through `/palaver settings`. Settings are shared by all your characters.

- `/palaver on` or `/palaver off` switches between Palaver and the game's own windows.
- `/palaver scale 1.1` sets the window's size, from 0.7 to 1.5.
- `/palaver font 16` sets the text size, from 12 to 22.
- `/palaver keys` turns the keys on or off.
- `/palaver books` opens books and letters in Palaver or in the game's window.
- `/palaver hud` hides the game's interface while you talk, or keeps it.
- `/palaver camera` moves the view in on whoever speaks.
- `/palaver value` and `/palaver upgrades` turn the coin and the arrow on or off.
- `/palaver reset` puts the window back in its place, at its size.
- `/palaver errors` shows the last error, if one ever stopped a page.

## Other addons

These share Palaver's look and work independently:

- **[Hearthtale](https://www.curseforge.com/wow/addons/hearthtale)** ([Wago](https://addons.wago.io/addons/E6gzPnN1)) writes a diary for your character as you play, with an epitaph when a Hardcore life ends.
- **[Lorekeeper's Codex](https://www.curseforge.com/wow/addons/lorekeepers-codex)** ([Wago](https://addons.wago.io/addons/j6jAL0NR)) unlocks lore pages as you explore Azeroth and meet its people.
- **[Yonder](https://www.curseforge.com/wow/addons/yonder)** ([Wago](https://addons.wago.io/addons/ZKbq5y61)) offers exploration riddles, rare hunts, a bestiary, an atlas and records of your fish and herbs.
- **[Second Wind](https://www.curseforge.com/wow/addons/second-wind)** ([Wago](https://addons.wago.io/addons/XKqEjbKy)) gives you a debrief after a close call or death.

## Support

Palaver is free and will stay free. If it's made the quest text worth reading again, you can support the addon with a coffee on [Ko-fi](https://ko-fi.com/salty_max). Thank you.

## Source

MIT licensed: [github.com/salty-max/palaver](https://github.com/salty-max/palaver). The way Palaver talks to NPCs follows DialogueUI, by Peterodox and Raenore: thanks to them. Quest levels and chains come from QuestieDB (Wowhead for Forever's newest quests), and the quest kinds' names from the game's own tables. Thanks to their contributors. Not affiliated with Blizzard Entertainment.
