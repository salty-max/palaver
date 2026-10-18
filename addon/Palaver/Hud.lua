-- The game's interface hidden while a conversation or a book lasts, only the
-- panel and the speaker left on screen: DialogueUI's "hide UI" (its
-- Camera.lua's fade helper, read as the reference). A quarter of a second's
-- fade, then the game's own Alt+Z (SetUIVisibility). On by default (the
-- user's call, 18 October 2026): /palaver hud or the Options page turns it off.
--
-- The interface comes back, at once, whenever it must: the conversation over
-- (Core's hide), a combat starting (PLAYER_REGEN_DISABLED comes before the
-- game locks it), a popup of the game's (a paid turn-in's question, an
-- innkeeper's), a cinematic, a window the gossip opens (GOSSIP_CLOSED's
-- interactionIsContinuing comes before a vendor's: the game's interface
-- coming back closes every window open, UIParent_OnShow's CloseAllWindows,
-- which would close the vendor's), a page that fails, the setting turned
-- off. Never touched in combat. One the player hid themselves (Alt+Z) is
-- left as it is, and not shown again.
local _, ns = ...
local H = {}
ns.hud = H

local FADE = 0.25
local hiding = false -- Palaver hid it (or is fading it out)
local fader = CreateFrame("Frame")

local function setShown(on)
  if SetUIVisibility then
    SetUIVisibility(on)
  else
    UIParent:SetShown(on)
  end
end

function H.hidden() return hiding end

function H.hide()
  if hiding or not (ns.settings and ns.settings.hideUI) then return end
  if InCombatLockdown() or not UIParent:IsShown() then return end
  hiding = true
  fader.t = 0
  fader:SetScript("OnUpdate", function(self, elapsed)
    self.t = self.t + elapsed
    local a = 1 - math.min(1, self.t / FADE)
    if a > 0 then return UIParent:SetAlpha(a) end
    self:SetScript("OnUpdate", nil)
    UIParent:SetAlpha(1)
    if InCombatLockdown() then
      hiding = false
      return
    end
    setShown(false)
  end)
end

-- (instant: no fade back, for what must find the interface there now)
function H.show(instant)
  if not hiding then return end
  hiding = false
  fader:SetScript("OnUpdate", nil)
  if not UIParent:IsShown() then
    -- (locked already: back the moment the combat ends)
    if InCombatLockdown() then
      H.owed = true
      return UIParent:SetAlpha(1)
    end
    setShown(true)
  end
  if instant then return UIParent:SetAlpha(1) end
  -- (from where a fade out had come to, if it was under way)
  local from = UIParent:GetAlpha()
  if from >= 1 then from = 0 end
  fader.t = from * FADE
  UIParent:SetAlpha(from)
  fader:SetScript("OnUpdate", function(self, elapsed)
    self.t = self.t + elapsed
    local a = math.min(1, self.t / FADE)
    UIParent:SetAlpha(a)
    if a >= 1 then self:SetScript("OnUpdate", nil) end
  end)
end

-- What brings it back at once.
local E = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "CINEMATIC_START", "PLAY_MOVIE", "LOADING_SCREEN_ENABLED" }) do
  pcall(E.RegisterEvent, E, event) -- (an event one game lacks)
end
pcall(E.RegisterEvent, E, "PLAYER_REGEN_ENABLED")
E:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" then
    if H.owed and not UIParent:IsShown() then setShown(true) end
    H.owed = nil
    return
  end
  H.show(true)
end)
if hooksecurefunc and StaticPopup_Show then hooksecurefunc("StaticPopup_Show", function() H.show(true) end) end
