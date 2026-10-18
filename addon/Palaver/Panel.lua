-- The panel: DialogueUI's way of talking to an NPC (a panel beside them, the
-- NPC left in view, the text large, the answers as lines, two buttons with
-- their keys) in the family's materials: the game's dark dialog box with its
-- gold border (the kit's K.dialog), titles in the display face and gold, the
-- bronze ring around the speaker's face, the bag's slots for items. Mock-ups:
-- ~/code/wow-addons/ideas/palaver/.
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

local WIDTH, PAD, PORTRAIT = 400, 24, 56
local HEADER = 72 -- the portrait and title, above the rule
local BUTTON_H, BUTTON_GAP, FOOTER_GAP = 32, 12, 16
local HEIGHT = 424 -- every page the same height: Blizzard's quest window's (TBC on, interface units)
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
local function build()
  frame = CreateFrame("Frame", "PalaverFrame", UIParent, "BackdropTemplate")
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  frame:SetWidth(WIDTH)
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
  end)
  frame:Hide()

  frame.portrait = K.roundIcon(frame, PORTRAIT, true)
  frame.portrait:SetPoint("TOPLEFT", PAD + 2, -PAD - 2)
  frame.title = K.label(frame, K.TITLE_FONT, 22, T.gold)
  frame.title:SetPoint("TOPLEFT", frame.portrait, "TOPRIGHT", 14, -6)
  frame.title:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
  frame.title:SetMaxLines(2)
  frame.sub = K.label(frame, K.BODY_FONT, 12, T.soft)
  frame.sub:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -6)
  frame.sub:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
  frame.sub:SetWordWrap(false)
  frame.rule = K.rule(frame)
  frame.rule:SetPoint("TOPLEFT", PAD, -PAD - HEADER)
  frame.rule:SetPoint("TOPRIGHT", -PAD, -PAD - HEADER)

  scroll = K.scrollArea(frame, WIDTH - 2 * PAD, "PalaverScroll")
  scroll:SetPoint("TOPLEFT", PAD, -PAD - HEADER - 14)
  scroll:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
  child = scroll.child

  frame.primary = button(true)
  frame.secondary = button(false)
  frame.hint = K.label(frame, K.BODY_FONT, 11, T.soft)
  frame.hint:SetPoint("BOTTOMLEFT", PAD, PAD + BUTTON_H + 4)
  frame.hint:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
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
  frame:SetScale(ns.settings and ns.settings.scale or 1)
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
    f.chosen = f:CreateTexture(nil, "OVERLAY")
    f.chosen:SetTexture("Interface\\QuestFrame\\UI-QuestItemHighlight")
    f.chosen:SetBlendMode("ADD")
    f.chosen:SetPoint("TOPLEFT", -10, 8)
    f.chosen:SetPoint("BOTTOMRIGHT", 14, -8)
    f:SetHighlightTexture(K.HIGHLIGHT, "ADD")
    f:SetScript("OnEnter", function(self) ns.game.itemTooltip(self, self.item) end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnClick", function(self)
      if self.chooseIndex then ns.core.choose(self.chooseIndex) end
    end)
    return f
  end)
  local w = math.floor((inner - 10) / 2)
  c:SetSize(w, 40)
  c:SetBackdropColor(0, 0, 0, 0.35)
  K.setSlot(c.slot, item.icon, item.count, item.quality)
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

-- ── a page ───────────────────────────────────────────────────────────────────
local function footer(page)
  local a = page.actions or {}
  local both = a.primary and a.secondary
  local bw = both and math.floor((WIDTH - 2 * PAD - BUTTON_GAP) / 2) or (WIDTH - 2 * PAD)
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
    frame.primary:SetPoint("BOTTOMLEFT", PAD, PAD)
    frame.secondary:SetPoint("BOTTOMRIGHT", -PAD, PAD)
  elseif a.primary then
    frame.primary:SetPoint("BOTTOMLEFT", PAD, PAD)
  elseif a.secondary then
    frame.secondary:SetPoint("BOTTOMLEFT", PAD, PAD)
  end
end

function P.show(page)
  if not frame then build() end
  releaseAll()
  P.page = page
  P.choosing = nil
  P.choice = nil
  inner = WIDTH - 2 * PAD - 8
  y = 0

  -- the speaker's face in the ring, the book's when no one speaks (an item)
  if page.unit and UnitExists(page.unit) then
    K.unitPortrait(page.unit)(frame.portrait)
  else
    frame.portrait.tex:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
  end
  frame.title:SetText(page.title or page.name or "")
  frame.sub:SetText(page.title ~= page.name and page.name or "")

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

  child:SetHeight(math.max(1, y))
  footer(page)
  frame.hint:SetText(page.choose and not P.choice and L["Choose a reward, then complete the quest."] or "")
  frame.hint:SetShown(page.choose and not P.choice)

  -- One height for every page, as Blizzard's quest window (the user's call,
  -- 18 October 2026): its 424 interface units, so it follows the game's UI
  -- scale as every window does (two thirds of the screen did not, and towered
  -- over them); the buttons stay where they were, a long text scrolls.
  if not frame:IsShown() then place() end
  local top = PAD + HEADER + 14
  local bottom = FOOTER_GAP + BUTTON_H + PAD + (page.choose and 16 or 0)
  scroll:SetHeight(HEIGHT - top - bottom)
  scroll:ScrollTo(0)
  frame:SetHeight(HEIGHT)
  if not frame:IsShown() then frame:Show() end
  scroll:UpdateThumb()
end

function P.hide()
  if frame then frame:Hide() end
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
  if frame and frame:IsShown() then place() end
end
