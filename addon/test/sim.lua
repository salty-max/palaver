-- Palaver played through: an NPC's gossip, a quest offered, accepted, brought
-- back, handed in with a reward chosen, a vendor, the keys, Escape, an error
-- that hands the conversation to Blizzard, turning Palaver off and on. Each
-- step as the game sends it (events, keys), each answer checked against the
-- game's calls. FOREVER=1, TBC=1, LOCALE=frFR: those clients.
local G = dofile("addon/test/game.lua")
local s, fire, ns = G.state, G.fire, G.ns
local P = ns.panel
local count = 0
local function check(ok, what)
  if not ok then error("✗ " .. what, 2) end
  count = count + 1
end
local function rows() return P.page and P.page.rows and #P.page.rows or 0 end
local function title() return PalaverFrame.title:GetText() end
local function words(tag) return _G[tag]:gsub("%s*[:：]%s*$", "") end

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

-- ── a gossip: the NPC's words, a quest and an option as lines ────────────────
s.npc, s.quest, s.talking = RAGNAR, RIBS, true
fire("GOSSIP_SHOW")
check(P.shown() and title() == "Ragnar Thunderbrew", "a gossip opens the panel, the NPC's name its title")
check(rows() == 2 and P.page.rows[1].text == "Beer Basted Boar Ribs", "the quest, then the option, as lines")
check(PalaverFrame.secondary.label:GetText() == words("GOODBYE"), "a gossip's button says the game's own Goodbye")
check(not PalaverFrame.primary.shown, "a gossip has no yes")
check(PalaverFrame.portrait.tex.portrait == "npc", "the speaker's face in the ring")

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
check(PalaverFrame.sub:GetText() == "Ragnar Thunderbrew", "the offer's subtitle: who offers it")
check(G.called("CloseGossip") == 0 and G.called("CloseQuest") == 0, "no close sent while the conversation goes on")
check(PalaverFrame.primary.label:GetText() == words("ACCEPT"), "the offer's yes is the game's own Accept")
check(#P.page.rewards.given == 2 and P.page.rewards.money == 175 and P.page.rewards.xp == 625, "the rewards read")

-- a held Space never accepts the next page
G.forget()
G.key("SPACE", function() fire("QUEST_DETAIL") end)
check(G.called("AcceptQuest") == 0, "a key pressed on one page and released on the next does nothing")
check(G.key("SPACE") == "palaver" and G.called("AcceptQuest") == 1, "Space accepts")
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
check(G.key("SPACE") == "palaver" and G.called("CompleteQuest") == 1, "finished: Space continues")

-- the hand-in: a reward to choose
RIBS.choice =
  { { name = "Dwarven Leather Boots", icon = 132542, quality = 2 }, { name = "Thick Cloak", icon = 133768 } }
fire("QUEST_COMPLETE")
G.advance(1)
check(P.page.kind == "complete" and P.choosing and PalaverFrame.hint.shown, "two rewards: the panel asks to choose")
G.forget()
G.key("SPACE")
check(G.called("GetQuestReward") == 0, "no reward chosen, no hand-in")
check(G.key("2") == "palaver" and P.choice == 2 and not PalaverFrame.hint.shown, "2 chooses the second reward")
G.key("SPACE")
local paid = G.TBC or G.FOREVER
n, c = G.called("GetQuestReward")
check(n == 1 and c[2] == 2, "Space hands it in with the reward chosen")

-- a turn-in that costs money: the game's own confirmation where the game asks
RIBS.cost = 500
fire("QUEST_COMPLETE")
G.key("1")
G.forget()
G.key("SPACE")
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
G.key("SPACE")
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

-- ── an error: the conversation handed to Blizzard's window ───────────────────
RIBS.broken = true
G.forget()
fire("QUEST_DETAIL")
check(not P.shown(), "a page that fails is not shown")
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

io.write(
  ("Palaver: %d checks passed (%s, %s).\n"):format(
    count,
    G.LOCALE,
    G.FOREVER and "Forever" or G.TBC and "TBC" or "Classic Era"
  )
)
