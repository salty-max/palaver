-- The rewards worth pointing out when a quest offers a choice: the one that
-- sells for most (a coin on its card), the one best for the character (the
-- game's green arrow). Marks only: the choice stays the player's.
--
-- Best for the character, by Palaver's own rule (no other addon asked: the
-- user's call, 18 October 2026), said so on the card's tooltip: an item the
-- game says the character can use, scored on the stats its class wants (a
-- hybrid by the talent tree holding most of its points), better than what it
-- wears there. A trinket never: its worth is its effect, which no stat tells.
-- An upgrade only: when nothing beats what the character wears, no arrow.
--
-- Each answer says when the game has yet to tell an item (its price, its
-- slot, its stats): asked again on GET_ITEM_INFO_RECEIVED (Core.lua).
local _, ns = ...
local L = ns.kit.L
local R = {}
ns.rewards = R

local function itemInfo(link)
  local fn = C_Item and C_Item.GetItemInfo or GetItemInfo
  if fn and link then return fn(link) end
end
local function itemStats(link)
  local fn = C_Item and C_Item.GetItemStats or GetItemStats
  if fn and link then return fn(link) end
end

-- ── the best value ───────────────────────────────────────────────────────────
-- The choice that sells for most (a stack at its count): { index, price }.
-- None when two share the top price or none sells. (nil, true: wait for the
-- game)
function R.bestValue(choices)
  local best, most, tie = nil, 0, false
  for i, it in ipairs(choices) do
    if not it.link then return nil, true end
    local price = select(11, itemInfo(it.link))
    if price == nil then return nil, true end
    price = price * (it.count or 1)
    if price > most then
      best, most, tie = i, price, false
    elseif price == most and price > 0 then
      tie = true
    end
  end
  if best and not tie then return { index = best, price = most } end
end

-- ── Palaver's own rule ───────────────────────────────────────────────────────
-- What each class wants, a hybrid by its tree (Classic's order: a paladin's
-- Holy, Protection, Retribution...), until one holds most of its points the
-- tree it most often levels in (LEVELING). dps: a melee weapon's damage per
-- second, ranged: a bow's, a gun's, a wand's. Rough by design: a hint for
-- the choice, not a theorycrafter's answer.
local STR, AGI, STA, INT, SPI =
  "ITEM_MOD_STRENGTH_SHORT",
  "ITEM_MOD_AGILITY_SHORT",
  "ITEM_MOD_STAMINA_SHORT",
  "ITEM_MOD_INTELLECT_SHORT",
  "ITEM_MOD_SPIRIT_SHORT"
local AP, DPS, ARMOR = "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", "RESISTANCE0_NAME"
local HEALER = { [INT] = 1, [SPI] = 0.6, [STA] = 0.4, [ARMOR] = 0.01, ranged = 1 }
local NUKER = { [INT] = 1, [STA] = 0.5, [SPI] = 0.4, [ARMOR] = 0.01, ranged = 1 }
local CLASSES = {
  WARRIOR = { { [STR] = 1, [AGI] = 0.6, [STA] = 0.5, [AP] = 0.5, [ARMOR] = 0.02, dps = 3, ranged = 0.5 } },
  ROGUE = { { [AGI] = 1, [STR] = 0.5, [STA] = 0.4, [AP] = 0.5, [ARMOR] = 0.01, dps = 3, ranged = 0.5 } },
  HUNTER = { { [AGI] = 1, [INT] = 0.4, [STA] = 0.4, [AP] = 0.4, [ARMOR] = 0.01, dps = 1, ranged = 3 } },
  MAGE = { NUKER },
  WARLOCK = { { [INT] = 1, [STA] = 0.7, [SPI] = 0.4, [ARMOR] = 0.01, ranged = 1 } },
  PRIEST = { HEALER },
  PALADIN = {
    { [INT] = 1, [STA] = 0.5, [SPI] = 0.3, [STR] = 0.2, [ARMOR] = 0.01 },
    { [STR] = 1, [STA] = 0.8, [AGI] = 0.4, [INT] = 0.2, [ARMOR] = 0.03, dps = 2 },
    { [STR] = 1, [STA] = 0.5, [AGI] = 0.4, [INT] = 0.3, [AP] = 0.5, [ARMOR] = 0.02, dps = 3 },
  },
  SHAMAN = {
    NUKER,
    { [STR] = 1, [AGI] = 0.7, [INT] = 0.3, [STA] = 0.5, [AP] = 0.5, [ARMOR] = 0.02, dps = 3 },
    HEALER,
  },
  DRUID = {
    NUKER,
    { [AGI] = 1, [STR] = 1, [STA] = 0.6, [AP] = 0.5, [ARMOR] = 0.03 },
    HEALER,
  },
}

-- (the tree a hybrid most often levels in: Retribution, Enhancement, Feral)
local LEVELING = { PALADIN = 3, SHAMAN = 2, DRUID = 2 }

-- The tree the character follows (1, 2 or 3): ten points at least, more than
-- half of them, as Hearthtale reads it (Life.lua). A few points here and there
-- are no way taken yet: the tree its class most often levels in.
local function secret(v) return issecretvalue and issecretvalue(v) end
local function tree()
  if not (GetNumTalentTabs and GetTalentTabInfo) then return nil end
  local best, most, all = nil, 0, 0
  for i = 1, GetNumTalentTabs() or 0 do
    -- (Classic Era's: name, icon, points; later clients': id, name, text, icon, points)
    local a, _, c, _, e = GetTalentTabInfo(i)
    local points = type(a) == "number" and e or c
    if type(points) == "number" and not secret(points) then
      all = all + points
      if points > most then
        best, most = i, points
      end
    end
  end
  if best and most >= 10 and most * 2 > all then return best end
end

local function weights()
  local _, class = UnitClass("player")
  local list = CLASSES[class or ""]
  if not list then return nil end
  return list[tree() or LEVELING[class] or 1] or list[1]
end

local RANGED = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
-- (nil: the game has yet to tell this item)
local function score(link, w)
  if not link then return 0 end
  local equipLoc = select(9, itemInfo(link))
  local stats = itemStats(link)
  if equipLoc == nil or stats == nil then return nil end
  local s = 0
  for stat, weight in pairs(w) do
    if stat ~= "dps" and stat ~= "ranged" then s = s + (stats[stat] or 0) * weight end
  end
  local dps = stats[DPS] or 0
  if RANGED[equipLoc] then
    s = s + dps * (w.ranged or 0)
  else
    s = s + dps * (w.dps or 0)
  end
  return s
end

-- Where an item goes: its slots, the weaker of two for a ring or a weapon.
local SLOTS = {
  INVTYPE_HEAD = { 1 },
  INVTYPE_NECK = { 2 },
  INVTYPE_SHOULDER = { 3 },
  INVTYPE_CHEST = { 5 },
  INVTYPE_ROBE = { 5 },
  INVTYPE_WAIST = { 6 },
  INVTYPE_LEGS = { 7 },
  INVTYPE_FEET = { 8 },
  INVTYPE_WRIST = { 9 },
  INVTYPE_HAND = { 10 },
  INVTYPE_FINGER = { 11, 12 },
  INVTYPE_CLOAK = { 15 },
  INVTYPE_WEAPON = { 16, 17 },
  INVTYPE_2HWEAPON = { 16, 17 },
  INVTYPE_WEAPONMAINHAND = { 16 },
  INVTYPE_WEAPONOFFHAND = { 17 },
  INVTYPE_SHIELD = { 17 },
  INVTYPE_HOLDABLE = { 17 },
  INVTYPE_RANGED = { 18 },
  INVTYPE_RANGEDRIGHT = { 18 },
  INVTYPE_THROWN = { 18 },
}

-- What it would replace, scored, and the item named on the tooltip: a
-- two-hand weapon both hands, a one-hand weapon the weaker hand where the
-- character fights with two, the main hand where it can't; an off hand, or a
-- one-hand weapon, against a two-hand weapon it would take the place of.
-- (nil: the game has yet to tell what is worn)
local function worn(equipLoc, w)
  local main = GetInventoryItemLink("player", 16)
  local twoHanded = main and select(9, itemInfo(main)) == "INVTYPE_2HWEAPON"
  local slots = SLOTS[equipLoc]
  if equipLoc == "INVTYPE_2HWEAPON" then
    local a, b = score(main, w), score(GetInventoryItemLink("player", 17), w)
    if a == nil or b == nil then return nil end
    return a + b, main or GetInventoryItemLink("player", 17)
  end
  if twoHanded and (slots[1] == 16 or slots[1] == 17) then return score(main, w), main end
  if equipLoc == "INVTYPE_WEAPON" and not (CanDualWield and CanDualWield()) then slots = { 16 } end
  local low, lowLink
  for _, slot in ipairs(slots) do
    local link = GetInventoryItemLink("player", slot)
    local s = score(link, w)
    if s == nil then return nil end
    if not low or s < low then
      low, lowLink = s, link
    end
  end
  return low, lowLink
end

local function own(it, w)
  local equipLoc = select(9, itemInfo(it.link))
  if equipLoc == nil then return nil, true end
  if not SLOTS[equipLoc] then return nil end -- (not worn, or a trinket: its worth is its effect)
  local s = score(it.link, w)
  local now, nowLink = worn(equipLoc, w)
  if s == nil or now == nil then return nil, true end
  if s <= now then return nil end
  local name = nowLink and itemInfo(nowLink)
  local why = name and L["Better for you than your %s, by the stats your class wants."]:format(name)
    or L["Better for you than an empty slot, by the stats your class wants."]
  return s - now, false, why
end

-- ── the best for the character ───────────────────────────────────────────────
-- Among the choices: { index, why } or nil (no upgrade among them), and true
-- when the game has yet to tell one of them.
function R.bestForYou(choices)
  local w = weights()
  if not w then return nil end
  local best, gain, why, waiting
  for i, it in ipairs(choices) do
    if not it.link then return nil, true end
    if it.usable ~= false then
      local g, wait, because = own(it, w)
      if wait then waiting = true end
      if g and (not gain or g > gain) then
        best, gain, why = i, g, because
      end
    end
  end
  if waiting then return nil, true end
  if best then return { index = best, why = why } end
end
