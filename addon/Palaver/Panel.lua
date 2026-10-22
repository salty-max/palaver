-- The panel: DialogueUI's way of talking to an NPC (a panel beside them, the
-- NPC left in view, the text large, the answers as lines, two buttons with
-- their keys) in the family's window (the kit's K.gameWindow, its body dark:
-- the user's call, 18 October 2026, in place of the gold dialog box). As
-- Blizzard's quest and gossip windows have it: the speaker's face in the
-- window's corner, their name in its title bar; a quest's title in gold
-- beside the face, the text on the kit's panel below, the buttons with their
-- keys under it. Mock-ups: ~/code/wow-addons/ideas/palaver/ (G, I).
--
-- It only shows: what the player does goes to Core (ns.core), which answers
-- the game. Hiding it never ends a conversation (the game's own windows end
-- one when hidden, which is how a trainer's or a vendor's window would be
-- cut short): only the player's Goodbye, Decline or Escape does.
local _, ns = ...
local K = ns.kit
local L = K.L
local T = K.T
local P = {}
ns.panel = P

local WIDTH = 400
local HEIGHT = 424 -- every page the same height: Blizzard's quest window's (TBC on, interface units)
local EDGE = 8 -- the panel's and the buttons' distance from the window's sides
local TOP = 62 -- the panel's top, under the window's corner face (Yonder's: 58)
local INNER = 12 -- the text's distance from the panel's sides
local BUTTON_H, BUTTON_GAP = 32, 12
local FOOT = EDGE + BUTTON_H + 8 -- the panel's bottom, above the buttons
local BOOK_ICON = "Interface\\QuestFrame\\UI-QuestLog-BookIcon"
local TEXT = T.text
local KEY_BADGE = { 0, 0, 0, 0.6 }

local frame, scroll, child
local pools = { para = {}, heading = {}, row = {}, card = {}, line = {} }
local used = {}
P.rows, P.cards = {}, {}

local function fontSize() return ns.settings and ns.settings.font or 15 end

-- ── pieces ───────────────────────────────────────────────────────────────────
-- A key as the buttons and rows show it: a small dark plate, a thin gold edge.
local function keyBadge(parent)
  local b = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  b:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  b:SetBackdropColor(unpack(KEY_BADGE))
  b:SetBackdropBorderColor(T.accent[1], T.accent[2], T.accent[3], 0.55)
  b.text = K.label(b, K.BODY_FONT, 10, TEXT)
  b.text:SetPoint("CENTER", 0, 0)
  b:SetHeight(18)
  function b:SetKey(key)
    self.text:SetText(key)
    self:SetWidth(math.max(18, self.text:GetStringWidth() + 10))
  end
  return b
end

-- A footer button: dark, a gold edge (the primary one lit), its key in a badge.
local function button(primary)
  local b = CreateFrame("Button", nil, frame, "BackdropTemplate")
  b:SetHeight(BUTTON_H)
  b:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  b.primary = primary
  b.badge = keyBadge(b)
  b.badge:SetPoint("LEFT", 9, 0)
  b.label = K.label(b, K.BODY_FONT, 13, TEXT)
  b.label:SetPoint("LEFT", b.badge, "RIGHT", 9, 0)
  b.label:SetPoint("RIGHT", -8, 0)
  b.label:SetWordWrap(false)
  function b:Paint(lit)
    local off = self.disabled
    if self.primary and not off then
      self:SetBackdropColor(0.29, 0.20, 0.09, lit and 1 or 0.92)
      self:SetBackdropBorderColor(0.9, 0.75, 0.45, 1)
      self.label:SetTextColor(1, 0.88, 0.63)
    else
      self:SetBackdropColor(0.08, 0.07, 0.05, lit and 1 or 0.88)
      if off then
        self:SetBackdropBorderColor(0.35, 0.30, 0.24, 1)
      elseif lit then
        self:SetBackdropBorderColor(0.80, 0.66, 0.44, 1)
      else
        self:SetBackdropBorderColor(0.58, 0.49, 0.36, 1)
      end
      self.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3], off and 0.45 or 1)
    end
  end
  b:SetScript("OnEnter", function(self) self:Paint(true) end)
  b:SetScript("OnLeave", function(self) self:Paint(false) end)
  b:SetScript("OnClick", function(self)
    if not self.disabled and self.run then self.run() end
  end)
  return b
end

local function take(kind, make)
  local list = pools[kind]
  used[kind] = (used[kind] or 0) + 1
  local w = list[used[kind]]
  if not w then
    w = make()
    list[used[kind]] = w
  end
  w:Show()
  return w
end

local function releaseAll()
  for kind, list in pairs(pools) do
    for _, w in ipairs(list) do
      w:Hide()
      w:ClearAllPoints()
    end
    used[kind] = 0
  end
  wipe(P.rows)
  wipe(P.cards)
end

-- ── the frame ────────────────────────────────────────────────────────────────
-- The family's window, without a parent: the panel stays when the game's
-- interface is hidden around it (Hud.lua, DialogueUI's way), at the
-- interface's scale all the same (place). Where the game has no such window,
-- the kit's dialog box. Its close button, or anything else that hides it,
-- ends the conversation as Escape does (Core's close).
local quietly = false -- (Palaver hiding it itself: no conversation to end)
local function build()
  frame = K.gameWindow("PalaverFrame", "")
  P.windowed = frame ~= nil
  if not frame then
    frame = K.dialog("PalaverFrame", "")
    frame.barLabel = K.label(frame, K.TITLE_FONT, 16, T.accent)
    frame.barLabel:SetPoint("TOP", 0, -16)
  end
  frame:SetParent(nil)
  frame:SetSize(WIDTH, HEIGHT)
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint(1)
    if ns.settings then ns.settings.point = { point, relPoint, x, y } end
    ns.camera.moved()
  end)
  frame:HookScript("OnHide", function()
    if not quietly then ns.core.close() end
  end)
  frame:Hide()

  -- a quest's title beside the face, a book's page there in a small line
  frame.title = K.label(frame, K.TITLE_FONT, 18, T.gold)
  frame.title:SetPoint("LEFT", frame, "TOPLEFT", 66, -(21 + TOP) / 2)
  frame.title:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
  frame.title:SetMaxLines(2)
  frame.kicker = K.label(frame, K.BODY_FONT, 12, T.soft)
  frame.kicker:SetPoint("LEFT", frame, "TOPLEFT", 66, -(21 + TOP) / 2)
  frame.kicker:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
  frame.kicker:SetWordWrap(false)

  frame.sheet = K.panel(frame)
  frame.sheet:SetPoint("TOPLEFT", EDGE, -TOP)
  frame.sheet:SetPoint("BOTTOMRIGHT", -EDGE, FOOT)
  scroll = K.scrollArea(frame.sheet, WIDTH - 2 * EDGE - 2 * INNER, "PalaverScroll")
  scroll:SetPoint("TOPLEFT", INNER, -10)
  scroll:SetPoint("RIGHT", frame.sheet, "RIGHT", -INNER, 0)
  child = scroll.child

  frame.primary = button(true)
  frame.secondary = button(false)
  -- a book's page back: a square button of the footer's, the spellbook's
  -- arrow in it, as the game's book window has it (mock: book page)
  frame.back = button(false)
  frame.back.badge:Hide()
  frame.back.label:Hide()
  frame.back:SetWidth(BUTTON_H)
  frame.back.arrow = frame.back:CreateTexture(nil, "ARTWORK")
  frame.back.arrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
  frame.back.arrow:SetSize(BUTTON_H - 2, BUTTON_H - 2)
  frame.back.arrow:SetPoint("CENTER")
  frame.back:HookScript("OnEnter", function(self)
    local tip = P.tooltip()
    tip:SetOwner(self, "ANCHOR_TOP")
    tip:SetText(self.tip or "")
    if ns.settings and ns.settings.keys ~= false then
      tip:AddLine(ns.game.word("KEY_BACKSPACE", "Backspace"), T.soft[1], T.soft[2], T.soft[3])
    end
    tip:Show()
  end)
  frame.back:HookScript("OnLeave", function() P.tooltip():Hide() end)
  frame.hint = K.label(frame.sheet, K.BODY_FONT, 11, T.soft)
  frame.hint:SetPoint("BOTTOMLEFT", INNER, 8)
  frame.hint:SetPoint("RIGHT", frame.sheet, "RIGHT", -INNER, 0)
end

-- The title bar's words: the speaker's name, a book's.
local function setBar(text)
  P.bar = text
  if frame.barLabel then return frame.barLabel:SetText(text) end
  if frame.SetTitle then
    frame:SetTitle(text)
  elseif type(frame.TitleText) == "table" then
    frame.TitleText:SetText(text)
  end
end

-- The face in the window's corner: the speaker's, else the book's.
local function setFace(unit)
  if not P.windowed then return end
  if unit and UnitExists(unit) and frame.SetPortraitToUnit then
    frame:SetPortraitToUnit(unit)
  elseif frame.SetPortraitToAsset then
    frame:SetPortraitToAsset(BOOK_ICON)
  end
end

local function place()
  frame:ClearAllPoints()
  local p = ns.settings and ns.settings.point
  if p then
    frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    -- (DialogueUI's place: the right of the screen, a little above its middle)
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -UIParent:GetWidth() * 0.08, 20)
  end
  -- (the interface's scale, as a window of the game's has it, then Palaver's)
  frame:SetScale(UIParent:GetScale() * (ns.settings and ns.settings.scale or 1))
end

-- The tooltip a card or a button shows: the game's, or Palaver's own while
-- the game's interface is hidden (the game's goes with it).
local own
function P.tooltip()
  if not (ns.hud and ns.hud.hidden()) then return GameTooltip end
  if not own then
    own = CreateFrame("GameTooltip", "PalaverTooltip", nil, "GameTooltipTemplate")
    own:SetFrameStrata("TOOLTIP")
  end
  own:SetScale(UIParent:GetScale())
  return own
end

-- ── the page's content, top to bottom ────────────────────────────────────────
local y, inner

local function para(text, color, size)
  if not text or text == "" then return end
  local fs = take("para", function() return K.label(child, K.BODY_FONT, 15, TEXT) end)
  fs:SetFont(K.BODY_FONT, size or fontSize(), "")
  fs:SetTextColor(unpack(color or TEXT))
  fs:SetWidth(inner)
  fs:SetSpacing(4)
  fs:SetText(text)
  fs:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
  y = y + fs:GetStringHeight() + 10
end

-- A quest's facts, a line above its text: its level in the colour of how hard
-- it is for the character, its kind in gold (the game's own names), the group
-- the game suggests, its place in its chain.
local function facts(f)
  if not f then return end
  local bits = {}
  if (f.level or 0) > 0 then
    local text = ns.game.word("LEVEL", "Level") .. " " .. f.level
    local c = GetQuestDifficultyColor and GetQuestDifficultyColor(f.level)
    if c and c.r then text = ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, text) end
    table.insert(bits, text)
  end
  local kind = (f.kind or 0) > 0 and ns.questTypes[f.kind]
  if kind then table.insert(bits, K.hex(T.gold) .. kind .. "|r") end
  if f.group then
    table.insert(bits, ns.game.word("QUEST_SUGGESTED_GROUP_NUM", "Suggested Players [%d]"):format(f.group))
  end
  if (f.of or 0) > 1 then table.insert(bits, L["Part %d of %d"]:format(f.part, f.of)) end
  if #bits == 0 then return end
  P.factsLine = table.concat(bits, "  \194\183  ")
  para(P.factsLine, T.soft, 12)
  y = y - 2
end

local function heading(text)
  local h = take("heading", function()
    local f = CreateFrame("Frame", nil, child)
    f:SetHeight(24)
    f.text = K.label(f, K.TITLE_FONT, 16, T.gold)
    f.text:SetPoint("BOTTOMLEFT", 0, 5)
    f.line = K.rule(f)
    f.line:SetPoint("BOTTOMLEFT")
    f.line:SetPoint("BOTTOMRIGHT")
    return f
  end)
  h:SetWidth(inner)
  h.text:SetText(text)
  y = y + 4
  h:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
  y = y + 24 + 8
end

-- A line the player may pick: its number's key, the game's icon, the words.
local function row(r, n)
  local b = take("row", function()
    local f = CreateFrame("Button", nil, child)
    f.badge = keyBadge(f)
    f.badge:SetPoint("TOPLEFT", 0, -1)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(16, 16)
    f.text = K.label(f, K.BODY_FONT, 15, TEXT)
    f.text:SetSpacing(2)
    f:SetHighlightTexture(K.HIGHLIGHT, "ADD")
    f:SetScript("OnClick", function(self) ns.core.pick(self.n) end)
    return f
  end)
  local keyed = ns.settings and ns.settings.keys ~= false and n <= 9
  b.badge:SetShown(keyed)
  if keyed then b.badge:SetKey(tostring(n)) end
  local left = keyed and 26 or 0
  b.icon:ClearAllPoints()
  b.icon:SetPoint("TOPLEFT", left, -1)
  b.icon:SetTexture(r.icon)
  local v = r.faded and 0.5 or 1
  b.icon:SetVertexColor(v, v, v)
  b.text:ClearAllPoints()
  b.text:SetPoint("TOPLEFT", left + 22, 0)
  b.text:SetFont(K.BODY_FONT, fontSize(), "")
  b.text:SetWidth(inner - left - 22)
  b.text:SetText(r.text or "")
  local c = r.faded and T.soft or TEXT
  b.text:SetTextColor(c[1], c[2], c[3])
  local h = math.max(20, b.text:GetStringHeight() + 4)
  b:SetSize(inner, h)
  b:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
  b.n = n
  P.rows[n] = b
  y = y + h + 6
end

-- An item card: the bag's slot and the item's name, half the width.
local function card(item, x, chooseIndex)
  local c = take("card", function()
    local f = CreateFrame("Button", nil, child, "BackdropTemplate")
    f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16 })
    f.slot = K.slot(f, 34)
    f.slot:SetPoint("LEFT", 3, 0)
    f.slot:EnableMouse(false)
    f.name = K.label(f, K.BODY_FONT, 13, TEXT)
    f.name:SetPoint("LEFT", f.slot, "RIGHT", 9, 0)
    f.name:SetPoint("RIGHT", -6, 0)
    f.name:SetMaxLines(2)
    -- the reward chosen: the game's highlight, two boxes in a 256 by 64
    -- texture made for its own buttons (the icon's, 9 to 43 square, the
    -- name's, 49 to 151 by 7 to 44), each cut out and laid on the card's own
    -- parts, the name's in three so its corners keep their shape. Over the
    -- slot (a frame of its own: the card's textures would sit under it).
    f.chosen = CreateFrame("Frame", nil, f.slot)
    f.chosen:SetAllPoints(f)
    local function lit(l, r, t, b)
      local tex = f.chosen:CreateTexture(nil, "OVERLAY")
      tex:SetTexture("Interface\\QuestFrame\\UI-QuestItemHighlight")
      tex:SetTexCoord(l / 256, r / 256, t / 64, b / 64)
      tex:SetBlendMode("ADD")
      return tex
    end
    local icon = lit(9, 44, 9, 44)
    icon:SetPoint("TOPLEFT", f.slot, "TOPLEFT", -1, 1)
    icon:SetPoint("BOTTOMRIGHT", f.slot, "BOTTOMRIGHT", 1, -1)
    local left, mid, right = lit(49, 59, 7, 45), lit(59, 141, 7, 45), lit(141, 152, 7, 45)
    left:SetSize(10, 38)
    left:SetPoint("TOPLEFT", 40, -1)
    right:SetSize(11, 38)
    right:SetPoint("TOPRIGHT", -1, -1)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
    mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    -- the marks (Rewards.lua): the game's green arrow, pointing up, over the
    -- slot's corner for the best for the character, its gold coin in the
    -- card's corner for the one that sells for most. The arrow is the slot's
    -- own: a frame draws over its parent's textures, whatever their layer,
    -- so the card's would sit under the item.
    f.best = f.slot:CreateTexture(nil, "OVERLAY", nil, 7)
    f.best:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
    f.best:SetTexCoord(0, 1, 1, 0)
    f.best:SetSize(18, 18)
    f.best:SetPoint("TOPLEFT", -5, 6)
    f.value = f:CreateTexture(nil, "OVERLAY", nil, 7)
    f.value:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    f.value:SetSize(13, 13)
    f.value:SetPoint("TOPRIGHT", -4, -4)
    f:SetHighlightTexture(K.HIGHLIGHT, "ADD")
    f:SetScript("OnEnter", function(self) ns.game.itemTooltip(self, self.item, self.notes) end)
    f:SetScript("OnLeave", function() P.tooltip():Hide() end)
    f:SetScript("OnClick", function(self)
      if self.chooseIndex then ns.core.choose(self.chooseIndex) end
    end)
    return f
  end)
  local w = math.floor((inner - 10) / 2)
  c:SetSize(w, 40)
  c:SetBackdropColor(0, 0, 0, 0.35)
  K.setSlot(c.slot, item.icon, item.count, item.quality)
  -- (one the character can't use: red, as the game's own window shows it)
  if item.usable == false then c.slot.icon:SetVertexColor(0.9, 0, 0) end
  c.best:Hide()
  c.value:Hide()
  c.notes = nil
  c.name:SetPoint("RIGHT", -6, 0)
  local name = item.name or ""
  c.name:SetText(name)
  local q = item.quality and item.quality >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
  if q then
    c.name:SetTextColor(q.r, q.g, q.b)
  else
    c.name:SetTextColor(unpack(TEXT))
  end
  c.item = item
  c.chooseIndex = chooseIndex
  c.chosen:Hide()
  c:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
  if chooseIndex then P.cards[chooseIndex] = c end
  return c
end

local function cards(list, chooseFrom)
  local w = math.floor((inner - 10) / 2)
  for i, item in ipairs(list) do
    local col = (i - 1) % 2
    card(item, col * (w + 10), chooseFrom and i or nil)
    if col == 1 or i == #list then y = y + 46 end
  end
end

-- A label and its value, side by side: Experience 625, Money 1s 75c.
local function lines(pairsList)
  local w = math.floor((inner - 10) / 2)
  for i, pair in ipairs(pairsList) do
    local l = take("line", function()
      local f = CreateFrame("Frame", nil, child)
      f:SetHeight(18)
      f.label = K.label(f, K.BODY_FONT, 13, T.soft)
      f.label:SetPoint("LEFT")
      f.value = K.label(f, K.BODY_FONT, 13, TEXT)
      f.value:SetPoint("LEFT", 90, 0)
      return f
    end)
    l:SetWidth(w)
    l.label:SetText(pair[1])
    l.value:SetText(pair[2])
    local col = (i - 1) % 2
    l:SetPoint("TOPLEFT", child, "TOPLEFT", col * (w + 10), -y)
    if col == 1 or i == #pairsList then y = y + 22 end
  end
end

local function rewards(r, choose)
  if not (r and r.any) then return end
  heading(ns.game.word("REWARDS", "Rewards"))
  if #r.choice > 0 then
    if #r.choice > 1 then para(ns.game.word("REWARD_CHOOSE", "Choose your reward"), T.soft, 13) end
    cards(r.choice, #r.choice > 1)
  end
  if #r.given > 0 then
    if #r.choice > 0 then para(ns.game.word("REWARD_ITEMS", "You will also receive"), T.soft, 13) end
    cards(r.given)
  end
  if #r.spells > 0 then cards(r.spells) end
  local l = {}
  if r.xp > 0 then table.insert(l, { ns.game.word("EXPERIENCE_COLON", "Experience"), tostring(r.xp) }) end
  if r.money > 0 then table.insert(l, { ns.game.word("MONEY", "Money"), ns.game.coins(r.money) }) end
  if r.honor > 0 then table.insert(l, { ns.game.word("HONOR", "Honor"), tostring(r.honor) }) end
  if r.title then table.insert(l, { ns.game.word("REWARD_TITLE", "Title"), r.title }) end
  lines(l)
  P.choosing = choose
end

-- ── the marks ────────────────────────────────────────────────────────────────
-- Among two rewards or more to choose from: the best for the character (an
-- arrow) and the one that sells for most (a coin), each saying why on the
-- card's tooltip (Rewards.lua). Asked again when the game tells an item it
-- had yet to (P.waiting: Core.lua's GET_ITEM_INFO_RECEIVED).
local UPGRADE = { 0.1, 1, 0.1 }
P.waiting = false
function P.mark()
  P.waiting = false
  for _, c in pairs(P.cards) do
    c.best:Hide()
    c.value:Hide()
    c.notes = nil
    c.name:SetPoint("RIGHT", -6, 0)
  end
  local r = P.page and P.page.rewards
  local choice = r and r.choice
  if not (choice and #choice > 1) then return end
  local s = ns.settings or {}
  local function note(c, text, color)
    c.notes = c.notes or {}
    table.insert(c.notes, { text, color })
  end
  if s.upgrades ~= false then
    local best, wait = ns.rewards.bestForYou(choice)
    if wait then P.waiting = true end
    local c = best and P.cards[best.index]
    if c then
      c.best:Show()
      note(c, best.why, UPGRADE)
    end
  end
  if s.value ~= false then
    local best, wait = ns.rewards.bestValue(choice)
    if wait then P.waiting = true end
    local c = best and P.cards[best.index]
    if c then
      c.value:Show()
      c.name:SetPoint("RIGHT", -20, 0)
      note(c, L["Sells for the most of these: %s."]:format(ns.game.coins(best.price)), T.gold)
    end
  end
end

-- The marks worked out again (a page shown, an item told, something worn
-- changed). One that fails is no reason to lose the page: the error kept for
-- /palaver errors, the marks left off.
function P.remark()
  local ok, err = pcall(P.mark)
  if ok then return end
  for _, c in pairs(P.cards) do
    c.best:Hide()
    c.value:Hide()
    c.notes = nil
  end
  P.waiting = false
  ns.core.keep(err, "marks")
end

-- ── a page ───────────────────────────────────────────────────────────────────
local function footer(page)
  local a = page.actions or {}
  local both = a.primary and a.secondary
  -- (a book's page back first, a square, the buttons beside it)
  local left = EDGE + (a.back and BUTTON_H + 8 or 0)
  local avail = WIDTH - EDGE - left
  local bw = both and math.floor((avail - BUTTON_GAP) / 2) or avail
  frame.back:ClearAllPoints()
  frame.back:SetShown(a.back ~= nil)
  if a.back then
    frame.back:SetPoint("BOTTOMLEFT", EDGE, EDGE)
    frame.back.tip = a.back.label
    frame.back.disabled = false
    frame.back.run = function() ns.core.act("back") end
    frame.back:Paint(false)
  end
  local keyed = ns.settings and ns.settings.keys ~= false
  for _, spec in ipairs({ { frame.primary, a.primary, "Space" }, { frame.secondary, a.secondary, "Esc" } }) do
    local b, act, key = spec[1], spec[2], spec[3]
    b:ClearAllPoints()
    b:SetShown(act ~= nil)
    if act then
      b:SetWidth(bw)
      b.label:SetText(act.label)
      b.badge:SetShown(keyed)
      b.badge:SetKey(key == "Space" and L["Space"] or L["Esc"])
      b.label:SetPoint("LEFT", keyed and b.badge or b, keyed and "RIGHT" or "LEFT", 9, 0)
      b.disabled = act.disabled and true or false
      b.run = function() ns.core.act(b == frame.primary and "primary" or "secondary") end
      b:Paint(false)
    end
  end
  if both then
    frame.primary:SetPoint("BOTTOMLEFT", left, EDGE)
    frame.secondary:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
  elseif a.primary then
    frame.primary:SetPoint("BOTTOMLEFT", left, EDGE)
  elseif a.secondary then
    frame.secondary:SetPoint("BOTTOMLEFT", left, EDGE)
  end
end

function P.show(page)
  if not frame then build() end
  releaseAll()
  P.page = page
  P.choosing = nil
  P.choice = nil
  P.factsLine = nil
  inner = WIDTH - 2 * EDGE - 2 * INNER - 8
  y = 0

  -- The speaker's face in the corner, their name in the title bar (a quest
  -- from an item, a book: the book's face, its name); a quest's title beside
  -- the face, a book's page there in a small line.
  setFace(page.unit)
  local bar = (page.name and page.name ~= "") and page.name or page.title or ""
  setBar(bar)
  local named = page.title ~= bar and page.title or ""
  frame.title:SetText(named)
  frame.title:SetShown(named ~= "")
  frame.kicker:SetText(page.kicker or "")
  frame.kicker:SetShown(named == "" and (page.kicker or "") ~= "")

  facts(page.facts)
  para(page.text)
  if page.objectives and page.objectives ~= "" then
    heading(ns.game.word("QUEST_OBJECTIVES", "Objectives"))
    para(page.objectives)
  end
  if page.required and (#page.required > 0 or (page.money or 0) > 0) then
    heading(ns.game.word("TURN_IN_ITEMS", "Required items"))
    cards(page.required)
    if (page.money or 0) > 0 then lines({ { ns.game.word("MONEY", "Money"), ns.game.coins(page.money) } }) end
  end
  if page.rows and #page.rows > 0 then
    if page.text and page.text ~= "" then y = y + 4 end
    for i, r in ipairs(page.rows) do
      row(r, i)
    end
  end
  rewards(page.rewards, page.choose)
  P.remark()

  child:SetHeight(math.max(1, y))
  footer(page)
  frame.hint:SetText(page.choose and not P.choice and L["Choose a reward, then complete the quest."] or "")
  frame.hint:SetShown(page.choose and not P.choice)

  -- One height for every page, as Blizzard's quest window (the user's call,
  -- 18 October 2026): its 424 interface units, so it follows the game's UI
  -- scale as every window does (two thirds of the screen did not, and towered
  -- over them); the buttons stay where they were, a long text scrolls.
  if not frame:IsShown() then place() end
  scroll:SetHeight(HEIGHT - TOP - FOOT - 10 - 10 - (page.choose and 16 or 0))
  scroll:SetScript("OnUpdate", nil)
  scroll:ScrollTo(0)
  frame:SetHeight(HEIGHT)
  if not frame:IsShown() then frame:Show() end
  scroll:UpdateThumb()
end

-- ── reading on ───────────────────────────────────────────────────────────────
-- Space or Enter on a page longer than the panel: the text scrolls down a
-- panel's height, less a few lines kept in view, before the key answers
-- (DialogueUI's "scroll down then accept"): no quest accepted with its
-- rewards unseen below. A short slide, a fifth of a second.
local SLIDE = 0.18
local function slide(self, elapsed)
  self.t = self.t + elapsed
  local k = math.min(1, self.t / SLIDE)
  k = 1 - (1 - k) * (1 - k)
  self:ScrollTo(self.from + (self.to - self.from) * k)
  if k >= 1 then self:SetScript("OnUpdate", nil) end
end

-- (true: there was more below, and the text moved to it)
function P.readOn()
  if not (scroll and frame:IsShown()) then return false end
  local range, at = scroll:Range(), scroll:GetVerticalScroll()
  local goal = scroll.to and scroll:GetScript("OnUpdate") and scroll.to or at
  if range - goal < 2 then return false end
  scroll.from, scroll.to, scroll.t = at, math.min(range, goal + scroll:GetHeight() - 48), 0
  scroll:SetScript("OnUpdate", slide)
  return true
end

function P.hide()
  if frame then
    quietly = true
    frame:Hide()
    quietly = false
  end
  P.page = nil
end

function P.shown() return frame ~= nil and frame:IsShown() end

-- The reward chosen (complete page): its card lit, the hint gone.
function P.choose(n)
  if not (P.choosing and P.cards[n]) then return false end
  for i, c in pairs(P.cards) do
    c.chosen:SetShown(i == n)
  end
  P.choice = n
  frame.hint:Hide()
  return true
end

function P.frame() return frame end
function P.reposition()
  if frame and frame:IsShown() then
    place()
    ns.camera.moved()
  end
end

-- (the interface's scale changed: the panel follows, as the game's windows do)
local scaler = CreateFrame("Frame")
for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
  pcall(scaler.RegisterEvent, scaler, event)
end
scaler:SetScript("OnEvent", function() P.reposition() end)
