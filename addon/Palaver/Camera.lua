-- The camera: DialogueUI's "zoom to the NPC" (its Camera.lua, read as the
-- reference). While a conversation lasts: the game's own interaction focus on
-- the speaker, the view set over the shoulder so the NPC stands beside the
-- panel, a short tilt that brings the view level with them, and a zoom in
-- (never out) to a distance by how tall the NPC stands, measured from its
-- model (a dwarf 1.7, a human 2.1, a gnome 1.1: 2 yards under 2). When the
-- conversation ends, every setting it touched and the old zoom come back.
--
-- Every setting is written to PalaverSettings.cameraBackup the moment it is
-- changed: a crash or a lost connection mid-conversation never restores,
-- and the client keeps these settings across sessions, so the next login
-- puts them back (the prototype's lesson). Off by default (/palaver camera).
local _, ns = ...
local C = {}
ns.camera = C

local SHOULDER = 1.5
local MOUNTED = 4.8 -- (DialogueUI's: the mount stands between)
local DURATION = 1.0
local FOCUS = {
  test_cameraTargetFocusInteractEnable = 1,
  test_cameraTargetFocusInteractStrengthPitch = 0,
  test_cameraTargetFocusInteractStrengthYaw = 0,
  test_cameraOverShoulder = SHOULDER,
  test_cameraHeadMovementStrength = 0,
  CameraKeepCharacterCentered = 0,
  CameraReduceUnexpectedMovement = 0,
}
local WARNING = "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED"

local function getCVar(name)
  local fn = C_CVar and C_CVar.GetCVar or GetCVar
  return fn and fn(name)
end
local function setCVar(name, value)
  local fn = C_CVar and C_CVar.SetCVar or SetCVar
  if fn then fn(name, value) end
end
local function secret(v) return issecretvalue and issecretvalue(v) end

local active, driver, warned, letGo = false, CreateFrame("Frame"), false, false
local measured = false
local session = 0 -- (each conversation's own: a late model or timer of an older one ignored)
local MIDDLING = 4 -- (no size to go by: a model that never loads, or loads without one)

-- The game's warning about experimental settings ("visual discomfort", Accept
-- or Disable, Disable undoing every one of them): not for a camera put back
-- when the conversation ends. Classic Era's interface hears it on UIParent:
-- muted while the camera is changed, then heard again. Forever's (12.1's
-- Blizzard_Game) on a frame of its own behind GameEvent: let go for the
-- session the first time, as DialogueUI does. A handler put back by an addon
-- would be the addon's, and the game's popups would run it (taint).
local function quiet()
  if UIParent:IsEventRegistered(WARNING) then
    UIParent:UnregisterEvent(WARNING)
    warned = true
  elseif not letGo and GameEvent and GameEvent.UnregisterInternalEvent then
    GameEvent.UnregisterInternalEvent(WARNING)
    letGo = true
  end
end
local function heard()
  if warned then
    UIParent:RegisterEvent(WARNING)
    warned = false
  end
end

-- The saved file's copy of what was changed, kept as it changes.
local function saved()
  local s = ns.settings
  if not s then return {} end
  s.cameraBackup = s.cameraBackup or { cvars = {} }
  return s.cameraBackup
end

local function change(name, value)
  local old = getCVar(name)
  if old == nil then return end -- (a setting this game doesn't have)
  local b = saved()
  if b.cvars[name] == nil then b.cvars[name] = tostring(old) end
  setCVar(name, value)
end

local function zoomTo(goal, outToo)
  if not (GetCameraZoom and CameraZoomIn and CameraZoomOut) then return end
  local diff = GetCameraZoom() - goal
  if math.abs(diff) < 0.1 then return end
  if diff > 0 then
    CameraZoomIn(diff)
  elseif outToo then
    CameraZoomOut(-diff)
  end
end

-- How close for an NPC this tall (DialogueUI's bands).
local function distance(height)
  if height < 2 then return 2 end
  if height < 2.6 then return 3 end
  if height < 4 then return 4 end
  if height < 5.1 then return 5 end
  if height < 6.1 then return 6 end
  if height < 8 then return 10 end
  if height + 2 <= 28.5 then return height + 2 end
end

-- ── measuring the NPC ────────────────────────────────────────────────────────
PalaverMeasureActorMixin = {}
function PalaverMeasureActorMixin:OnModelLoaded()
  local _, _, z1, _, _, z2 = self:GetActiveBoundingBox()
  self:ClearModel()
  if not active or measured or self.session ~= session then return end
  measured = true
  if not (z1 and z2) then return zoomTo(MIDDLING) end
  local d = distance(z2 - z1)
  if d then zoomTo(d) end
end

local scene, actor
local function measure()
  if not (CreateFrame and UnitExists("npc")) then return false end
  local ok = pcall(function()
    scene = scene or CreateFrame("ModelScene")
    scene:SetSize(1, 1)
    actor = actor or scene:CreateActor(nil, "PalaverMeasureActorTemplate")
  end)
  if not (ok and actor) then return false end
  actor.session = session
  return pcall(actor.SetModelByUnit, actor, "npc")
end

-- ── the move in ──────────────────────────────────────────────────────────────
-- Over a second: the focus's pull on the pitch from none to full, the pitch
-- limit eased from 88 to 15 (which lowers the view), then the limit
-- released to 88 (the view stays where it came to).
local function ease(t) return math.sin(math.min(1, t) * math.pi / 2) end
local function tilt(self, elapsed)
  self.t = (self.t or 0) + elapsed
  local k = ease(self.t / DURATION)
  setCVar("test_cameraTargetFocusInteractStrengthPitch", k)
  if self.t >= DURATION then
    ConsoleExec("pitchlimit 15")
    ConsoleExec("pitchlimit 88")
    self:SetScript("OnUpdate", nil)
    return
  end
  ConsoleExec("pitchlimit " .. math.floor(88 - 73 * k + 0.5))
end

-- Who is spoken to is someone to look at: an NPC, not the player (a quest
-- from an item), not an object, not one whose identity the game hides.
local function speaker()
  if not UnitExists("npc") then return false end
  local me = UnitIsUnit("npc", "player")
  if secret(me) or me then return false end
  return true
end

function C.start()
  if active or not (ns.settings and ns.settings.camera) then return end
  if InCombatLockdown() or not speaker() then return end
  active = true
  quiet()
  for name, value in pairs(FOCUS) do
    change(name, value)
  end
  local b = saved()
  b.zoom = GetCameraZoom and GetCameraZoom()
  b.pitch = true
  local shoulder = (IsMounted and IsMounted()) and MOUNTED or SHOULDER
  setCVar("test_cameraOverShoulder", shoulder)
  measured = false
  session = session + 1
  local mine = session
  if measure() then
    C_Timer.After(0.5, function()
      if active and not measured and session == mine then
        measured = true
        zoomTo(MIDDLING)
      end
    end)
  else
    measured = true
    zoomTo(MIDDLING)
  end
  driver.t = 0
  driver:SetScript("OnUpdate", tilt)
end

-- Everything put back: the settings, the pitch limit, the zoom.
local function restore(b)
  for name, value in pairs(b.cvars or {}) do
    setCVar(name, value)
  end
  if b.pitch and ConsoleExec then ConsoleExec("pitchlimit 88") end
  if b.zoom then zoomTo(b.zoom, true) end
end

function C.stop()
  if not active then return end
  active = false
  driver:SetScript("OnUpdate", nil)
  restore(saved())
  ns.settings.cameraBackup = nil
  heard()
end

-- At login: a conversation the last session never finished left the camera
-- changed. Its settings back (the zoom is the session's own: not kept).
function C.recover()
  local b = ns.settings and ns.settings.cameraBackup
  if not b then return end
  b.zoom = nil
  quiet()
  restore(b)
  ns.settings.cameraBackup = nil
  heard()
end

function C.active() return active end
