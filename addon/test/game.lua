-- A small game for Palaver's tests: frames as the kit and the panel use
-- them, the game's events, Blizzard's own quest and gossip windows (each
-- registered for its events as the client registers them), the gossip and
-- quest APIs over a scripted NPC, timers, keys. FOREVER=1 plays Forever's
-- client (its CustomGossipFrameManager, coins only in C_CurrencyInfo, no
-- GetRewardSpell), TBC=1 TBC Anniversary's (paid turn-ins confirmed),
-- LOCALE=frFR a French client (the game's own words in French).
local G = {}
local state = { time = 1000, calls = {}, printed = {}, timers = {}, combat = false, talking = false }
G.state = state
local FOREVER = os.getenv("FOREVER") == "1"
local TBC = os.getenv("TBC") == "1"
local LOCALE = os.getenv("LOCALE") or "enUS"
G.FOREVER, G.TBC, G.LOCALE = FOREVER, TBC, LOCALE

local function call(name, ...) table.insert(state.calls, { name, ... }) end
function G.called(name)
  local n, last = 0, nil
  for _, c in ipairs(state.calls) do
    if c[1] == name then
      n = n + 1
      last = c
    end
  end
  return n, last
end
function G.forget() state.calls = {} end

-- ── frames ───────────────────────────────────────────────────────────────────
local registry = {} -- event -> frames, in registration order
local function obj(kind, name)
  local o = {
    kind = kind,
    name = name,
    shown = kind ~= "Frame" and kind ~= "Button" and kind ~= "ScrollFrame",
    scripts = {},
    events = {},
    text = nil,
    w = 0,
    h = 0,
    font = 15,
  }
  return setmetatable(o, {
    __index = function(self, k)
      local m = G.methods[k]
      if m then return m end
      return function() end
    end,
  })
end
G.methods = {
  Show = function(self)
    self.shown = true
    local s = self.scripts.OnShow
    if s then s(self) end
  end,
  Hide = function(self)
    local was = self.shown
    self.shown = false
    local s = self.scripts.OnHide
    if was and s then s(self) end
  end,
  IsShown = function(self) return self.shown end,
  IsVisible = function(self) return self.shown end,
  SetShown = function(self, v)
    if v then
      self:Show()
    else
      self:Hide()
    end
  end,
  SetText = function(self, t) self.text = t end,
  GetText = function(self) return self.text end,
  SetFormattedText = function(self, f, ...) self.text = f:format(...) end,
  SetScript = function(self, k, f) self.scripts[k] = f end,
  GetScript = function(self, k) return self.scripts[k] end,
  HookScript = function(self, k, f)
    local old = self.scripts[k]
    self.scripts[k] = function(...)
      if old then old(...) end
      f(...)
    end
  end,
  RegisterEvent = function(self, e)
    if G.invalidEvents[e] then error('Attempt to register unknown event "' .. e .. '"') end
    if self.events[e] then return end
    self.events[e] = true
    registry[e] = registry[e] or {}
    table.insert(registry[e], self)
  end,
  UnregisterEvent = function(self, e)
    if not self.events[e] then return end
    self.events[e] = nil
    for i, f in ipairs(registry[e] or {}) do
      if f == self then
        table.remove(registry[e], i)
        break
      end
    end
  end,
  UnregisterAllEvents = function(self)
    for e in pairs(self.events) do
      G.methods.UnregisterEvent(self, e)
    end
  end,
  IsEventRegistered = function(self, e) return self.events[e] == true end,
  SetWidth = function(self, w) self.w = w end,
  SetHeight = function(self, h) self.h = h end,
  SetSize = function(self, w, h)
    self.w, self.h = w, h
  end,
  GetWidth = function(self) return self.w end,
  GetHeight = function(self) return self.h end,
  SetFont = function(self, _, size) self.font = size end,
  GetStringHeight = function(self)
    local t = self.text or ""
    if t == "" then return 0 end
    local per = math.max(1, math.floor((self.w > 0 and self.w or 300) / (self.font * 0.55)))
    local lines = 0
    for para in (t .. "\n"):gmatch("(.-)\n") do
      lines = lines + math.max(1, math.ceil(#para / per))
    end
    return lines * (self.font + 4)
  end,
  GetStringWidth = function(self) return #(self.text or "") * self.font * 0.55 end,
  CreateTexture = function() return obj("Texture") end,
  CreateFontString = function() return obj("FontString") end,
  CreateMaskTexture = function() return obj("MaskTexture") end,
  GetPoint = function(self) return "RIGHT", UIParent, "RIGHT", -100, 20 end,
  SetScrollChild = function(self, c) self.scrollChild = c end,
  GetVerticalScroll = function(self) return self.vscroll or 0 end,
  SetVerticalScroll = function(self, v) self.vscroll = v end,
  EnableKeyboard = function(self, on)
    if state.combat then error("EnableKeyboard is protected in combat") end
    self.keyboard = on
  end,
  SetPropagateKeyboardInput = function(self, on)
    if state.combat then error("SetPropagateKeyboardInput is protected in combat") end
    self.propagate = on
  end,
  GetName = function(self) return self.name end,
  SetScale = function(self, v) self.scale = v end,
  GetScale = function(self) return self.scale or 1 end,
  GetParent = function(self) return self.parent end,
}

function CreateFrame(kind, name, parent, template)
  local f = obj(kind, name)
  f.parent = parent
  f.template = template
  if name then _G[name] = f end
  return f
end
UIParent = obj("Frame", "UIParent")
UIParent.shown = true
UIParent.w, UIParent.h = 1365, 768
GameTooltip = obj("Frame", "GameTooltip")
WorldFrame = obj("Frame", "WorldFrame")

G.invalidEvents = {}
if FOREVER then
  G.invalidEvents.LEARNED_SPELL_IN_TAB = true
else
  G.invalidEvents.LEARNED_SPELL_IN_SKILL_LINE = true
end

function G.fire(e, ...)
  local list = {}
  for _, f in ipairs(registry[e] or {}) do
    table.insert(list, f)
  end
  for _, f in ipairs(list) do
    local s = f.scripts.OnEvent
    if s and f.events[e] then s(f, e, ...) end
  end
end

-- ── timers ───────────────────────────────────────────────────────────────────
function GetTime() return state.time end
function time() return 1790000000 + math.floor(state.time) end
C_Timer = {
  After = function(delay, fn) table.insert(state.timers, { at = state.time + delay, fn = fn }) end,
}
function G.advance(seconds)
  local stop = state.time + seconds
  while true do
    table.sort(state.timers, function(a, b) return a.at < b.at end)
    local t = state.timers[1]
    if not t or t.at > stop then break end
    table.remove(state.timers, 1)
    state.time = t.at
    t.fn()
  end
  state.time = stop
end

-- ── the game's basics ────────────────────────────────────────────────────────
local BUILD = FOREVER and 16001 or TBC and 20506 or 11509
function GetBuildInfo() return "x", "1", "Oct 2026", BUILD end
function GetLocale() return LOCALE end
function print(...)
  local t = {}
  for i = 1, select("#", ...) do
    t[#t + 1] = tostring(select(i, ...))
  end
  table.insert(state.printed, table.concat(t, " "))
end
function wipe(t)
  for k in pairs(t) do
    t[k] = nil
  end
  return t
end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function debugstack() return "stack" end
function InCombatLockdown() return state.combat end
function IsModifierKeyDown() return state.modifier == true end
function GetCurrentKeyBoardFocus() return state.typing end
SOUNDKIT = { IG_QUEST_LIST_OPEN = 1, IG_QUEST_LIST_CLOSE = 2, IG_QUEST_CANCEL = 3, IG_MAINMENU_OPTION_CHECKBOX_ON = 4 }
function PlaySound(id)
  if not id then error("PlaySound: no sound") end
  call("PlaySound", id)
end
ITEM_QUALITY_COLORS = { [2] = { r = 0.1, g = 1, b = 0.1 }, [3] = { r = 0, g = 0.44, b = 0.87 } }
SlashCmdList = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
UISpecialFrames = {}
C_AddOns = { IsAddOnLoaded = function(name) return state.loaded and state.loaded[name] or false end }
Enum =
  { PlayerInteractionType = { Gossip = 3, QuestGiver = 4 }, QuestFrequency = { Default = 0, Daily = 1, Weekly = 2 } }
C_PlayerInteractionManager = { IsInteractingWithNpcOfType = function() return state.talking end }
function SetPortraitTexture(tex, unit) tex.portrait = unit end

-- the game's own words, in the client's language
local WORDS = {
  enUS = {
    ACCEPT = "Accept",
    DECLINE = "Decline",
    COMPLETE_QUEST = "Complete Quest",
    CONTINUE = "Continue",
    GOODBYE = "Goodbye",
    REWARDS = "Rewards",
    QUEST_OBJECTIVES = "Quest Objectives",
    TURN_IN_ITEMS = "Required items:",
    EXPERIENCE_COLON = "Experience:",
    MONEY = "Money",
    REWARD_CHOOSE = "Choose your reward:",
    REWARD_ITEMS = "You will also receive:",
  },
  frFR = {
    ACCEPT = "Accepter",
    DECLINE = "Refuser",
    COMPLETE_QUEST = "Terminer la quête",
    CONTINUE = "Continuer",
    GOODBYE = "Au revoir",
    REWARDS = "Récompenses",
    QUEST_OBJECTIVES = "Objectifs",
    TURN_IN_ITEMS = "Objets requis :",
    EXPERIENCE_COLON = "Expérience :",
    MONEY = "Argent",
    REWARD_CHOOSE = "Choisissez votre récompense :",
    REWARD_ITEMS = "Vous recevrez également :",
  },
}
for k, v in pairs(WORDS[LOCALE] or WORDS.enUS) do
  _G[k] = v
end

-- coins: Forever has them in C_CurrencyInfo alone (alpha.3's error)
local function coins(c) return ("%dc"):format(c) end
if FOREVER then
  C_CurrencyInfo = { GetCoinTextureString = coins }
else
  GetCoinTextureString = coins
end

-- ── Blizzard's windows, as the client registers them ─────────────────────────
QuestFrame = CreateFrame("Frame", "QuestFrame")
for _, e in ipairs({
  "QUEST_GREETING",
  "QUEST_DETAIL",
  "QUEST_PROGRESS",
  "QUEST_COMPLETE",
  "QUEST_FINISHED",
  "QUEST_ITEM_UPDATE",
  "QUEST_LOG_UPDATE",
  "UNIT_PORTRAIT_UPDATE",
  "PORTRAITS_UPDATED",
  FOREVER and "LEARNED_SPELL_IN_SKILL_LINE" or "LEARNED_SPELL_IN_TAB",
}) do
  QuestFrame:RegisterEvent(e)
end
QuestFrame:SetScript("OnEvent", function(_, e) call("QuestFrame", e) end)
GossipFrame = CreateFrame("Frame", "GossipFrame")
GossipFrame:RegisterEvent("QUEST_LOG_UPDATE")
if FOREVER then
  CustomGossipFrameManager = CreateFrame("Frame", "CustomGossipFrameManager")
  CustomGossipFrameManager:RegisterEvent("GOSSIP_SHOW")
  CustomGossipFrameManager:RegisterEvent("GOSSIP_CLOSED")
  CustomGossipFrameManager.handlers = {}
  function CustomGossipFrameManager:GetHandler(kit) return self.handlers[kit] end
  function CustomGossipFrameManager:HandleOpenEvent(kit) call("CustomGossip", kit) end
else
  GossipFrame:RegisterEvent("GOSSIP_SHOW")
  GossipFrame:RegisterEvent("GOSSIP_CLOSED")
end
GossipFrame:SetScript("OnEvent", function(_, e) call("GossipFrame", e) end)
G.native = {}
for _, f in ipairs({ QuestFrame, GossipFrame, CustomGossipFrameManager }) do
  local list = {}
  for e in pairs(f.events) do
    list[#list + 1] = e
  end
  table.sort(list)
  G.native[f] = table.concat(list, ",")
end
function G.events(f)
  local list = {}
  for e in pairs(f.events) do
    list[#list + 1] = e
  end
  table.sort(list)
  return table.concat(list, ",")
end

QuestInfoFrame = {}
for i = 1, 4 do
  _G["StaticPopup" .. i] = CreateFrame("Frame", "StaticPopup" .. i)
end
function StaticPopup_Show(which)
  call("StaticPopup_Show", which, QuestInfoFrame.itemChoice)
  StaticPopup1:Show()
  return StaticPopup1
end
function PlayAutoAcceptQuestSound() call("PlayAutoAcceptQuestSound") end

-- ── the NPC and the quest on show ────────────────────────────────────────────
-- state.npc: { name, gossip = { text, options, available, active }, greeting
-- = { text, active, available }, quest = { id, title, text, objectives,
-- progress, reward, completable, required, choice, given, money, xp, cost } }
function UnitExists(unit) return (unit == "npc" or unit == "questnpc") and state.npc ~= nil end
function UnitName(unit)
  if UnitExists(unit) then return state.npc.name end
end

local function gossip() return state.npc.gossip end
C_GossipInfo = {
  GetText = function() return gossip().text end,
  GetOptions = function()
    local out = {}
    for i, o in ipairs(gossip().options or {}) do
      out[i] = {
        name = o.name,
        icon = o.icon or 132053,
        orderIndex = i - 1,
        gossipOptionID = 1000 + i,
        selectOptionWhenOnlyOption = o.only,
      }
    end
    return out
  end,
  GetAvailableQuests = function() return gossip().available or {} end,
  GetActiveQuests = function() return gossip().active or {} end,
  GetNumAvailableQuests = function() return #(gossip().available or {}) end,
  GetNumActiveQuests = function() return #(gossip().active or {}) end,
  ForceGossip = function() return false end,
  SelectOptionByIndex = function(i) call("SelectOptionByIndex", i) end,
  SelectAvailableQuest = function(id) call("SelectAvailableQuest", id) end,
  SelectActiveQuest = function(id) call("SelectActiveQuest", id) end,
  CloseGossip = function() call("CloseGossip") end,
}

local function quest() return state.quest end
function GetQuestID() return quest() and quest().id or 0 end
function GetTitleText() return quest().title end
function GetQuestText()
  if quest().broken then error("a broken quest text") end
  return quest().text
end
function GetObjectiveText() return quest().objectives end
function GetProgressText() return quest().progress end
function GetRewardText() return quest().reward end
function IsQuestCompletable() return quest().completable end
function GetGreetingText() return state.npc.greeting.text end
function GetNumActiveQuests() return #state.npc.greeting.active end
function GetActiveTitle(i) return state.npc.greeting.active[i].title, state.npc.greeting.active[i].isComplete end
function GetNumAvailableQuests() return #state.npc.greeting.available end
function GetAvailableTitle(i) return state.npc.greeting.available[i].title end
if TBC or FOREVER then
  function GetAvailableQuestInfo(i) return state.npc.greeting.available[i].isTrivial, false, false, false end
end
function SelectActiveQuest(i) call("SelectActiveQuest#", i) end
function SelectAvailableQuest(i) call("SelectAvailableQuest#", i) end
local function list(kind)
  local q = quest()
  return kind == "choice" and (q.choice or {}) or kind == "reward" and (q.given or {}) or (q.required or {})
end
function GetNumQuestChoices() return #list("choice") end
function GetNumQuestRewards() return #list("reward") end
function GetNumQuestItems() return #list("required") end
function GetQuestItemInfo(kind, i)
  local it = list(kind)[i]
  return it.name, it.icon, it.count or 1, it.quality or 1, true
end
function GetRewardMoney() return quest().money or 0 end
function GetRewardXP() return quest().xp or 0 end
function GetQuestMoneyToGet() return quest().cost or 0 end
if not FOREVER then
  function GetRewardSpell() end
end
function AcceptQuest() call("AcceptQuest") end
function DeclineQuest() call("DeclineQuest") end
function CompleteQuest() call("CompleteQuest") end
function GetQuestReward(i) call("GetQuestReward", i) end
function CloseQuest() call("CloseQuest") end

-- ── keys ─────────────────────────────────────────────────────────────────────
-- A key pressed and released on Palaver's listener (if it listens): whether
-- the game got it too.
function G.key(key, holdThen)
  local l = PalaverKeys
  if not (l and l.shown and l.keyboard) then return "game" end
  l.propagate = true
  l.scripts.OnKeyDown(l, key)
  local taken = l.propagate == false
  if holdThen then holdThen() end
  l.scripts.OnKeyUp(l, key)
  return taken and "palaver" or "game"
end

-- ── the addon ────────────────────────────────────────────────────────────────
local DIR = "addon/Palaver/"
local ns = {}
G.ns = ns
for _, file in ipairs({ "Kit.lua", "Locale.lua", "Text_" .. LOCALE .. ".lua", "Game.lua", "Panel.lua", "Core.lua" }) do
  assert(loadfile(DIR .. file))("Palaver", ns)
end
function G.login(loaded)
  state.loaded = loaded
  G.fire("ADDON_LOADED", "Palaver")
  G.fire("PLAYER_LOGIN")
end
return G
