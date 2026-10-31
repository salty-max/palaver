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

-- (the kit's page: K.options, account-wide here, every setting through ns.core.set)
local O

function ns.createSettingsPanel()
  if O then return end
  O = K.options({
    title = "Palaver",
    key = "PALAVER",
    get = function(key) return ns.settings[key] end,
    set = function(key, value) ns.core.set(key, value) end,
    defaults = ns.DEFAULTS,
  })
  O:check(
    "enabled",
    L["Conversations in Palaver"],
    L["Palaver shows quests and what NPCs say in its panel. When it is off, the game's own windows are back."]
  )
  O:check(
    "keys",
    L["Answer with the keyboard"],
    L["Space or Enter answers yes, 1 to 9 pick a line or a reward, and Backspace goes back a page in a book. Escape says goodbye even with this off. No key acts in combat, while you type or with a modifier held."]
  )
  O:check(
    "readOn",
    L["Read to the end first"],
    L["On a page longer than the panel, Space or Enter scrolls down first and answers once you have seen it all."]
  )
  O:check(
    "books",
    L["Books and letters in Palaver"],
    L["Books, letters and plaques you read open in Palaver's panel. When it is off, the game's own book window opens them."]
  )
  O:check(
    "hideUI",
    L["Hide the interface while you talk or read"],
    L["While you talk or read, the game's interface fades away and only the panel stays. The interface comes back for a fight, a vendor, a trainer or a question from the game."]
  )
  O:check(
    "camera",
    L["Move the camera in"],
    L["While you talk, the view moves in on whoever speaks, and comes back when you are done."]
  )
  O:check(
    "value",
    L["Mark the best value"],
    L["When a quest offers a choice of rewards, a gold coin marks the best value: the one that sells for the most."]
  )
  O:check(
    "upgrades",
    L["Mark the best upgrade"],
    L["When a quest offers a choice of rewards, a green arrow marks the best upgrade over what you wear, by the stats your class wants."]
  )
  local function values(list, label)
    return function()
      local out = {}
      for _, v in ipairs(list) do
        table.insert(out, { v, label(v) })
      end
      return out
    end
  end
  O:choice(
    "scale",
    L["Panel size"],
    L["Sets the panel's size, on top of the game's interface scale."],
    values(SCALES, function(v) return L["%d%%"]:format(math.floor(v * 100 + 0.5)) end)
  )
  O:choice(
    "font",
    L["Text size"],
    L["Sets the size of the text and of the lines you pick from."],
    values(FONTS, tostring)
  )
  O:done()
end

function ns.openSettings() return O ~= nil and O:open() end
