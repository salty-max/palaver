-- The conversation: the game's quest and gossip events taken from Blizzard's
-- windows (muted once, at login, as DialogueUI does: QuestFrame's events,
-- GossipFrame's and Forever's CustomGossipFrameManager's, each restored as it
-- was when Palaver is turned off), shown in the panel (Panel.lua), answered
-- through the game's own calls (Game.lua).
--
-- A conversation goes on across pages: a gossip leads to a quest, a quest
-- back to the gossip. The game closes one page before it opens the next, so
-- a close is only acted on a moment later, if nothing has come since and the
-- NPC is no longer talking. A close the game says goes on (GOSSIP_CLOSED's
-- interactionIsContinuing: a vendor, a trainer, a flight master's map) and
-- one of those windows opening step the panel aside without a word to the
-- game. Only the player ends a conversation (Goodbye, Decline, Escape).
--
-- Books, letters and plaques too: the game's book window muted the same way
-- (its ITEM_TEXT_ events), where the books setting says.
--
-- PalaverSettings: { enabled, scale, font, keys, readOn, camera, value,
-- upgrades, books, hideUI, version, point, cameraBackup }. PalaverErrors:
-- the last few errors (a page that failed to draw hands its conversation to
-- Blizzard's window for the rest of the session, said once in chat; a
-- reward's mark that failed only drops the marks).
local addonName, ns = ...
local K = ns.kit
local L = K.L
local G, P = ns.game, ns.panel
local C = {}
ns.core = C

local PREFIX = K.hex(K.T.accent) .. "Palaver|r: "
local DEFAULTS = {
  enabled = true,
  scale = 1,
  font = 15,
  keys = true,
  camera = true,
  value = true,
  upgrades = true,
  readOn = true,
  books = true,
  hideUI = true,
  version = 3,
}
ns.DEFAULTS = DEFAULTS -- (the Options page's defaults: Settings.lua)
local RIVALS = { "DialogueUI", "Immersion", "Storyline" }

local function say(text) print(PREFIX .. text) end
-- (a sound by its name in the game's list, if this game has it)
local function sound(name)
  local id = SOUNDKIT and SOUNDKIT[name]
  if id then PlaySound(id) end
end

-- ── Blizzard's windows, muted and restored ───────────────────────────────────
local QUEST_EVENTS = {
  "QUEST_GREETING",
  "QUEST_DETAIL",
  "QUEST_PROGRESS",
  "QUEST_COMPLETE",
  "QUEST_FINISHED",
  "QUEST_ITEM_UPDATE",
  "QUEST_LOG_UPDATE",
  "UNIT_PORTRAIT_UPDATE",
  "PORTRAITS_UPDATED",
  "LEARNED_SPELL_IN_SKILL_LINE",
  "LEARNED_SPELL_IN_TAB",
}
local GOSSIP_EVENTS = { "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_LOG_UPDATE" }
-- (books, letters and plaques: the game's book window, where the setting says)
local BOOK_EVENTS = { "ITEM_TEXT_BEGIN", "ITEM_TEXT_TRANSLATION", "ITEM_TEXT_READY", "ITEM_TEXT_CLOSED" }
local removed = {}

local function registered(f, event)
  local ok, on = pcall(f.IsEventRegistered, f, event)
  return ok and on
end

function C.mute()
  if next(removed) then return end
  for _, spec in ipairs({
    { QuestFrame, QUEST_EVENTS },
    { GossipFrame, GOSSIP_EVENTS },
    { CustomGossipFrameManager, { "GOSSIP_SHOW", "GOSSIP_CLOSED" } },
    { ns.settings.books ~= false and ItemTextFrame or nil, BOOK_EVENTS },
  }) do
    local f, events = spec[1], spec[2]
    if f then
      local list = {}
      for _, e in ipairs(events) do
        if registered(f, e) then
          f:UnregisterEvent(e)
          table.insert(list, e)
        end
      end
      removed[f] = list
    end
  end
end

function C.unmute()
  for f, list in pairs(removed) do
    for _, e in ipairs(list) do
      f:RegisterEvent(e)
    end
  end
  wipe(removed)
end

function C.muted() return next(removed) ~= nil end
-- (the books Palaver's: the game's book window muted)
local function books() return ItemTextFrame ~= nil and removed[ItemTextFrame] ~= nil end

-- ── the conversation's state ─────────────────────────────────────────────────
local shown = 0 -- pages shown so far: a close waits to see if another comes
local expecting = 0 -- until when the player's last answer may bring a page
local continuing = false -- the game said the interaction goes on elsewhere
local handedOver = false -- an error gave the rest of the session to Blizzard
local picked -- what the player last picked: a quest, or an option (a vendor's...)
C.kind = nil

local function now() return GetTime() end

-- Still talking to an NPC the way a quest or a gossip does?
local function talking()
  local M, T = C_PlayerInteractionManager, Enum and Enum.PlayerInteractionType
  if not (M and M.IsInteractingWithNpcOfType and T) then return false end
  return M.IsInteractingWithNpcOfType(T.Gossip) or M.IsInteractingWithNpcOfType(T.QuestGiver)
end

local keys -- the keyboard listener (below)

-- The panel put away, the conversation left as it is.
function C.hide()
  if P.shown() then sound("IG_QUEST_LIST_CLOSE") end
  P.hide()
  C.kind = nil
  continuing = false
  picked = nil
  if keys then keys.off() end
  ns.camera.stop()
  ns.hud.show()
end

-- A close the game sent: acted on a moment later, if no page came since and
-- the NPC is done (else once more, a little later: a gossip coming back
-- after a quest is handed in takes the server a moment).
local function closeSoon(tries)
  local mark = shown
  local delay = now() < expecting and 0.5 or 0.15
  C_Timer.After(delay, function()
    if shown ~= mark or not P.shown() then return end
    if not continuing and talking() and (tries or 0) < 3 then return closeSoon((tries or 0) + 1) end
    C.hide()
  end)
end

-- ── a page shown ─────────────────────────────────────────────────────────────
-- (an error while drawing one: kept, said once, and this conversation, with
-- the rest of the session's, given back to Blizzard's windows)
local replay
-- (an error kept for /palaver errors, the last five)
-- (stack: where it was thrown, when the caller caught it with xpcall)
function C.keep(err, event, stack)
  local log = PalaverErrors or {}
  PalaverErrors = log
  stack = stack or (debugstack and debugstack(3) or "")
  table.insert(log, 1, { at = time(), event = event, err = tostring(err), stack = stack })
  while #log > 5 do
    table.remove(log)
  end
end

local function failed(err, event, ...)
  C.keep(err, event)
  handedOver = true
  pcall(ns.hud.show, true)
  pcall(ns.camera.stop)
  pcall(P.hide)
  if keys then pcall(keys.off) end
  C.unmute()
  replay(event, ...)
  say(
    L["an error stopped this page, so the game's own window takes over until you reload. /palaver errors shows what went wrong."]
  )
end

local function show(event, read, ...)
  local was = P.shown()
  local ok, err = pcall(function()
    local page = read()
    P.show(page)
    C.kind = page.kind
  end)
  if not ok then return failed(err, event, ...) end
  shown = shown + 1
  continuing = false
  if not was then sound("IG_QUEST_LIST_OPEN") end
  if keys then keys.on() end
  -- (the interface hidden before the camera moves: a camera that fails never
  -- costs the conversation its hidden interface, Camera.lua's guard)
  ns.hud.hide()
  if C.kind ~= "book" then ns.camera.start() end
end

-- Blizzard's own handlers, fed the event Palaver could not show.
replay = function(event, ...)
  if event == "GOSSIP_SHOW" then
    if CustomGossipFrameManager and CustomGossipFrameManager.HandleOpenEvent then
      CustomGossipFrameManager:HandleOpenEvent(...)
    elseif GossipFrame and GossipFrame:GetScript("OnEvent") then
      GossipFrame:GetScript("OnEvent")(GossipFrame, event, ...)
    end
  elseif event:find("^ITEM_TEXT_") then
    if ItemTextFrame and ItemTextFrame:GetScript("OnEvent") then
      ItemTextFrame:GetScript("OnEvent")(ItemTextFrame, event, ...)
    end
  elseif QuestFrame and QuestFrame:GetScript("OnEvent") then
    QuestFrame:GetScript("OnEvent")(QuestFrame, event, ...)
  end
end

-- ── the game's events ────────────────────────────────────────────────────────
local E = CreateFrame("Frame")
local ON = {}

function ON.GOSSIP_SHOW(textureKit)
  -- (Forever's own gossip screens, a picker or a guide: Blizzard's)
  local M = CustomGossipFrameManager
  if M and M.GetHandler and textureKit and M:GetHandler(textureKit) then return M:HandleOpenEvent(textureKit) end
  local only = G.skipGossip()
  if only then return C_GossipInfo.SelectOptionByIndex(only) end
  show("GOSSIP_SHOW", G.gossip, textureKit)
end

function ON.GOSSIP_CLOSED(interactionIsContinuing)
  if interactionIsContinuing then
    continuing = true
    -- (the interface back before the window an option opens: its coming back
    -- would close that window. A quest picked comes to the panel: hidden on.)
    if picked ~= "quest" then ns.hud.show(true) end
  end
  closeSoon()
end

function ON.QUEST_GREETING() show("QUEST_GREETING", G.greeting) end

function ON.QUEST_DETAIL(questStartItemID)
  if G.startedFromItem(questStartItemID) then
    if PlayAutoAcceptQuestSound then PlayAutoAcceptQuestSound() end
    CloseQuest()
    return
  end
  show("QUEST_DETAIL", G.detail, questStartItemID)
end

function ON.QUEST_PROGRESS() show("QUEST_PROGRESS", G.progress) end
function ON.QUEST_COMPLETE() show("QUEST_COMPLETE", G.complete) end
function ON.QUEST_FINISHED() closeSoon() end

-- (an item's name or icon that came late: the page again, its choice kept)
function ON.QUEST_ITEM_UPDATE()
  local read = C.kind == "detail" and G.detail
    or C.kind == "progress" and G.progress
    or C.kind == "complete" and G.complete
  if not (read and P.shown()) then return end
  local choice = P.choice
  show("QUEST_ITEM_UPDATE", read)
  if choice then P.choose(choice) end
end

-- A book, a letter, a plaque: its page when the game has it ready (the begin
-- only says one comes), a word while the game translates it, the panel away
-- when the game closes it.
function ON.ITEM_TEXT_READY()
  if books() then show("ITEM_TEXT_READY", G.book) end
end
function ON.ITEM_TEXT_TRANSLATION(delay)
  if books() then show("ITEM_TEXT_TRANSLATION", G.translating, delay) end
end
function ON.ITEM_TEXT_CLOSED()
  if books() and C.kind == "book" then C.hide() end
end

-- (the marks on the rewards: an item the game had yet to tell, or a change
-- in what the character wears)
function ON.GET_ITEM_INFO_RECEIVED()
  if P.waiting and P.shown() then P.remark() end
end
function ON.PLAYER_EQUIPMENT_CHANGED()
  if P.shown() then P.remark() end
end

function ON.QUEST_LOG_UPDATE()
  if not P.shown() then return end
  if C.kind == "gossip" then
    show("QUEST_LOG_UPDATE", G.gossip)
  elseif C.kind == "greeting" then
    show("QUEST_LOG_UPDATE", G.greeting)
  end
end

-- Windows a gossip opens: the panel steps aside, the NPC still spoken to.
for _, event in ipairs({
  "MERCHANT_SHOW",
  "TRAINER_SHOW",
  "TAXIMAP_OPENED",
  "BANKFRAME_OPENED",
  "AUCTION_HOUSE_SHOW",
  "PET_STABLE_SHOW",
  "GUILD_REGISTRAR_SHOW",
  "PETITION_SHOW",
  "TABARD_FRAME_OPEN",
  "CONFIRM_BINDER",
  "CONFIRM_TALENT_WIPE",
  "BATTLEFIELDS_SHOW",
}) do
  ON[event] = function()
    if P.shown() then
      continuing = true
      C.hide()
    end
  end
end

for _, event in ipairs({ "LOADING_SCREEN_ENABLED", "PLAYER_LEAVING_WORLD" }) do
  ON[event] = function() C.hide() end
end

-- (the camera stays through a fight, as DialogueUI's does)
function ON.PLAYER_REGEN_DISABLED()
  if keys then keys.off() end
end
function ON.PLAYER_REGEN_ENABLED()
  if keys and P.shown() then keys.on() end
end

local CONVERSATION = {
  "GOSSIP_SHOW",
  "GOSSIP_CLOSED",
  "QUEST_GREETING",
  "QUEST_DETAIL",
  "QUEST_PROGRESS",
  "QUEST_COMPLETE",
  "QUEST_FINISHED",
  "QUEST_ITEM_UPDATE",
  "QUEST_LOG_UPDATE",
  "ITEM_TEXT_READY",
  "ITEM_TEXT_TRANSLATION",
  "ITEM_TEXT_CLOSED",
}

E:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= addonName then return end
    PalaverSettings = PalaverSettings or {}
    -- (settings saved before version 2 held hideUI off by default, not by
    -- choice: on, as the default became, 18 October 2026. Before version 3
    -- the camera the same: on, as DialogueUI's, 22 October 2026)
    if PalaverSettings.enabled ~= nil then
      local version = PalaverSettings.version or 1
      if version < 2 then PalaverSettings.hideUI = true end
      if version < 3 then PalaverSettings.camera = true end
      PalaverSettings.version = math.max(version, 3)
    end
    for k, v in pairs(DEFAULTS) do
      if PalaverSettings[k] == nil then PalaverSettings[k] = v end
    end
    ns.settings = PalaverSettings
    ns.camera.recover()
    return
  end
  -- (the camera put back whatever happens: Palaver on or off, at a logout,
  -- a quit or a camp's countdown, as DialogueUI does)
  if event == "PLAYER_LOGOUT" or event == "PLAYER_QUITING" or event == "PLAYER_CAMPING" then return ns.camera.stop() end
  if event == "PLAYER_LOGIN" then
    ns.createSettingsPanel()
    return C.start()
  end
  if handedOver or not C.muted() then return end
  local fn = ON[event]
  if fn then fn(...) end
end)
E:RegisterEvent("ADDON_LOADED")
E:RegisterEvent("PLAYER_LOGIN")
E:RegisterEvent("PLAYER_LOGOUT")
pcall(E.RegisterEvent, E, "PLAYER_QUITING")
pcall(E.RegisterEvent, E, "PLAYER_CAMPING")
for event in pairs(ON) do
  pcall(E.RegisterEvent, E, event) -- (an event one game lacks)
end
for _, event in ipairs(CONVERSATION) do
  pcall(E.RegisterEvent, E, event)
end

-- Another addon that does this already: it keeps the conversations.
local function rival()
  local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
  for _, name in ipairs(RIVALS) do
    if loaded and loaded(name) then return name end
  end
end

function C.start()
  local other = rival()
  if other then
    say(
      L["%s already shows your conversations, so Palaver stays out of its way. Turn one of them off to choose."]:format(
        other
      )
    )
    return
  end
  if ns.settings.enabled then C.mute() end
end

-- ── what the player does ─────────────────────────────────────────────────────
-- (each answer may bring a page: a close the game sends meanwhile waits)
local function answered() expecting = now() + 1 end

function C.act(which)
  local page = P.page
  local a = page and page.actions and page.actions[which]
  if not a or a.disabled then return end
  if page.kind == "complete" and which == "primary" then
    if not G.turnIn(P.choice) then
      sound("IG_QUEST_LOG_ABANDON_QUEST")
      return
    end
  else
    a.run()
  end
  if which == "secondary" then sound("IG_QUEST_CANCEL") end
  answered()
end

function C.pick(n)
  local r = P.page and P.page.rows and P.page.rows[n]
  if not r then return end
  picked = r.kind
  r.pick()
  answered()
end

function C.choose(n)
  if P.choose(n) then sound("IG_MAINMENU_OPTION_CHECKBOX_ON") end
end

-- Escape: the conversation ended, as Blizzard's windows end it when closed.
function C.close()
  if C.kind == "gossip" then
    G.closeGossip()
  elseif C.kind == "book" then
    CloseItemText()
  elseif C.kind then
    G.closeQuest()
  end
  C.hide()
end

-- ── the keyboard ─────────────────────────────────────────────────────────────
-- Space or Enter answers yes (the lit button), Escape goodbye, 1 to 9 a line
-- or a reward. On the key's release, and only on the page it was pressed on:
-- a key held down never accepts the next quest. Never in combat (the game
-- keeps the keyboard then), never while typing or with a modifier held.
keys = {}
-- (no parent: it keeps listening while the game's interface is hidden)
local listener = CreateFrame("Frame", "PalaverKeys")
listener:SetAllPoints(UIParent)
listener:Hide()
local down -- { key, page }
-- (one of the game's own questions open, a paid turn-in's: Escape is its)
local function popup()
  for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
    -- selene: allow(global_usage)
    local f = _G["StaticPopup" .. i]
    if f and f:IsShown() then return true end
  end
  return false
end
local function mine(key)
  if key == "ESCAPE" then return not popup() end
  if not (ns.settings and ns.settings.keys) then return false end
  local page = P.page
  if not page then return false end
  if key == "SPACE" or key == "ENTER" then
    local a = page.actions and page.actions.primary
    return a ~= nil and not a.disabled
  end
  if key == "BACKSPACE" then return page.actions ~= nil and page.actions.back ~= nil end
  local n = tonumber(key)
  if n and n >= 1 and n <= 9 then return (page.rows and page.rows[n] ~= nil) or (P.choosing and P.cards[n] ~= nil) end
  return false
end
listener:SetScript("OnKeyDown", function(self, key)
  local typing = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
  local take = not typing and not IsModifierKeyDown() and mine(key)
  if not InCombatLockdown() then self:SetPropagateKeyboardInput(not take) end
  if take then down = { key = key, page = shown } end
end)
listener:SetScript("OnKeyUp", function(_, key)
  local d = down
  down = nil
  if not (d and d.key == key and d.page == shown and P.shown()) then return end
  if key == "ESCAPE" then return C.close() end
  if key == "SPACE" or key == "ENTER" then
    -- (a long page read to its end first, where the setting says so)
    if ns.settings.readOn ~= false and P.readOn() then return end
    return C.act("primary")
  end
  if key == "BACKSPACE" then return C.act("back") end
  local n = tonumber(key)
  if P.page.rows and P.page.rows[n] then return C.pick(n) end
  C.choose(n)
end)
function keys.on()
  if InCombatLockdown() then return end
  listener:Show()
  listener:EnableKeyboard(true)
end
function keys.off()
  down = nil
  if InCombatLockdown() then return end
  listener:SetPropagateKeyboardInput(true)
  listener:EnableKeyboard(false)
  listener:Hide()
end

-- ── /palaver ─────────────────────────────────────────────────────────────────
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

SLASH_PALAVER1 = "/palaver"
-- A setting changed, from /palaver or the game's Options page (Settings.lua),
-- and what it changes at once: Palaver on or off, the panel's size, the
-- camera put back, the rewards' marks worked out again.
function C.set(key, value)
  local s = ns.settings
  s[key] = value
  if key == "enabled" then
    if value and not rival() then
      C.mute()
    else
      if P.shown() then C.close() end
      C.unmute()
    end
  elseif key == "scale" then
    P.reposition()
  elseif key == "camera" then
    if not value then ns.camera.stop() end
  elseif key == "value" or key == "upgrades" then
    if P.shown() then P.remark() end
  elseif key == "hideUI" then
    if value and P.shown() then
      ns.hud.hide()
    else
      ns.hud.show()
    end
  elseif key == "books" then
    -- (the game's book window muted or not, the rest as it was)
    if not value and C.kind == "book" then C.close() end
    if C.muted() then
      C.unmute()
      C.mute()
    end
  end
end

SlashCmdList.PALAVER = function(msg)
  local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
  local s = ns.settings
  if cmd == "on" or cmd == "off" then
    C.set("enabled", cmd == "on")
    say(s.enabled and L["On: your conversations are shown here."] or L["Off: the game's own windows are back."])
  elseif cmd == "scale" and tonumber(arg) then
    C.set("scale", clamp(tonumber(arg), 0.7, 1.5))
    say(L["Scale %s."]:format(s.scale))
  elseif cmd == "font" and tonumber(arg) then
    C.set("font", clamp(math.floor(tonumber(arg)), 12, 22))
    say(L["Text size %d."]:format(s.font))
  elseif cmd == "keys" then
    C.set("keys", not s.keys)
    say(s.keys and L["Keys on: Space, Escape and 1 to 9 answer."] or L["Keys off: only the mouse answers."])
  elseif cmd == "books" then
    C.set("books", not s.books)
    say(
      s.books and L["Books on: books, letters and plaques open here."]
        or L["Books off: the game's own book window is back."]
    )
  elseif cmd == "hud" then
    C.set("hideUI", not s.hideUI)
    say(
      s.hideUI and L["Interface hidden while you talk or read: only the panel stays."]
        or L["Interface kept while you talk or read."]
    )
  elseif cmd == "camera" then
    C.set("camera", not s.camera)
    say(
      s.camera and L["Camera on: the view moves in on whoever speaks."]
        or L["Camera off: the view stays as you set it."]
    )
  elseif cmd == "value" then
    C.set("value", not s.value)
    say(
      s.value and L["Best value on: a coin marks the reward that sells for most."]
        or L["Best value off: no coin on the rewards."]
    )
  elseif cmd == "upgrades" then
    C.set("upgrades", not s.upgrades)
    say(
      s.upgrades and L["Upgrades on: an arrow marks the reward best for you, by the stats your class wants."]
        or L["Upgrades off: no arrow on the rewards."]
    )
  elseif cmd == "reset" then
    s.point = nil
    C.set("scale", DEFAULTS.scale)
    C.set("font", DEFAULTS.font)
    say(L["The panel is back in its place, at its size."])
  elseif cmd == "errors" then
    local last = PalaverErrors and PalaverErrors[1]
    say(last and (last.event .. ": " .. last.err) or L["No error so far."])
  elseif cmd == "settings" or cmd == "options" then
    if not ns.openSettings() then say(L["No settings page in this client."]) end
  else
    say(
      L["/palaver on or off, scale 0.7 to 1.5, font 12 to 22, keys, books, hud, camera, value, upgrades, reset, errors, settings."]
    )
  end
end
