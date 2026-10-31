-- Palaver played through: an NPC's gossip, a quest offered, accepted, brought
-- back, handed in with a reward chosen, the rewards' marks, a vendor, the
-- keys, Escape, an error that hands the conversation to Blizzard, turning
-- Palaver off and on. Each
-- step as the game sends it (events, keys), each answer checked against the
-- game's calls. FOREVER=1, LOCALE=frFR: those clients.
local G = dofile("addon/test/game.lua")
local s, fire, ns = G.state, G.fire, G.ns
local P = ns.panel
local count = 0
local function check(ok, what)
  if not ok then error("✗ " .. what, 2) end
  count = count + 1
end
local function rows() return P.page and P.page.rows and #P.page.rows or 0 end
-- the window's title bar, and the quest's title beside the face (none: "")
local function bar() return PalaverFrame.titleText end
local function title() return PalaverFrame.title.shown and PalaverFrame.title:GetText() or "" end
local function words(tag) return _G[tag]:gsub("%s*[:：]%s*$", "") end
-- Space as a reader presses it: through a page longer than the panel to its
-- end (it reads on first), then once more to answer
local function yes()
  for _ = 1, 12 do
    local sc = PalaverScroll
    if not (P.shown() and ns.settings.readOn and sc:Range() - sc:GetVerticalScroll() >= 2) then break end
    G.key("SPACE")
    G.advance(0.3)
  end
  return G.key("SPACE")
end

local RAGNAR = {
  name = "Ragnar Thunderbrew",
  gossip = {
    text = "Ah, a thirsty traveller!",
    available = { { title = "Beer Basted Boar Ribs", questID = 384, isTrivial = false } },
    active = {},
    options = { { name = "Let me browse your goods." } },
  },
}
local RIBS = {
  id = 384,
  title = "Beer Basted Boar Ribs",
  text = "Nothing my tavern patrons enjoy more than some Beer Basted Boar Ribs!",
  objectives = "Ragnar Thunderbrew in Kharanos wants 6 Crag Boar Ribs and a mug of Rhapsody Malt.",
  progress = "I'm going to need six crag boar ribs and a mug of Rhapsody Malt, Gurdhil.",
  reward = "The Malt is brewed, the Boars are dead",
  given = {
    { name = "Beer Basted Boar Ribs", icon = 134004, count = 5 },
    { name = "Recipe: Beer Basted Boar Ribs", icon = 134939 },
  },
  required = { { name = "Crag Boar Rib", icon = 133972, count = 6 }, { name = "Rhapsody Malt", icon = 132800 } },
  money = 175,
  xp = 625,
}

-- ── login: Blizzard's windows muted, as they were registered ─────────────────
G.login()
check(ns.settings.enabled and ns.settings.font == 15, "the settings start with their defaults")
check(
  G.events(QuestFrame) == "" or G.events(QuestFrame) == "UNIT_PORTRAIT_UPDATE",
  "QuestFrame hears none of the conversation"
)
check(not QuestFrame:IsEventRegistered("QUEST_DETAIL"), "QuestFrame no longer opens on a quest")
local gossipOwner = G.FOREVER and CustomGossipFrameManager or GossipFrame
check(not gossipOwner:IsEventRegistered("GOSSIP_SHOW"), "the game's gossip window no longer opens")

-- ── the game's Options page: every setting, changed as /palaver changes it ──
local O = G.options
check(O.registered and O.name == "Palaver", "Palaver's page in the game's Options")
for _, key in ipairs({ "enabled", "keys", "camera", "value", "upgrades", "scale", "font" }) do
  local setting = O.settings["PALAVER_" .. key:upper()]
  check(setting and setting.get() == ns.settings[key], "the page shows " .. key)
end
O.settings.PALAVER_ENABLED.set(false)
check(QuestFrame:IsEventRegistered("QUEST_DETAIL"), "off on the page: the game's windows back, as /palaver off")
O.settings.PALAVER_ENABLED.set(true)
check(not QuestFrame:IsEventRegistered("QUEST_DETAIL"), "on again: muted again")
local scales = O.settings.PALAVER_SCALE.options()
check(#scales == 9 and scales[1].label == ns.kit.L["%d%%"]:format(70), "the panel's sizes, 70% to 150%")
SlashCmdList.PALAVER("scale 1.1")
check(
  s.printed[#s.printed]:find(ns.kit.L["Panel size %d%%."]:format(110), 1, true),
  "/palaver scale: the size in percent, as the page shows it"
)
SlashCmdList.PALAVER("scale 1")
check(
  s.printed[#s.printed]:find(ns.kit.L["Panel size %d%%."]:format(100), 1, true),
  "and a size without a decimal point on any client"
)
SlashCmdList.PALAVER("settings")
check(O.opened == 42, "/palaver settings opens the page")

-- ── a gossip: the NPC's words, a quest and an option as lines ────────────────
s.npc, s.quest, s.talking = RAGNAR, RIBS, true
fire("GOSSIP_SHOW")
check(P.shown() and bar() == "Ragnar Thunderbrew", "a gossip opens the window, the NPC's name in its title bar")
check(title() == "", "a gossip: no title beside the face, the name is in the bar")
check(
  PalaverFrame.template == "ButtonFrameTemplate" and PalaverFrame.parent == nil,
  "the family's window, outside the interface"
)
check(rows() == 2 and P.page.rows[1].text == "Beer Basted Boar Ribs", "the quest, then the option, as lines")
check(PalaverFrame.secondary.label:GetText() == words("GOODBYE"), "a gossip's button says the game's own Goodbye")
check(not PalaverFrame.primary.shown, "a gossip has no yes")
check(PalaverFrame.face == "npc", "the speaker's face in the window's corner")
G.forget()
PalaverFrame.CloseButton.scripts.OnClick(PalaverFrame.CloseButton)
check(not P.shown() and G.called("CloseGossip") == 1, "the window's close button: goodbye, as Escape")
fire("GOSSIP_SHOW")
local gossipHeight = PalaverFrame:GetHeight()

-- the quest picked with its key, then the game's close and the quest's page
G.forget()
check(G.key("1") == "palaver", "1 picks the first line, the game never hears it")
local n, c = G.called("SelectAvailableQuest")
check(n == 1 and c[2] == 384, "the quest picked by its id")
fire("GOSSIP_CLOSED", false)
G.advance(0.2)
check(P.shown(), "the gossip's close waits for what the answer brings")
fire("QUEST_DETAIL")
G.advance(1)
check(
  P.shown() and P.page.kind == "detail" and title() == "Beer Basted Boar Ribs",
  "the offer follows, the panel never gone"
)
check(bar() == "Ragnar Thunderbrew", "the title bar: who offers it")
check(PalaverFrame:GetHeight() == gossipHeight, "the offer as tall as the gossip: the buttons stay where they were")
check(G.called("CloseGossip") == 0 and G.called("CloseQuest") == 0, "no close sent while the conversation goes on")
check(PalaverFrame.primary.label:GetText() == words("ACCEPT"), "the offer's yes is the game's own Accept")
check(#P.page.rewards.given == 2 and P.page.rewards.money == 175 and P.page.rewards.xp == 625, "the rewards read")

-- a held Space never accepts the next page
G.forget()
G.key("SPACE", function() fire("QUEST_DETAIL") end)
check(G.called("AcceptQuest") == 0, "a key pressed on one page and released on the next does nothing")
check(yes() == "palaver" and G.called("AcceptQuest") == 1, "Space accepts")
fire("QUEST_FINISHED")
s.talking = false
G.advance(1)
check(not P.shown(), "the quest's close, the NPC done: the panel put away")
check(G.called("CloseQuest") == 0, "the game's close is not answered with another")

-- ── brought back unfinished, then finished ───────────────────────────────────
s.talking = true
fire("QUEST_PROGRESS")
check(P.page.kind == "progress" and PalaverFrame.primary.disabled, "unfinished: Continue is out of reach")
check(#P.page.required == 2, "what the quest asks to bring")
G.forget()
check(G.key("SPACE") == "game" and G.called("CompleteQuest") == 0, "Space with nothing to say goes to the game")
RIBS.completable = true
fire("QUEST_PROGRESS")
check(yes() == "palaver" and G.called("CompleteQuest") == 1, "finished: Space continues")

-- the hand-in: a reward to choose
RIBS.choice =
  { { name = "Dwarven Leather Boots", icon = 132542, quality = 2 }, { name = "Thick Cloak", icon = 133768 } }
fire("QUEST_COMPLETE")
G.advance(1)
check(P.page.kind == "complete" and P.choosing and PalaverFrame.hint.shown, "two rewards: the panel asks to choose")
check(PalaverFrame:GetHeight() == gossipHeight, "the hand-in too, its hint inside the same height")
G.forget()
yes()
check(G.called("GetQuestReward") == 0, "no reward chosen, no hand-in")
check(G.key("2") == "palaver" and P.choice == 2 and not PalaverFrame.hint.shown, "2 chooses the second reward")
yes()
local paid = G.FOREVER
n, c = G.called("GetQuestReward")
check(n == 1 and c[2] == 2, "Space hands it in with the reward chosen")

-- a turn-in that costs money: the game's own confirmation where the game asks
RIBS.cost = 500
fire("QUEST_COMPLETE")
G.key("1")
G.forget()
yes()
if paid then
  n, c = G.called("StaticPopup_Show")
  check(
    n == 1 and c[2] == "CONFIRM_COMPLETE_EXPENSIVE_QUEST" and c[3] == 1,
    "a paid turn-in asks the game's question, the reward chosen"
  )
  check(G.called("GetQuestReward") == 0, "and waits for its answer")
  check(G.key("ESCAPE") == "game", "Escape answers the game's question, not the conversation")
  StaticPopup1:Hide()
else
  check(G.called("GetQuestReward") == 1, "Classic Era hands a paid turn-in in at once, as its window does")
end
RIBS.cost, RIBS.choice = nil, nil

-- one reward: the choice is made
RIBS.choice = { { name = "Thick Cloak", icon = 133768 } }
fire("QUEST_COMPLETE")
G.forget()
yes()
n, c = G.called("GetQuestReward")
check(n == 1 and c[2] == 1, "one reward to choose is the one given")
RIBS.choice = nil
fire("QUEST_FINISHED")
fire("GOSSIP_SHOW")
G.advance(1)
check(P.shown() and P.page.kind == "gossip", "the gossip back after the hand-in, the panel never gone")

-- ── Escape ends a conversation as Blizzard's windows do ──────────────────────
G.forget()
check(G.key("ESCAPE") == "palaver" and G.called("CloseGossip") == 1 and not P.shown(), "Escape on a gossip: goodbye")
fire("QUEST_DETAIL")
G.forget()
G.key("ESCAPE")
check(G.called("CloseQuest") == 1 and not P.shown(), "Escape on a quest: the quest closed")
check(G.key("ESCAPE") == "game", "with the panel away, Escape is the game's")

-- ── a vendor: the panel steps aside, the NPC still spoken to ─────────────────
fire("GOSSIP_SHOW")
G.forget()
G.key("2")
n, c = G.called("SelectOptionByIndex")
check(n == 1 and c[2] == 0, "the option picked by its order (the game counts from 0)")
fire("GOSSIP_CLOSED", true)
fire("MERCHANT_SHOW")
G.advance(1)
check(not P.shown(), "the vendor's window: the panel away")
check(G.called("CloseGossip") == 0 and G.called("CloseQuest") == 0, "and the vendor never closed by it")

-- a gossip the game skips: one option marked to be chosen at once
s.npc = { name = "Thor", gossip = { text = "", options = { { name = "Show me where I can fly.", only = true } } } }
G.forget()
fire("GOSSIP_SHOW")
check(G.called("SelectOptionByIndex") == 1 and not P.shown(), "a lone option the game would skip: skipped")

-- a quest started from an item: the game accepts it, as its window lets it
G.forget()
fire("QUEST_DETAIL", 1307)
check(G.called("CloseQuest") == 1 and not P.shown(), "a quest from an item: the window closed, the quest the game's")

-- ── a greeting: several quests, no gossip ────────────────────────────────────
s.npc = {
  name = "Grelin Whitebeard",
  greeting = {
    text = "Coldridge Valley is crawling with troggs.",
    active = { { title = "The Troll Cave", isComplete = true } },
    available = { { title = "The Stolen Journal" }, { title = "Scalding Mornbrew Delivery", isTrivial = true } },
  },
}
fire("QUEST_GREETING")
check(
  P.page.kind == "greeting" and rows() == 3 and P.page.rows[1].icon == ns.game.QUEST_ICON.active,
  "a greeting: the quests as lines"
)
G.forget()
G.key("3")
n, c = G.called("SelectAvailableQuest#")
check(n == 1 and c[2] == 2, "the third line: the second quest offered")
fire("QUEST_FINISHED")
s.talking = false
G.advance(1)

-- ── the keys stay the game's when they should ────────────────────────────────
s.npc, s.talking = RAGNAR, true
fire("GOSSIP_SHOW")
s.typing = {}
check(G.key("1") == "game", "typing in a box: the keys are the box's")
s.typing = nil
s.modifier = true
check(G.key("1") == "game", "with a modifier held: the game's binding")
s.modifier = nil
fire("PLAYER_REGEN_DISABLED")
s.combat = true
check(G.key("1") == "game", "in combat: the game keeps the keyboard")
s.combat = false
fire("PLAYER_REGEN_ENABLED")
check(G.key("1") == "palaver", "out of combat: the keys answer again")
fire("QUEST_FINISHED")
s.talking = false
G.advance(1)

-- ── the language: the game's own words for the game's buttons ────────────────
s.talking = true
fire("QUEST_DETAIL")
check(PalaverFrame.primary.label:GetText() == words("ACCEPT"), "Accept in the client's language: " .. words("ACCEPT"))
check(PalaverFrame.primary.badge.text:GetText() == ns.kit.L["Space"], "the key's name in the language")
if G.LOCALE == "frFR" then check(ns.kit.L["Space"] == "Espace", "French: Espace") end
G.key("ESCAPE")

-- ── the rewards' marks: the best for the character, the best value ─────────
local L = ns.kit.L
local items = s.items
items["item:mh"] =
  { name = "Worn Shortsword", price = 7, slot = "INVTYPE_WEAPON", stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5 } }
items["item:legs0"] = {
  name = "Ragged Leggings",
  price = 5,
  slot = "INVTYPE_LEGS",
  stats = { RESISTANCE0_NAME = 50, ITEM_MOD_STAMINA_SHORT = 1 },
}
items["item:trousers"] = {
  name = "Rancher's Trousers",
  price = 162,
  slot = "INVTYPE_LEGS",
  stats = { RESISTANCE0_NAME = 60, ITEM_MOD_STAMINA_SHORT = 2 },
}
items["item:tunic"] = {
  name = "Soft Leather Tunic",
  price = 201,
  slot = "INVTYPE_CHEST",
  stats = { RESISTANCE0_NAME = 50, ITEM_MOD_AGILITY_SHORT = 1 },
}
items["item:hammer"] = {
  name = "Coldridge Hammer",
  price = 466,
  slot = "INVTYPE_2HWEAPON",
  stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 8, ITEM_MOD_STRENGTH_SHORT = 2 },
}
s.worn = { [16] = "item:mh", [7] = "item:legs0" }
local HERD = {
  id = 314,
  title = "Protecting the Herd",
  text = "Vagash has been killing our livestock.",
  objectives = "Kill Vagash and bring his fang to Rudra Amberstill.",
  reward = "Very well done!",
  completable = true,
  choice = {
    { name = "Rancher's Trousers", icon = 134582, link = "item:trousers" },
    { name = "Soft Leather Tunic", icon = 132719, link = "item:tunic" },
    { name = "Coldridge Hammer", icon = 133052, link = "item:hammer" },
  },
  xp = 450,
}
s.npc, s.quest, s.talking = { name = "Rudra Amberstill" }, HERD, true
-- (each choice's marks: the arrow, the coin)
local function marks()
  local out = {}
  for i = 1, #P.page.rewards.choice do
    local c = P.cards[i]
    out[i] = (c.best.shown and "^" or "") .. (c.value.shown and "$" or "")
  end
  return table.concat(out, "|")
end
local function tip(i)
  local c = P.cards[i]
  c.scripts.OnEnter(c)
  return table.concat(P.tooltip().lines, "\n")
end
fire("QUEST_COMPLETE")
check(marks() == "||^$", "a warrior: the hammer the best for them, and it sells for most")
check(not P.choice, "the marks choose nothing: the choice stays the player's")
check(tip(3):find("Worn Shortsword", 1, true), "the arrow says what it beats")
check(
  tip(3):find(L["Best value: it sells for %s, more than the other rewards."]:format(ns.game.coins(466)), 1, true),
  "the coin says what it sells for"
)
check(tip(1) == "", "an unmarked reward: the game's tooltip alone")
fire("QUEST_DETAIL")
check(marks() == "||^$", "the offer shows the marks too")

HERD.choice[3].usable = false
fire("QUEST_COMPLETE")
check(marks() == "|^|$", "a hammer they can't use: the tunic for an empty chest, the coin still on the hammer")
check(P.cards[3].slot.icon.color[2] == 0, "and the hammer red, as the game's window shows it")
check(tip(2):find(L["An upgrade over an empty slot, by the stats your class wants."], 1, true), "the empty slot said")
HERD.choice[3].usable = nil

-- a two-hand weapon against both hands held: no one item to name
items["item:oh"] = { name = "Worn Buckler", price = 3, slot = "INVTYPE_SHIELD", stats = { ITEM_MOD_STAMINA_SHORT = 1 } }
s.worn[17] = "item:oh"
fire("QUEST_COMPLETE")
check(
  tip(3):find(L["An upgrade over the two items in your hands, by the stats your class wants."], 1, true),
  "a hammer for both hands: the two items in your hands, no one item named"
)
s.worn[17] = nil
fire("QUEST_COMPLETE")

-- a title among the rewards: it reaches the page, the game's label after it
GetRewardTitle = function() return "the Brave" end
fire("QUEST_COMPLETE")
check(P.page.rewards.title == "the Brave", "a title reward is on the page")
GetRewardTitle = nil
fire("QUEST_COMPLETE")

items["item:hammer"].pending = true
fire("QUEST_COMPLETE")
check(marks() == "||" and P.waiting, "an item the game has yet to tell: no marks, waiting")
items["item:hammer"].pending = nil
fire("GET_ITEM_INFO_RECEIVED", 0)
check(marks() == "||^$" and not P.waiting, "told at last: the marks come")

items["item:tunic"].price = 466
fire("QUEST_COMPLETE")
check(marks() == "||^", "two at the top price: no coin")
items["item:tunic"].price = 201

SlashCmdList.PALAVER("value")
check(not ns.settings.value and marks() == "||^", "/palaver value: the coin off at once")
SlashCmdList.PALAVER("upgrades")
check(not ns.settings.upgrades and marks() == "||", "/palaver upgrades: the arrow off")
SlashCmdList.PALAVER("value")
SlashCmdList.PALAVER("upgrades")
check(marks() == "||^$", "both on again")
O.settings.PALAVER_VALUE.set(false)
check(marks() == "||^", "the coin off from the Options page, at once")
O.settings.PALAVER_VALUE.set(true)
check(marks() == "||^$", "and back")

-- a rogue's second hand: an empty off hand only where it fights with two
items["item:dagger"] =
  { name = "Rogue's Dagger", price = 9, slot = "INVTYPE_WEAPON", stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 6 } }
items["item:dirk"] =
  { name = "Keen Dirk", price = 50, slot = "INVTYPE_WEAPON", stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5 } }
s.class, s.worn = "ROGUE", { [16] = "item:dagger", [7] = "item:legs0" }
HERD.choice = { { name = "Keen Dirk", icon = 135641, link = "item:dirk" }, HERD.choice[1] }
fire("QUEST_COMPLETE")
check(marks() == "|^$", "one hand: a weaker dagger is no upgrade")
s.dualWield = true
fire("PLAYER_EQUIPMENT_CHANGED")
check(marks() == "^|$", "two hands: the dirk for the empty off hand, worked out again")
s.dualWield = nil

-- a hybrid by its tree: a paladin levels as Retribution until a tree holds most points
items["item:intlegs"] = {
  name = "Acolyte's Pants",
  price = 30,
  slot = "INVTYPE_LEGS",
  stats = { RESISTANCE0_NAME = 20, ITEM_MOD_INTELLECT_SHORT = 4 },
}
items["item:strlegs"] = {
  name = "Militia Leggings",
  price = 40,
  slot = "INVTYPE_LEGS",
  stats = { RESISTANCE0_NAME = 60, ITEM_MOD_STRENGTH_SHORT = 3 },
}
s.class, s.worn = "PALADIN", { [7] = "item:legs0" }
HERD.choice = {
  { name = "Acolyte's Pants", icon = 134588, link = "item:intlegs" },
  { name = "Militia Leggings", icon = 134582, link = "item:strlegs" },
}
fire("QUEST_COMPLETE")
check(marks() == "|^$", "a paladin with no tree yet: strength, as Retribution levels")
s.talents = { 11, 0, 0 }
fire("QUEST_COMPLETE")
check(marks() == "^|$", "eleven points in Holy: intellect")
s.talents = { 5, 3, 4 }
fire("QUEST_COMPLETE")
check(marks() == "|^$", "a few points here and there: still Retribution")
s.talents = { 0, 0, 0 }

-- no other addon asked: Pawn loaded and saying otherwise changes nothing
s.class, s.worn = "WARRIOR", { [16] = "item:mh", [7] = "item:legs0" }
HERD.choice = {
  { name = "Rancher's Trousers", icon = 134582, link = "item:trousers" },
  { name = "Soft Leather Tunic", icon = 132719, link = "item:tunic" },
  { name = "Coldridge Hammer", icon = 133052, link = "item:hammer" },
}
local asked = false
function PawnIsReady()
  asked = true
  return true
end
function PawnGetItemData(link)
  asked = true
  return { Link = link }
end
function PawnIsItemAnUpgrade()
  asked = true
  return { { ScaleName = "a", LocalizedScaleName = "Arms", PercentUpgrade = 0.5 } }
end
fire("QUEST_COMPLETE")
check(marks() == "||^$" and not asked, "Pawn loaded: Palaver's own rule, Pawn never asked")
PawnIsReady, PawnGetItemData, PawnIsItemAnUpgrade = nil, nil, nil

-- a mark that fails: kept for /palaver errors, the page kept, Palaver kept
local real = ns.rewards.bestValue
ns.rewards.bestValue = function() error("a broken price") end
fire("QUEST_COMPLETE")
check(P.shown() and P.page.kind == "complete" and marks() == "||", "a failing mark: the page without marks")
check(PalaverErrors[1].event == "marks", "the error kept")
check(not QuestFrame:IsEventRegistered("QUEST_DETAIL"), "and Palaver still the one talking")
ns.rewards.bestValue = real
PalaverErrors = nil
G.key("ESCAPE")
s.worn = {}

-- ── the camera: DialogueUI's moves, on by default as DialogueUI's ──────────
s.npc, s.quest, s.talking = RAGNAR, RIBS, true
check(ns.settings.camera, "the camera on by default")
SlashCmdList.PALAVER("camera")
check(not ns.settings.camera, "/palaver camera turns it off")
fire("GOSSIP_SHOW")
check(not ns.camera.active() and s.zoom == 15, "off: the view stays as it was")
G.key("ESCAPE")
SlashCmdList.PALAVER("camera")
check(ns.settings.camera, "and on again")
local function restored()
  for k, v in pairs(G.cvarsAtStart) do
    if s.cvars[k] ~= v then return false end
  end
  return s.zoom == 15 and s.pitchlimit == 88 and ns.settings.cameraBackup == nil
end
local function near(a, b) return math.abs(tonumber(a) - b) < 1e-3 end
s.npcHeight = 1.7 -- (a dwarf)
fire("GOSSIP_SHOW")
check(ns.camera.active(), "a conversation moves the camera")
check(
  s.cvars.test_cameraTargetFocusInteractEnable == "1" and s.cvars.test_cameraOverShoulder == "1.5",
  "the game's focus on the speaker, the view over the shoulder"
)
check(s.zoom == 2, "a dwarf, 1.7 tall: two yards")
local b = ns.settings.cameraBackup
check(b and b.cvars.test_cameraOverShoulder == "0" and b.zoom == 15, "what it changes, saved as it changes it")
check(b.cvars.cameraFov == "90", "the field of view kept before the tilt narrows it")
check((s.warnings or 0) == 0, "the game's experimental-settings warning kept quiet")
G.advance(0.5)
local k = math.sin(math.pi / 4)
check(
  near(s.pitchlimit, 88 - 73 * k) and near(s.cvars.cameraFov, 90 - 15 * k),
  "half way: the pitch limit and the field of view eased, not in whole steps"
)
G.advance(0.7)
check(
  s.pitchlimit == 88 and s.cvars.test_cameraTargetFocusInteractStrengthPitch == "1" and s.cvars.cameraFov == "75",
  "the tilt done: the pitch limit released, the field of view at 75"
)
G.key("1")
fire("GOSSIP_CLOSED", false)
fire("QUEST_DETAIL")
G.advance(1)
check(ns.camera.active() and s.zoom == 2, "the next page keeps the camera where it is")
G.key("ESCAPE")
check(
  not ns.camera.active() and restored(),
  "the conversation over: every setting, the field of view, the pitch limit and the zoom as they were"
)
check((s.warnings or 0) == 0, "nor when every setting goes back")
if G.FOREVER then
  check(not G.internal.EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED, "Forever: the warning let go for the session")
else
  check(UIParent:IsEventRegistered("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED"), "the warning heard again")
end

-- (a fight: the camera stays, as DialogueUI's does)
fire("GOSSIP_SHOW")
fire("PLAYER_REGEN_DISABLED")
s.combat = true
check(ns.camera.active() and s.cvars.test_cameraTargetFocusInteractEnable == "1", "a fight: the camera stays")
s.combat = false
fire("PLAYER_REGEN_ENABLED")
G.key("ESCAPE")
check(restored(), "and goes back when the conversation ends")
s.combat = true
fire("GOSSIP_SHOW")
check(ns.camera.active(), "a conversation begun in a fight: the camera moves all the same")
s.combat = false
fire("PLAYER_REGEN_ENABLED")
G.key("ESCAPE")

-- (no one to look at: the view slides aside, three yards out)
s.npcIsPlayer = true
fire("QUEST_DETAIL")
check(ns.camera.active() and s.zoom == 3, "a quest from an item: the camera comes to three yards")
check(
  s.cvars.test_cameraTargetFocusInteractEnable == "0" and s.cvars.cameraFov == "90",
  "no focus and the field of view as it was: no one to look at"
)
G.advance(1)
check(near(s.cvars.test_cameraOverShoulder, 3 * 0.4314 + 0.1057), "the view slid aside by how far out it is")
G.key("ESCAPE")
check(not ns.camera.active() and restored(), "and back when it ends")
s.npcIsPlayer = nil
local secrets = C_Secrets
C_Secrets = { ShouldUnitIdentityBeSecret = function() return true end }
fire("GOSSIP_SHOW")
check(s.zoom == 4, "an NPC the game won't let be measured: four yards")
G.key("ESCAPE")
C_Secrets = secrets

-- (the NPC's model: waited for, however long)
s.npcHeight = nil
fire("GOSSIP_SHOW")
G.advance(2)
check(s.zoom == 15, "a model slow to load: the camera waits for it")
s.npcHeight = 2.1
G.actor:OnModelLoaded()
check(s.zoom == 3, "however long it takes: a human, 2.1 tall, three yards")
G.key("ESCAPE")
s.npcHeight = nil
fire("GOSSIP_SHOW")
G.actor:OnModelLoaded()
check(s.zoom == 15, "a model without a size: the zoom left as it is")
G.key("ESCAPE")
s.npcHeight = nil
fire("GOSSIP_SHOW")
G.key("ESCAPE")
s.npcHeight = 7.7
G.actor:OnModelLoaded()
check(s.zoom == 15, "a model that loads after its conversation: the camera left alone")
fire("GOSSIP_SHOW")
check(s.zoom == 10, "an NPC 7.7 tall: ten yards")
G.key("ESCAPE")
s.npcHeight, s.zoom = 1.7, 1.5
fire("GOSSIP_SHOW")
check(s.zoom == 1.5, "already closer than it would go: the camera never zooms out")
G.key("ESCAPE")

-- (a mount, a druid's form, the panel's side)
s.zoom, s.mounted = 15, true
fire("GOSSIP_SHOW")
check(near(s.cvars.test_cameraOverShoulder, 7.2), "mounted: the shoulder times 4.8, the mount between")
if G.FOREVER then
  check(s.cvars.cameraFov == "90", "Forever on a mount: the field of view left alone")
else
  G.advance(1.2)
  check(s.cvars.cameraFov == "75", "on a mount: the field of view narrows all the same")
end
s.mounted = nil
fire("PLAYER_MOUNT_DISPLAY_CHANGED")
check(s.cvars.test_cameraOverShoulder == "1.5", "off the mount mid-conversation: back over the shoulder")
fire("PLAYER_LOGOUT")
check(restored(), "a logout mid-conversation: the camera back before the game saves its settings")
G.key("ESCAPE")
if G.FOREVER then
  fire("GOSSIP_SHOW")
  G.advance(0.5)
  s.mounted = true
  fire("PLAYER_MOUNT_DISPLAY_CHANGED")
  G.advance(1)
  check(
    s.cvars.cameraFov == "90" and near(s.cvars.test_cameraOverShoulder, 7.2),
    "Forever, mounted mid-conversation: the field of view back, the shoulder further"
  )
  s.mounted = nil
  G.key("ESCAPE")
  check(restored(), "and all back when it ends")
end
local class = s.class
s.class, s.form = "DRUID", 1
fire("GOSSIP_SHOW")
check(s.cvars.test_cameraOverShoulder == "1", "a druid in cat form: the cat's shoulder")
s.form = 5
fire("UPDATE_SHAPESHIFT_FORM")
G.advance(0)
check(s.cvars.test_cameraOverShoulder == "0.9", "into bear form mid-conversation: the bear's")
G.key("ESCAPE")
s.class, s.form = class, nil
PalaverFrame.cx = 300 -- (dragged to the left of the screen)
fire("GOSSIP_SHOW")
check(s.cvars.test_cameraOverShoulder == "-1.5", "a panel on the left: over the other shoulder")
PalaverFrame.cx = 1000
PalaverFrame:GetScript("OnDragStop")(PalaverFrame)
check(s.cvars.test_cameraOverShoulder == "1.5", "dragged back to the right mid-conversation: the right shoulder")
G.key("ESCAPE")
PalaverFrame.cx, ns.settings.point = nil, nil
fire("GOSSIP_SHOW")
fire("PLAYER_CAMPING")
check(not ns.camera.active() and restored(), "a camp's countdown: the camera back")
G.key("ESCAPE")
-- (a camera that fails: put back, still for the session, the error kept once;
-- the conversation keeps its keys and its hidden interface)
local unitClass = UnitClass
UnitClass = function() error("a broken call") end
fire("GOSSIP_SHOW")
G.advance(0.5)
check(not ns.camera.active() and restored(), "a failing camera: put back at once")
check(not UIParent.shown and PalaverErrors[1].event == "camera", "the interface hidden all the same, the error kept")
check(G.key("ESCAPE") == "palaver" and not P.shown(), "and Escape still ends the conversation")
UnitClass = unitClass
fire("GOSSIP_SHOW")
check(not ns.camera.active() and #PalaverErrors == 1, "never tried again this session: one error kept, not one a page")
G.key("ESCAPE")
PalaverErrors = nil

-- ── reading on: Space through a long page before it answers ────────────────
local LONG = {
  id = 99999,
  title = "A Long Tale",
  text = string.rep("The road east was long and the night was cold. ", 60),
  objectives = "Listen.",
}
s.npc, s.quest, s.talking = RAGNAR, LONG, true
fire("QUEST_DETAIL")
G.forget()
check(G.key("SPACE") == "palaver" and G.called("AcceptQuest") == 0, "a long offer: Space reads on, no answer yet")
G.advance(0.3)
check(PalaverScroll:GetVerticalScroll() > 0, "the text moved down")
check(yes() == "palaver" and G.called("AcceptQuest") == 1, "read to its end, Space accepts")
fire("QUEST_DETAIL")
G.forget()
PalaverFrame.primary.scripts.OnClick(PalaverFrame.primary)
check(G.called("AcceptQuest") == 1, "a click on Accept answers at once")
fire("QUEST_DETAIL")
O.settings.PALAVER_READON.set(false)
G.forget()
G.key("SPACE")
check(G.called("AcceptQuest") == 1, "reading on turned off: Space answers at once")
O.settings.PALAVER_READON.set(true)
G.key("ESCAPE")
check(not P.factsLine and P.page == nil, "a quest the data doesn't know: no facts")

-- ── a quest's facts on its offer page ────────────────────────────────────────
local function fact(id, group)
  s.quest = { id = id, title = "Quest " .. id, text = "Words.", objectives = "Do it.", group = group }
  fire("QUEST_DETAIL")
  return P.factsLine or ""
end
local level = function(n) return ns.game.word("UNIT_LEVEL_TEMPLATE", "Level %d"):format(n) end
local line = fact(132)
check(line:find(level(18), 1, true), "the Defias Brotherhood's second part: level 18")
check(line:find(L["Part %d of %d"]:format(2, 7), 1, true), "and part 2 of 7, by the game's own chain")
line = fact(166)
check(
  line:find(ns.questTypes[81], 1, true) and line:find(L["Part %d of %d"]:format(7, 7), 1, true),
  "its end: a dungeon, part 7 of 7"
)
check(ns.questTypes[81] == (G.LOCALE == "frFR" and "Donjon" or "Dungeon"), "the kind in the game's own word")
line = fact(314, 3)
check(line:find(ns.questTypes[1], 1, true), "Protecting the Herd: elite")
check(line:find(ns.game.word("QUEST_SUGGESTED_GROUP_NUM", "x"):format(3), 1, true), "the group the game suggests")
check(not line:find(L["Part %d of %d"]:format(1, 1), 1, true), "no chain: no part")
fact(99999)
check(not P.factsLine, "nothing known: no line")
s.quest = { id = 132, title = "The Defias Brotherhood", progress = "Back so soon?", required = {} }
fire("QUEST_PROGRESS")
check(not P.factsLine, "the offer only: not on its return")
G.key("ESCAPE")

-- ── books, letters and plaques in the panel ──────────────────────────────────
s.npc, s.talking = nil, false
check(not ItemTextFrame:IsEventRegistered("ITEM_TEXT_READY"), "the game's book window muted")
s.book = {
  title = "The Story of Morgan Ladimore",
  pages = {
    "Morgan Ladimore was a hero of the Second War.",
    "<HTML><BODY><H1>Chapter</H1><P>Two &amp; more<BR/>lines</P></BODY></HTML>",
    "The end.",
  },
  page = 1,
}
fire("ITEM_TEXT_BEGIN")
check(not P.shown(), "the book's start: its page follows")
fire("ITEM_TEXT_READY")
check(
  P.shown() and P.page.kind == "book" and bar() == "The Story of Morgan Ladimore",
  "a book opens, its name in the bar"
)
check(PalaverFrame.face == "Interface\\QuestFrame\\UI-QuestLog-BookIcon", "the book's face in the corner")
check(
  PalaverFrame.kicker.shown and PalaverFrame.kicker:GetText() == ns.game.word("PAGE_NUMBER", "x"):format(1),
  "its page number beside it"
)
check(
  PalaverFrame.primary.label:GetText() == words("NEXT") and PalaverFrame.secondary.label:GetText() == words("CLOSE"),
  "the game's Next and Close"
)
check(not PalaverFrame.back.shown, "the first page: no way back")
check(not ns.camera.active(), "a book: the camera stays")
G.forget()
yes()
check(G.called("ItemTextNextPage") == 1, "Space turns the page")
s.book.page = 2
fire("ITEM_TEXT_READY")
check(P.page.text == "Chapter\n\nTwo & more\nlines", "a page in HTML read as plain text")
check(PalaverFrame.back.shown, "a page back")
G.forget()
check(G.key("BACKSPACE") == "palaver" and G.called("ItemTextPrevPage") == 1, "Backspace turns back")
s.book.page = 3
fire("ITEM_TEXT_READY")
check(
  PalaverFrame.primary.label:GetText() == words("CLOSE") and not PalaverFrame.secondary.shown,
  "the last page: Space closes"
)
G.forget()
yes()
check(G.called("CloseItemText") == 1, "the book closed")
fire("ITEM_TEXT_CLOSED")
check(not P.shown(), "the game's close: the panel away")
s.book = { title = "A Letter", pages = { "Meet me at the inn." }, page = 1, creator = "Thrall" }
fire("ITEM_TEXT_READY")
check(P.page.text:find(words("ITEM_TEXT_FROM") .. "\nThrall", 1, true), "a letter says who wrote it")
check(not PalaverFrame.kicker.shown, "one page: no page number")
G.forget()
G.key("ESCAPE")
check(G.called("CloseItemText") == 1 and not P.shown(), "Escape closes a book")
fire("ITEM_TEXT_CLOSED")
fire("ITEM_TEXT_TRANSLATION", 3)
check(P.shown() and P.page.text == L["Translating..."], "a text the game translates: a word while it does")
fire("ITEM_TEXT_READY")
check(P.page.text:find("Meet me at the inn.", 1, true) == 1, "then its page")
fire("ITEM_TEXT_CLOSED")
O.settings.PALAVER_BOOKS.set(false)
check(ItemTextFrame:IsEventRegistered("ITEM_TEXT_READY"), "books off: the game's book window back")
check(not QuestFrame:IsEventRegistered("QUEST_DETAIL"), "the conversations still Palaver's")
G.forget()
fire("ITEM_TEXT_READY")
check(not P.shown() and G.called("ItemTextFrame") == 1, "a book read by the game's window, Palaver out of it")
O.settings.PALAVER_BOOKS.set(true)
check(not ItemTextFrame:IsEventRegistered("ITEM_TEXT_READY"), "books on again")
s.book = nil

-- ── the game's interface hidden while talking ────────────────────────────────
s.npc, s.quest, s.talking = RAGNAR, RIBS, true
check(ns.settings.hideUI, "the interface hidden by default")
check(PalaverFrame.parent == nil and PalaverKeys.parent == nil, "the panel and its keys outside the game's interface")
G.forget()
fire("GOSSIP_SHOW")
G.advance(0.1)
check(UIParent.shown and UIParent:GetAlpha() < 1, "talking: the interface fades")
G.advance(0.3)
check(not UIParent.shown and UIParent:GetAlpha() == 1 and P.shown(), "then it is hidden, the panel stays")
check(P.tooltip() == PalaverTooltip, "a card's tooltip Palaver's own, the game's hidden with the interface")
G.key("1")
fire("GOSSIP_CLOSED", true)
check(not UIParent.shown, "a quest picked, the interaction going on: hidden still, the quest comes to the panel")
fire("QUEST_DETAIL")
G.advance(0.5)
check(not UIParent.shown and P.page.kind == "detail", "its offer, the interface away throughout")
fire("GOSSIP_SHOW")
check(G.key("2") == "palaver", "the keys still answer")
G.forget()
fire("GOSSIP_CLOSED", true)
check(UIParent.shown and G.called("CloseAllWindows") == 1, "a vendor's coming: the interface back first")
fire("MERCHANT_SHOW")
check(not P.shown() and G.called("CloseAllWindows") == 1, "so its coming back never closes the vendor's window")
fire("GOSSIP_SHOW")
G.advance(0.5)
G.key("ESCAPE")
check(UIParent.shown, "the conversation over: the interface back")
G.advance(0.3)
check(UIParent:GetAlpha() == 1, "faded in")
fire("GOSSIP_SHOW")
G.advance(0.5)
fire("PLAYER_REGEN_DISABLED")
check(UIParent.shown and UIParent:GetAlpha() == 1, "a fight: the interface back at once")
fire("PLAYER_REGEN_ENABLED")
G.key("ESCAPE")
fire("GOSSIP_SHOW")
G.advance(0.5)
StaticPopup_Show("CONFIRM_BINDER")
check(UIParent.shown, "a question of the game's: the interface back to ask it")
StaticPopup1:Hide()
G.key("ESCAPE")
fire("GOSSIP_SHOW")
G.advance(0.5)
O.settings.PALAVER_HIDEUI.set(false)
check(UIParent.shown, "the setting off: the interface back")
O.settings.PALAVER_HIDEUI.set(true)
check(ns.hud.hidden(), "on again mid-conversation: hidden again")
G.advance(0.5)
check(not UIParent.shown, "once faded")
G.key("ESCAPE")
G.advance(0.5)
UIParent.shown = false -- (the player's own Alt+Z)
G.forget()
fire("GOSSIP_SHOW")
G.advance(0.5)
G.key("ESCAPE")
check(G.called("SetUIVisibility") == 0 and not UIParent.shown, "an interface the player hid: left as they left it")
UIParent.shown = true
s.combat = true
fire("GOSSIP_SHOW")
G.advance(0.5)
check(UIParent.shown, "in combat: never touched")
s.combat = false
G.key("ESCAPE")

-- ── an error: the conversation handed to Blizzard's window ───────────────────
RIBS.broken = true
s.npc, s.quest, s.talking = RAGNAR, RIBS, true
fire("GOSSIP_SHOW")
G.advance(0.5)
G.forget()
fire("QUEST_DETAIL")
check(not P.shown(), "a page that fails is not shown")
check(UIParent.shown, "and the game's interface is back")
check(G.called("QuestFrame") == 1, "the game's own window gets it")
check(QuestFrame:IsEventRegistered("QUEST_DETAIL"), "and the game's windows hear the conversations again")
check(PalaverErrors and PalaverErrors[1].event == "QUEST_DETAIL", "the error kept for /palaver errors")
check(s.printed[#s.printed]:find("/palaver errors", 1, true), "said once in chat")
G.forget()
fire("QUEST_DETAIL")
check(not P.shown() and G.called("QuestFrame") == 1, "Palaver keeps out of the rest of the session")
RIBS.broken = nil

-- ── off and on: Blizzard's registrations restored exactly ────────────────────
local G2 = dofile("addon/test/game.lua")
G2.login()
local native = G2.native[QuestFrame]
SlashCmdList.PALAVER("off")
check(G2.events(QuestFrame) == native, "off: QuestFrame's events as the client registered them")
check(G2.events(GossipFrame) == G2.native[GossipFrame], "off: GossipFrame's as well")
check(G2.events(ItemTextFrame) == G2.native[ItemTextFrame], "off: the book window's as well")
if G2.FOREVER then
  check(
    G2.events(CustomGossipFrameManager) == G2.native[CustomGossipFrameManager],
    "off: Forever's gossip manager's as well"
  )
end
SlashCmdList.PALAVER("on")
check(not QuestFrame:IsEventRegistered("QUEST_DETAIL"), "on: muted again")

-- another addon showing conversations: Palaver stays out of its way
local G3 = dofile("addon/test/game.lua")
G3.login({ DialogueUI = true })
check(QuestFrame:IsEventRegistered("QUEST_DETAIL"), "DialogueUI loaded: Blizzard's windows left as they are")
check(G3.state.printed[1] and G3.state.printed[1]:find("DialogueUI", 1, true), "and said once")
local printed = #G3.state.printed
SlashCmdList.PALAVER("on")
check(
  G3.state.printed[printed + 1] and G3.state.printed[printed + 1]:find("DialogueUI", 1, true),
  "/palaver on with DialogueUI loaded: the line says Palaver stays out"
)
check(
  not G3.state.printed[printed + 1]:find(L["On: your conversations are shown in Palaver's panel."], 1, true),
  "and never says On"
)
check(QuestFrame:IsEventRegistered("QUEST_DETAIL"), "and the game's windows stay as they are")

-- a crash mid-conversation: nothing restored then, the next login does it
-- (what a conversation's camera changes, on a fresh game)
local G5 = dofile("addon/test/game.lua")
PalaverSettings = nil -- (a new player's saved file)
G5.login()
G5.state.npc, G5.state.quest, G5.state.talking, G5.state.npcHeight = RAGNAR, RIBS, true, 1.7
G5.fire("GOSSIP_SHOW")
local keep = {}
for k, v in pairs(PalaverSettings.cameraBackup.cvars) do
  keep[k] = v
end
local changed = G5.state.cvars.test_cameraOverShoulder
local G4 = dofile("addon/test/game.lua")
for k in pairs(keep) do
  G4.state.cvars[k] = k == "test_cameraOverShoulder" and changed or "9"
end
PalaverSettings = { camera = true, cameraBackup = { cvars = keep, zoom = 3, pitch = true } }
G4.login()
local back = true
for k, v in pairs(keep) do
  if G4.state.cvars[k] ~= v then back = false end
end
check(back and PalaverSettings.cameraBackup == nil, "the next login puts back what a crash left changed")
check(G4.state.zoom == 15, "but not the old session's zoom, which was the session's own")
check((G4.state.warnings or 0) == 0, "and no experimental-settings warning at that login")

-- settings saved before the interface hid and the camera moved by default:
-- on, once
local G6 = dofile("addon/test/game.lua")
PalaverSettings = { enabled = true, hideUI = false }
G6.login()
check(
  PalaverSettings.hideUI == true and PalaverSettings.camera == true and PalaverSettings.version == 3,
  "an older saved file: the interface hidden and the camera on, as the new defaults"
)
local G7 = dofile("addon/test/game.lua")
PalaverSettings = { enabled = true, hideUI = false, camera = false, version = 2 }
G7.login()
check(PalaverSettings.hideUI == false, "the interface shown since: left shown")
check(
  PalaverSettings.camera == true and PalaverSettings.version == 3,
  "a saved file of before the camera's default: on, once"
)
local G8 = dofile("addon/test/game.lua")
PalaverSettings = { enabled = true, camera = false, version = 3 }
G8.login()
check(PalaverSettings.camera == false, "turned off since: left off")

io.write(("Palaver: %d checks passed (%s, %s).\n"):format(count, G.LOCALE, G.FOREVER and "Forever" or "Classic Era"))
