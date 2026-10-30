# Palaver

Quests and conversations with NPCs in a panel beside them, read and answered
from the keyboard, in the look of Hearthtale, Lorekeeper's Codex, Yonder and
Second Wind.

One download for Classic Era and World of Warcraft: Forever.

## Using it

Talk to an NPC: their words, their quests and their options open in the
family's window, the NPC's face in its corner and the NPC still in view.

- **Space** (or Enter) answers yes: Accept, Continue, Complete Quest.
- **Escape** says goodbye.
- **1 to 9** pick a line, or the reward to take when a quest offers a choice.

A key acts when you let it go, and only on the page you pressed it on: a
held Space never accepts the next quest. On a page longer than the panel,
Space first scrolls down, so you never accept a quest with its rewards
unseen. In combat, while typing or with a modifier held, the keys stay the
game's. Drag the panel to move it.

A quest's offer shows what the game's own window keeps quiet: its level in
the colour of how hard it is for you, whether it's elite or a dungeon, and
where it sits in its chain, like part 2 of 7.

Books, letters and plaques open in the same panel. Space turns the page,
Backspace turns back.

While you talk or read, the game's interface fades away, so only the window
and the one you speak to stay on screen. It comes back for a fight, a vendor
or a question of the game's. /palaver hud or the Options keep it on screen.

When a quest offers a choice of rewards, two marks help you pick. A green
arrow sits on the one best for your character, and a gold coin on the one
that sells for most. Hover a marked reward to see why. The arrow weighs the
stats your class wants against what you wear, and Palaver needs no other
addon for it. The marks never choose for you.

Every setting is also on Palaver's page in the game's Options, under AddOns.

```text
/palaver on | off        Palaver's panel, or the game's own windows
/palaver scale 1.1       its size, 0.7 to 1.5
/palaver font 16         its text, 12 to 22
/palaver keys            the keys on or off
/palaver books           books and letters in Palaver, or the game's window
/palaver hud             the game's interface hidden while you talk, or kept
/palaver camera          the view moves in on whoever speaks, or stays still
/palaver value           the coin on the reward that sells for most
/palaver upgrades        the arrow on the reward best for you
/palaver reset           back in its place, at its size
/palaver errors          the last error, if one ever stopped a page
/palaver settings        Palaver's page in the game's Options
```

If DialogueUI, Immersion or Storyline is installed, Palaver stays out of its
way and says so.

## Languages

The NPCs' words, the quests and the game's buttons are the game's own, in
your client's language. Palaver's few words of its own speak English, French,
German and Spanish (German and Spanish are first translations).

## Thanks

Palaver's way of talking to NPCs follows DialogueUI, by Peterodox and
Raenore. Quest levels and chains come from QuestieDB (Wowhead for Forever's
newest quests), the quest kinds' names from the game's own tables.

## Building

```bash
bun run check     # everything a commit needs
bun run package   # a test zip in dist/
```

The quest facts come from [wow-data](https://github.com/salty-max/wow-data),
beside this folder.

## License

MIT.
