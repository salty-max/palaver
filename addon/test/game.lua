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
    -- (a method the test game lacks does nothing, as long as it is a
    -- method: the game's are capitalized, a field the addon never set is nil)
    __index = function(self, k)
      local m = G.methods[k]
      if m then return m end
      if type(k) == "string" and k:match("^%u") then
        return function() end
      end
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
  SetAlpha = function(self, a) self.alpha = a end,
  SetParent = function(self, p) self.parent = p end,
  -- the game's window: its title bar, the face in its corner
  SetTitle = function(self, t) self.titleText = t end,
  SetPortraitToUnit = function(self, unit) self.face = unit end,
  SetPortraitToAsset = function(self, asset) self.face = asset end,
  GetAlpha = function(self) return self.alpha or 1 end,
  -- a ModelScene's actor: the NPC's model loaded at once, as tall as state.npcHeight
  CreateActor = function(self, _, template)
    local a = obj("Actor")
    a.template = template
    for k, v in pairs(PalaverMeasureActorMixin or {}) do
      a[k] = v
    end
    function a:SetModelByUnit(unit)
      call("SetModelByUnit", unit)
      if state.npcHeight then self:OnModelLoaded() end
    end
    function a:GetActiveBoundingBox()
      if not state.npcHeight then return nil end
      return -0.5, -0.5, 0, 0.5, 0.5, state.npcHeight
    end
    return a
  end,
  SetVertexColor = function(self, r, g, b) self.color = { r, g, b } end,
  SetScale = function(self, v) self.scale = v end,
  GetScale = function(self) return self.scale or 1 end,
  GetParent = function(self) return self.parent end,
}

local frames = {}
function CreateFrame(kind, name, parent, template)
  local f = obj(kind, name)
  table.insert(frames, f)
  f.parent = parent
  f.template = template
  if name then _G[name] = f end
  -- (the game's window: a close button that hides it, as HideUIPanel does)
  if template == "ButtonFrameTemplate" then
    f.CloseButton = CreateFrame("Button", nil, f)
    f.CloseButton:SetScript("OnClick", function(self) self.parent:Hide() end)
  end
  -- (a tooltip of the template: it keeps its lines, as the game's does)
  if kind == "GameTooltip" then
    f.lines = {}
    function f:SetOwner() wipe(self.lines) end
    function f:AddLine(text) table.insert(self.lines, text) end
  end
  return f
end
UIParent = obj("Frame", "UIParent")
UIParent.shown = true
UIParent.w, UIParent.h = 1365, 768
UIParent.events.EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED = true
GameTooltip = obj("Frame", "GameTooltip")
GameTooltip.lines = {}
function GameTooltip:SetOwner() wipe(self.lines) end
function GameTooltip:AddLine(text) table.insert(self.lines, text) end
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
  -- (frames' OnUpdate, a tenth of a second at a time, before the timers due)
  local t = state.time
  while t < stop - 1e-9 do
    local step = math.min(0.1, stop - t)
    t = t + step
    for _, f in ipairs(frames) do
      local u = f.scripts.OnUpdate
      if u then u(f, step) end
    end
  end
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

-- the camera: its settings (Forever has the two newer ones), zoom, pitch
state.cvars = {
  test_cameraOverShoulder = "0",
  test_cameraTargetFocusInteractEnable = "0",
  test_cameraTargetFocusInteractStrengthPitch = "0.5",
  test_cameraTargetFocusInteractStrengthYaw = "1",
  test_cameraHeadMovementStrength = "0.3",
}
if FOREVER then
  state.cvars.CameraKeepCharacterCentered = "1"
  state.cvars.CameraReduceUnexpectedMovement = "1"
end
G.cvarsAtStart = {}
for k, v in pairs(state.cvars) do
  G.cvarsAtStart[k] = v
end
C_CVar = {
  GetCVar = function(name) return state.cvars[name] end,
  SetCVar = function(name, value)
    if state.cvars[name] == nil then error("no such setting " .. name) end
    state.cvars[name] = tostring(value)
  end,
}
state.zoom, state.pitchlimit = 15, 88
function GetCameraZoom() return state.zoom end
function CameraZoomIn(d) state.zoom = math.max(0, state.zoom - d) end
function CameraZoomOut(d) state.zoom = state.zoom + d end
function ConsoleExec(cmd)
  local v = cmd:match("^pitchlimit (%d+)$")
  if v then state.pitchlimit = tonumber(v) end
  call("ConsoleExec", cmd)
end
function UnitIsUnit(a, b) return a == "npc" and b == "player" and state.npcIsPlayer == true end
function IsMounted() return state.mounted == true end
if FOREVER then
  function issecretvalue() return false end
end

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
    LEVEL = "Level",
    NEXT = "Next",
    PREV = "Prev",
    CLOSE = "Close",
    PAGE_NUMBER = "Page %d",
    ITEM_TEXT_FROM = "From",
    KEY_BACKSPACE = "Backspace",
    QUEST_SUGGESTED_GROUP_NUM = "Suggested Players [%d]",
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
    LEVEL = "Niveau",
    NEXT = "Suivante",
    PREV = "Précédente",
    CLOSE = "Fermer",
    PAGE_NUMBER = "Page %d",
    ITEM_TEXT_FROM = "De",
    KEY_BACKSPACE = "Retour arrière",
    QUEST_SUGGESTED_GROUP_NUM = "Joueurs suggérés [%d]",
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

-- the game's Options page: what the addon registers, kept (G.options)
local options = { settings = {} }
G.options = options
Settings = {
  VarType = { Boolean = "boolean", Number = "number", String = "string" },
  RegisterVerticalLayoutCategory = function(name)
    options.name = name
    return { GetID = function() return 42 end }
  end,
  RegisterProxySetting = function(_, variable, _, name, default, get, set)
    local setting = { variable = variable, name = name, default = default, get = get, set = set }
    options.settings[variable] = setting
    return setting
  end,
  CreateCheckbox = function() end,
  CreateDropdown = function(_, setting, list) setting.options = list end,
  CreateControlTextContainer = function()
    local data = {}
    return {
      Add = function(_, value, label) table.insert(data, { value = value, label = label }) end,
      GetData = function() return data end,
    }
  end,
  RegisterAddOnCategory = function() options.registered = true end,
  OpenToCategory = function(id) options.opened = id end,
}

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
-- the game's book window, and the book on show (state.book: { title, pages,
-- page, creator, material })
ItemTextFrame = CreateFrame("Frame", "ItemTextFrame")
for _, e in ipairs({ "ITEM_TEXT_BEGIN", "ITEM_TEXT_TRANSLATION", "ITEM_TEXT_READY", "ITEM_TEXT_CLOSED" }) do
  ItemTextFrame:RegisterEvent(e)
end
ItemTextFrame:SetScript("OnEvent", function(_, e) call("ItemTextFrame", e) end)
local function book() return state.book end
function ItemTextGetItem() return book() and book().title end
function ItemTextGetText() return book().pages[book().page] end
function ItemTextGetPage() return book().page end
function ItemTextHasNextPage() return book().page < #book().pages end
function ItemTextGetCreator() return book().creator end
function ItemTextGetMaterial() return book().material end
function ItemTextNextPage() call("ItemTextNextPage") end
function ItemTextPrevPage() call("ItemTextPrevPage") end
function CloseItemText() call("CloseItemText") end

-- the game's interface, hidden and shown as Alt+Z does (shown: the game
-- closes every window open, UIParent_OnShow)
function SetUIVisibility(on)
  call("SetUIVisibility", on)
  if on and not UIParent.shown then call("CloseAllWindows") end
  UIParent.shown = on
end
function hooksecurefunc(name, fn)
  local old = _G[name]
  _G[name] = function(...)
    local r = { old(...) }
    fn(...)
    return unpack(r)
  end
end
function GetSuggestedGroupNum() return state.quest and state.quest.group or 0 end
function GetQuestDifficultyColor() return { r = 1, g = 1, b = 0 } end

for _, f in ipairs({ QuestFrame, GossipFrame, ItemTextFrame, CustomGossipFrameManager }) do
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
  return it.name, it.icon, it.count or 1, it.quality or 1, it.usable ~= false
end
function GetQuestItemLink(kind, i) return list(kind)[i].link end

-- items as the game tells them (state.items[link]: { name, price, slot,
-- stats }; pending: not told yet), what the character wears (state.worn[slot]:
-- a link), its class and talents (state.class, state.talents: points a tree)
state.items, state.worn, state.class, state.talents = {}, {}, "WARRIOR", { 0, 0, 0 }
local function info(link)
  local it = link and state.items[link]
  if not it or it.pending then return end
  return it.name, link, 1, 10, 1, "Armor", "Misc", 1, it.slot or "", 134400, it.price or 0
end
local function stats(link)
  local it = link and state.items[link]
  if not it or it.pending then return nil end
  local out = {}
  for k, v in pairs(it.stats or {}) do
    out[k] = v
  end
  return out
end
if FOREVER then
  C_Item = { GetItemInfo = info, GetItemStats = stats }
else
  GetItemInfo, GetItemStats = info, stats
end
function GetInventoryItemLink(unit, slot) return unit == "player" and state.worn[slot] or nil end
function UnitClass() return "Class", state.class end
function CanDualWield() return state.dualWield == true end
function GetNumTalentTabs() return 3 end
function GetTalentTabInfo(i)
  -- (Classic Era's: name, icon, points; TBC's and Forever's: id, name, text, icon, points)
  if FOREVER or TBC then return 100 + i, "Tree" .. i, "", 1, state.talents[i] end
  return "Tree" .. i, 1, state.talents[i]
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
for _, file in ipairs({
  "Kit.lua",
  "Locale.lua",
  "Text_" .. LOCALE .. ".lua",
  FOREVER and "Quests_Forever.lua" or "Quests_Classic.lua",
  "Game.lua",
  "Rewards.lua",
  "Panel.lua",
  "Camera.lua",
  "Hud.lua",
  "Core.lua",
  "Settings.lua",
}) do
  assert(loadfile(DIR .. file))("Palaver", ns)
end
function G.login(loaded)
  state.loaded = loaded
  G.fire("ADDON_LOADED", "Palaver")
  G.fire("PLAYER_LOGIN")
end
return G
