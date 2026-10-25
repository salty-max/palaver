-- A small game for Palaver's tests (the kit's game, wowmock.lua: frames,
-- events, timers, the character, the map) with Blizzard's own quest and
-- gossip windows (each registered for its events as the client registers
-- them), the gossip and quest APIs over a scripted NPC, keys. FOREVER=1 plays
-- Forever's client (its CustomGossipFrameManager, coins only in
-- C_CurrencyInfo, no GetRewardSpell), TBC=1 TBC Anniversary's (paid turn-ins
-- confirmed), LOCALE=frFR a French client (the game's own words in French).
local G = dofile("addon/test/wowmock.lua")
local state, FOREVER, LOCALE, obj = G.state, G.FOREVER, G.LOCALE, G.obj
local TBC = os.getenv("TBC") == "1"
G.TBC = TBC
local function call(name, ...) table.insert(state.calls, { name, ... }) end

-- ── what differs from the kit's game ─────────────────────────────────────────
-- (the screen's middle, and a frame's where a test put it: cx, cy)
G.methods.GetCenter = function(self)
  if self == UIParent then return self.w / 2, self.h / 2 end
  return self.cx, self.cy
end
-- a ModelScene's actor: the NPC's model loaded at once, as tall as state.npcHeight
G.methods.CreateActor = function(self, _, template)
  local a = obj("Actor")
  a.template = template
  for k, v in pairs(PalaverMeasureActorMixin or {}) do
    a[k] = v
  end
  G.actor = a -- (a model slow to load: the test loads it later)
  function a:SetModelByUnit(unit)
    call("SetModelByUnit", unit)
    if state.npcHeight then self:OnModelLoaded() end
  end
  function a:GetActiveBoundingBox()
    if not state.npcHeight then return nil end
    return -0.5, -0.5, 0, 0.5, 0.5, state.npcHeight
  end
  return a
end
-- (the experimental-settings warning: UIParent's on Classic Era, on
-- Forever Blizzard_Game's own frame behind GameEvent; a test_ setting changed
-- while it's heard counts in state.warnings, the popup the player would see)
if FOREVER then
  G.internal = { EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED = true }
  GameEvent = {
    RegisterInternalEvent = function(e) G.internal[e] = true end,
    UnregisterInternalEvent = function(e) G.internal[e] = nil end,
  }
else
  UIParent.events.EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED = true
end
if FOREVER then
  G.invalidEvents.LEARNED_SPELL_IN_TAB = true
else
  G.invalidEvents.LEARNED_SPELL_IN_SKILL_LINE = true
end

-- ── the game's basics ────────────────────────────────────────────────────────
local BUILD = FOREVER and 16001 or TBC and 20506 or 11509
function GetBuildInfo() return "x", "1", "Oct 2026", BUILD end
function IsModifierKeyDown() return state.modifier == true end
function GetCurrentKeyBoardFocus() return state.typing end
SOUNDKIT = { IG_QUEST_LIST_OPEN = 1, IG_QUEST_LIST_CLOSE = 2, IG_QUEST_CANCEL = 3, IG_MAINMENU_OPTION_CHECKBOX_ON = 4 }
-- (the game's: whether it will play, as a client with the sound says)
function PlaySound(id)
  if not id then error("PlaySound: no sound") end
  call("PlaySound", id)
  return true
end
ITEM_QUALITY_COLORS = { [2] = { r = 0.1, g = 1, b = 0.1 }, [3] = { r = 0, g = 0.44, b = 0.87 } }
C_AddOns = { IsAddOnLoaded = function(name) return state.loaded and state.loaded[name] or false end }
Enum = Enum or {}
Enum.PlayerInteractionType = { Gossip = 3, QuestGiver = 4 }
Enum.QuestFrequency = { Default = 0, Daily = 1, Weekly = 2 }
C_PlayerInteractionManager = { IsInteractingWithNpcOfType = function() return state.talking end }
function SetPortraitTexture(tex, unit) tex.portrait = unit end

-- the camera: its settings (Forever has the two newer ones), zoom, pitch
state.cvars = {
  cameraFov = "90",
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
    local heard = FOREVER and G.internal.EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED
      or not FOREVER and UIParent.events.EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED
    if heard and name:match("^test_") and state.cvars[name] ~= tostring(value) then
      state.warnings = (state.warnings or 0) + 1
    end
    state.cvars[name] = tostring(value)
  end,
}
state.zoom, state.pitchlimit = 15, 88
function GetCameraZoom() return state.zoom end
function CameraZoomIn(d) state.zoom = math.max(0, state.zoom - d) end
function CameraZoomOut(d) state.zoom = state.zoom + d end
function ConsoleExec(cmd)
  local v = cmd:match("^pitchlimit ([%d%.]+)$")
  if v then state.pitchlimit = tonumber(v) end
  call("ConsoleExec", cmd)
end
function UnitIsUnit(a, b) return a == "npc" and b == "player" and state.npcIsPlayer == true end
function IsMounted() return state.mounted == true end
function GetShapeshiftFormID() return state.form end
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

-- the game's Options page (G.options, not the kit's G.panel): what the addon registers, kept (G.options)
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
-- (not G.load: the TOC lists Camera.xml, which is no Lua file; the files as
-- the game loads them, the TBC client reading the Vanilla TOC's list)
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
