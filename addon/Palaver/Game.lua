-- What the game says, read into plain tables for the panel, and what the
-- player answers, said back to it: the same calls Blizzard's own gossip and
-- quest windows make (Blizzard_UIPanels_Game: GossipFrameShared.lua,
-- QuestFrame.lua, QuestInfo.lua), in every game: Classic Era,
-- Forever. A function one game lacks is checked before use.
--
-- A page: { kind, unit, name, title, text, rows, sections, rewards,
-- required, money, actions }. kind: gossip, greeting, detail, progress,
-- complete. Rows are what the player may pick (a quest, an option), each
-- with its icon, text, a faded look (a quest too low to matter) and pick().
local _, ns = ...
local G = {}
ns.game = G

-- The game's own words for what its windows say (Accept, Rewards...), in the
-- client's language: its interface strings, the English where one is missing.
-- A heading's trailing colon dropped ("Required items:").
function G.word(tag, english)
  -- selene: allow(global_usage)
  local s = _G[tag]
  if type(s) ~= "string" or s == "" then s = english end
  return (s:gsub("%s*[:：]%s*$", ""))
end
local word = G.word

local QUEST_ICON = {
  available = "Interface\\GossipFrame\\AvailableQuestIcon",
  daily = "Interface\\GossipFrame\\DailyQuestIcon",
  repeatable = "Interface\\GossipFrame\\DailyActiveQuestIcon",
  legendary = "Interface\\GossipFrame\\AvailableLegendaryQuestIcon",
  active = "Interface\\GossipFrame\\ActiveQuestIcon",
  incomplete = "Interface\\GossipFrame\\IncompleteQuestIcon",
}
G.QUEST_ICON = QUEST_ICON

-- The one speaking: a gossip's "npc", a quest's "questnpc" (the same
-- creature, or an object, or a quest started from an item: nobody).
local function speaker(kind)
  local unit = kind == "gossip" and "npc" or "questnpc"
  if not UnitExists(unit) then unit = "npc" end
  if not UnitExists(unit) then return nil, nil end
  return unit, UnitName(unit)
end

-- ── a gossip ─────────────────────────────────────────────────────────────────
local function frequent(info)
  local F = Enum and Enum.QuestFrequency
  return F and not info.isMeta and (info.frequency == F.Daily or info.frequency == F.Weekly)
end

local function sortOptions(options)
  table.sort(options, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
  return options
end

-- The gossip the game would skip: no quest, one option the game marks to be
-- chosen straight away (Blizzard's HandleShow).
function G.skipGossip()
  local C = C_GossipInfo
  local options = sortOptions(C.GetOptions() or {})
  if C.GetNumAvailableQuests() > 0 or C.GetNumActiveQuests() > 0 or #options ~= 1 then return nil end
  if C.ForceGossip and C.ForceGossip() then return nil end
  if options[1].selectOptionWhenOnlyOption then return options[1].orderIndex end
end

function G.gossip()
  local C = C_GossipInfo
  local unit, name = speaker("gossip")
  local rows = {}
  for _, q in ipairs(C.GetAvailableQuests() or {}) do
    local icon = q.isLegendary and QUEST_ICON.legendary
      or frequent(q) and QUEST_ICON.daily
      or q.repeatable and QUEST_ICON.repeatable
      or QUEST_ICON.available
    table.insert(rows, {
      kind = "quest",
      icon = icon,
      text = q.title,
      faded = q.isTrivial or q.isIgnored,
      pick = function() C.SelectAvailableQuest(q.questID) end,
    })
  end
  for _, q in ipairs(C.GetActiveQuests() or {}) do
    table.insert(rows, {
      kind = "quest",
      icon = q.isComplete and QUEST_ICON.active or QUEST_ICON.incomplete,
      text = q.title,
      faded = q.isTrivial or q.isIgnored,
      pick = function() C.SelectActiveQuest(q.questID) end,
    })
  end
  for _, o in ipairs(sortOptions(C.GetOptions() or {})) do
    table.insert(rows, {
      kind = "option",
      icon = o.overrideIconID or o.icon or "Interface\\GossipFrame\\GossipGossipIcon",
      text = o.name,
      pick = function() C.SelectOptionByIndex(o.orderIndex) end,
    })
  end
  return {
    kind = "gossip",
    unit = unit,
    name = name,
    title = name,
    text = C.GetText() or "",
    rows = rows,
    actions = { secondary = { label = word("GOODBYE", "Goodbye"), run = G.closeGossip } },
  }
end

function G.closeGossip() C_GossipInfo.CloseGossip() end

-- ── a quest's greeting: an NPC with several quests and no gossip ─────────────
function G.greeting()
  local unit, name = speaker("quest")
  local rows = {}
  local numActive = GetNumActiveQuests()
  for i = 1, numActive do
    local title, isComplete = GetActiveTitle(i)
    table.insert(rows, {
      kind = "quest",
      icon = isComplete and QUEST_ICON.active or QUEST_ICON.incomplete,
      text = title,
      faded = IsActiveQuestTrivial and IsActiveQuestTrivial(i),
      pick = function() SelectActiveQuest(i) end,
    })
  end
  for i = 1, GetNumAvailableQuests() do
    local isTrivial, isDaily, isRepeatable, isLegendary
    if GetAvailableQuestInfo then
      isTrivial, isDaily, isRepeatable, isLegendary = GetAvailableQuestInfo(i)
    end
    table.insert(rows, {
      kind = "quest",
      icon = isLegendary and QUEST_ICON.legendary
        or isDaily and QUEST_ICON.daily
        or isRepeatable and QUEST_ICON.repeatable
        or QUEST_ICON.available,
      text = GetAvailableTitle(i),
      faded = isTrivial,
      pick = function() SelectAvailableQuest(i) end,
    })
  end
  return {
    kind = "greeting",
    unit = unit,
    name = name,
    title = name,
    text = GetGreetingText() or "",
    rows = rows,
    actions = { secondary = { label = word("GOODBYE", "Goodbye"), run = G.closeQuest } },
  }
end

function G.closeQuest() CloseQuest() end

-- ── rewards and what a quest asks to bring ───────────────────────────────────
-- (an item's link, for its price and stats, and whether the character can
-- use it: the game's red icon in its own window)
local function items(type, count)
  local out = {}
  for i = 1, count do
    local name, texture, numItems, quality, isUsable = GetQuestItemInfo(type, i)
    if name or texture then
      table.insert(out, {
        type = type,
        index = i,
        name = name,
        icon = texture,
        count = numItems,
        quality = quality,
        usable = isUsable,
        link = GetQuestItemLink and GetQuestItemLink(type, i) or nil,
      })
    end
  end
  return out
end

-- Spells a quest teaches or casts: Forever's per-quest list, else Classic's one.
local function spells()
  local out = {}
  local questID = GetQuestID and GetQuestID()
  if C_QuestInfoSystem and C_QuestInfoSystem.GetQuestRewardSpells and questID and questID > 0 then
    for _, spellID in ipairs(C_QuestInfoSystem.GetQuestRewardSpells(questID) or {}) do
      local info = C_QuestInfoSystem.GetQuestRewardSpellInfo(questID, spellID)
      if info and info.texture then table.insert(out, { name = info.name, icon = info.texture, spell = spellID }) end
    end
  elseif GetRewardSpell then
    local texture, name = GetRewardSpell()
    if texture then table.insert(out, { name = name, icon = texture, spell = true }) end
  end
  return out
end

-- What finishing the quest gives: a choice among items (choice), items given
-- (given), spells, money, experience (where the game tells it), honor, a title.
function G.rewards()
  local r = {
    choice = items("choice", GetNumQuestChoices()),
    given = items("reward", GetNumQuestRewards()),
    spells = spells(),
    money = GetRewardMoney and GetRewardMoney() or 0,
    xp = GetRewardXP and GetRewardXP() or 0,
    honor = GetRewardHonor and GetRewardHonor() or 0,
    title = GetRewardTitle and GetRewardTitle() or nil,
  }
  r.any = #r.choice + #r.given + #r.spells > 0 or r.money > 0 or r.xp > 0 or r.honor > 0 or r.title ~= nil
  return r
end

-- Money as the game writes it, its coins drawn in (Forever's namespace first,
-- else the old global).
function G.coins(copper)
  local fn = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString or GetCoinTextureString
  return fn and fn(copper) or tostring(copper)
end

-- ── a quest's pages ──────────────────────────────────────────────────────────
local function quest(kind)
  local unit, name = speaker("quest")
  return { kind = kind, unit = unit, name = name, title = GetTitleText() or "" }
end

-- ── a quest's facts ──────────────────────────────────────────────────────────
-- What the offer page tells before it is accepted (scripts/quests.ts, from
-- wow-data's databases, each game's own Quests_<game>.lua): its level, its
-- kind (elite, dungeon, raid, PvP...), its place in its chain; and the group
-- the game suggests for it, where it says. nil: nothing known.
function G.facts(questID)
  local f = {}
  local v = questID and ns.quests and ns.quests[questID]
  if v then
    f.level = v % 100
    f.kind = math.floor(v / 100) % 100
    f.part = math.floor(v / 10000) % 100
    f.of = math.floor(v / 1000000)
  end
  local group = GetSuggestedGroupNum and GetSuggestedGroupNum() or 0
  if type(group) == "number" and group > 1 then f.group = group end
  if (f.level or 0) > 0 or (f.kind or 0) > 0 or (f.of or 0) > 1 or f.group then return f end
end

-- Offered: what it is, what it asks, what it gives.
function G.detail()
  local p = quest("detail")
  p.facts = G.facts(GetQuestID and GetQuestID())
  p.text = GetQuestText() or ""
  p.objectives = GetObjectiveText() or ""
  p.rewards = G.rewards()
  p.actions = {
    primary = { label = word("ACCEPT", "Accept"), run = AcceptQuest },
    secondary = { label = word("DECLINE", "Decline"), run = DeclineQuest },
  }
  return p
end

-- Brought back unfinished, or finished: what it still asks to bring.
function G.progress()
  local p = quest("progress")
  p.text = GetProgressText() or ""
  p.required = items("required", GetNumQuestItems())
  p.money = GetQuestMoneyToGet and GetQuestMoneyToGet() or 0
  local completable = IsQuestCompletable()
  p.actions = {
    primary = { label = word("CONTINUE", "Continue"), run = CompleteQuest, disabled = not completable },
    secondary = { label = word("GOODBYE", "Goodbye"), run = DeclineQuest },
  }
  return p
end

-- Handed in: the NPC's thanks, the rewards, a choice among them maybe.
function G.complete()
  local p = quest("complete")
  p.text = GetRewardText() or ""
  p.rewards = G.rewards()
  p.choose = #p.rewards.choice > 1
  p.actions = {
    primary = { label = word("COMPLETE_QUEST", "Complete Quest"), run = G.turnIn },
    secondary = { label = word("GOODBYE", "Goodbye"), run = DeclineQuest },
  }
  return p
end

-- The turn-in, with the reward chosen (choice: its index; one choice is the
-- choice). A turn-in that costs money asks first where the game asks (Forever, Blizzard's QuestRewardCompleteButton_OnClick): its own
-- confirmation, which takes the choice from QuestInfoFrame.
function G.turnIn(choice)
  local n = GetNumQuestChoices()
  if n == 1 then choice = 1 end
  if n > 1 and not choice then return false end
  local cost = GetQuestMoneyToGet and GetQuestMoneyToGet() or 0
  if cost > 0 and ns.forever and StaticPopup_Show then
    if QuestInfoFrame then QuestInfoFrame.itemChoice = choice or 0 end
    local dialog = StaticPopup_Show("CONFIRM_COMPLETE_EXPENSIVE_QUEST")
    local moneyFrame = dialog and (dialog.MoneyFrame or dialog.moneyFrame)
    if moneyFrame and MoneyFrame_Update then MoneyFrame_Update(moneyFrame, cost) end
    return true
  end
  GetQuestReward(choice or 0)
  return true
end

-- ── a book, a letter, a plaque ───────────────────────────────────────────────
-- What the game's book window shows (Blizzard_UIPanels_Game's
-- ItemTextFrame.lua): the item's or the object's name, a page of its text
-- and who wrote it (a letter), the page's number where there are several
-- (kicker: the small line beside the window's face).
-- A page in HTML (a heading, paragraphs) read as plain text: its tags gone,
-- its breaks kept.
function G.plain(text)
  if not text:find("^%s*<[Hh][Tt][Mm][Ll]") then return text end
  text = text:gsub("<[Bb][Rr]%s*/?>", "\n")
  text = text:gsub("</[Pp]>", "\n\n"):gsub("</[Hh]%d>", "\n\n")
  text = text:gsub("<[^>]*>", "")
  text = text:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&nbsp;", " "):gsub("&amp;", "&")
  text = text:gsub("[ \t]*\n[ \t]*", "\n"):gsub("\n\n\n+", "\n\n")
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function turn(fn)
  return function()
    if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
      PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
    fn()
  end
end

function G.book()
  local page = ItemTextGetPage and ItemTextGetPage() or 1
  local hasNext = ItemTextHasNextPage and ItemTextHasNextPage()
  local text = G.plain(ItemTextGetText() or "")
  local creator = ItemTextGetCreator and ItemTextGetCreator()
  if creator and creator ~= "" then text = text .. "\n\n" .. word("ITEM_TEXT_FROM", "From") .. "\n" .. creator end
  local paged = page > 1 or hasNext
  local close = { label = word("CLOSE", "Close"), run = CloseItemText }
  return {
    kind = "book",
    title = ItemTextGetItem() or "",
    kicker = paged and word("PAGE_NUMBER", "Page %d"):format(page) or nil,
    text = text,
    actions = {
      primary = hasNext and { label = word("NEXT", "Next"), run = turn(ItemTextNextPage) } or close,
      secondary = hasNext and close or nil,
      back = page > 1 and { label = word("PREV", "Prev"), run = turn(ItemTextPrevPage) } or nil,
    },
  }
end

-- A text the game is still translating (ITEM_TEXT_TRANSLATION): its name,
-- a word that it comes.
function G.translating()
  return {
    kind = "book",
    title = ItemTextGetItem and ItemTextGetItem() or "",
    text = ns.kit.L["Translating..."],
    actions = { secondary = { label = word("CLOSE", "Close"), run = CloseItemText } },
  }
end

-- An item a quest asks for or gives, in the game's tooltip, and Palaver's
-- word on it below (notes: { text, color }, why a reward is marked).
-- (the game's tooltip, or Palaver's own while the interface is hidden)
function G.itemTooltip(owner, item, notes)
  local tip = ns.panel.tooltip()
  tip:SetOwner(owner, "ANCHOR_RIGHT")
  if item.spell then
    if type(item.spell) == "number" and tip.SetSpellByID then tip:SetSpellByID(item.spell) end
  else
    tip:SetQuestItem(item.type, item.index)
  end
  for i, note in ipairs(notes or {}) do
    if i == 1 then tip:AddLine(" ") end
    tip:AddLine(note[1], note[2][1], note[2][2], note[2][3], true)
  end
  tip:Show()
end

-- A quest started from an item: the game accepts it itself (Blizzard closes
-- the window at once, QuestFrame_OnEvent).
function G.startedFromItem(questStartItemID) return questStartItemID ~= nil and questStartItemID ~= 0 end
