-- Palaver's page in the game's Options (AddOns tab), as its siblings have
-- theirs (Second Wind's Settings.lua): every setting /palaver changes, the
-- same way (ns.core.set: what each changes at once). Account-wide, in
-- PalaverSettings (Core.lua): a reading panel's settings, the same for every
-- character. /palaver settings opens it.
local _, ns = ...
local K = ns.kit
local L = K.L

local SCALES = { 0.7, 0.8, 0.9, 1, 1.1, 1.2, 1.3, 1.4, 1.5 }
local FONTS = { 12, 13, 14, 15, 16, 17, 18, 20, 22 }

local category

function ns.createSettingsPanel()
  if category or not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
  category = Settings.RegisterVerticalLayoutCategory("Palaver")

  local function get(key)
    return function() return ns.settings[key] end
  end
  local function set(key)
    return function(value) ns.core.set(key, value) end
  end

  local function checkbox(key, name, tooltip)
    local setting = Settings.RegisterProxySetting(
      category,
      "PALAVER_" .. key:upper(),
      Settings.VarType.Boolean,
      name,
      ns.DEFAULTS[key],
      get(key),
      set(key)
    )
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  local function dropdown(key, name, tooltip, values, label)
    local setting = Settings.RegisterProxySetting(
      category,
      "PALAVER_" .. key:upper(),
      Settings.VarType.Number,
      name,
      ns.DEFAULTS[key],
      get(key),
      set(key)
    )
    Settings.CreateDropdown(category, setting, function()
      local options = Settings.CreateControlTextContainer()
      for _, v in ipairs(values) do
        options:Add(v, label(v))
      end
      return options:GetData()
    end, tooltip)
  end

  checkbox(
    "enabled",
    L["Conversations in Palaver"],
    L["Quests and what NPCs say, in Palaver's panel. Off, the game's own windows are back."]
  )
  checkbox(
    "keys",
    L["Answer with the keyboard"],
    L["Space or Enter answers yes, Escape says goodbye, 1 to 9 pick a line or a reward. Never in combat or while you type."]
  )
  checkbox(
    "camera",
    L["Move the camera in"],
    L["While you talk, the view moves in on whoever speaks, and comes back when you are done."]
  )
  checkbox(
    "value",
    L["Mark the best value"],
    L["When a quest offers a choice of rewards, a gold coin on the one that sells for most."]
  )
  checkbox(
    "upgrades",
    L["Mark the best for you"],
    L["When a quest offers a choice of rewards, a green arrow on the one that beats what you wear by most, by the stats your class wants."]
  )
  dropdown(
    "scale",
    L["Panel size"],
    L["The panel's size, on top of the game's interface scale."],
    SCALES,
    function(v) return L["%d%%"]:format(math.floor(v * 100 + 0.5)) end
  )
  dropdown("font", L["Text size"], L["The size of what NPCs say and of the lines to pick."], FONTS, tostring)

  Settings.RegisterAddOnCategory(category)
end

function ns.openSettings()
  if category then Settings.OpenToCategory(category:GetID()) end
  return category ~= nil
end
