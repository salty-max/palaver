-- The camera: DialogueUI's "zoom in" (its Code/Camera.lua, Peterodox's
-- YUI-Dialogue, read line by line as the reference: the same moves, the same
-- numbers, as its default settings play them).
--
-- Someone to look at (an NPC): the game's own interaction focus on the
-- speaker, the view set over the shoulder so the NPC stands beside the panel,
-- a one-second tilt that brings the view level with them and narrows the
-- field of view to 75, and a zoom in (never out) to a distance by how tall the
-- NPC stands, measured from its model (a dwarf 1.7, a human 2.1, a gnome 1.1:
-- 2 yards under 2). No one to look at (an object's quest, an item's, an NPC
-- whose identity the game hides): the view slides aside, by how far out it
-- is, and comes to 3 yards. While the conversation lasts the view follows a
-- mount, a druid's form and the panel's side of the screen, and it stays
-- through a fight, as DialogueUI's does. When the conversation ends, every
-- setting it touched and the old zoom come back.
--
-- Every setting is written to PalaverSettings.cameraBackup the moment it is
-- changed: a crash or a lost connection mid-conversation never restores,
-- and the client keeps these settings across sessions, so the next login
-- puts them back (the prototype's lesson). On by default, as DialogueUI's
-- (the user's call, 22 October 2026). /palaver camera turns it off.
local _, ns = ...
local C = {}
ns.camera = C

local SHOULDER = 1.5
local MOUNTED = 4.8 -- (the shoulder's multiplier on a mount, which stands between)
local DURATION = 1.0
local FOV = 75
local OBJECT = 3 -- (no one to look at: how close)
local UNKNOWN = 3 -- (no size to go by: as tall as this, so 4 yards)
local FOCUS = {
  test_cameraTargetFocusInteractEnable = 1,
  test_cameraTargetFocusInteractStrengthPitch = 0,
  test_cameraTargetFocusInteractStrengthYaw = 0,
  test_cameraOverShoulder = SHOULDER,
  test_cameraHeadMovementStrength = 0,
  CameraKeepCharacterCentered = 0,
  CameraReduceUnexpectedMovement = 0,
}
local ASIDE = {
  CameraKeepCharacterCentered = 0,
  CameraReduceUnexpectedMovement = 0,
}
-- A druid's form, its own distance over the shoulder (GetShapeshiftFormID:
-- cat, tree, travel, aquatic, bear, swift flight, flight, moonkin).
local FORMS = { [1] = 1.0, [2] = 1.0, [3] = 1.1, [4] = 0.9, [5] = 0.9, [27] = 0.55, [29] = 0.55, [31] = 1.0 }
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
local function mountedNow() return IsMounted and IsMounted() or false end

local driver, listener = CreateFrame("Frame"), CreateFrame("Frame")
local active, warned, letGo = false, false, false
local mode -- ("npc": someone to look at, "aside": no one)
local session = 0 -- (each conversation's own: a late model or timer of an older one ignored)
local mounted, left = false, false
local base, pan = SHOULDER, 1 -- (the shoulder and the slide's multiplier, a druid's form's)
local fovFrom -- (the field of view the tilt narrows from, nil when it stays)
local shoulder = 0 -- (where the slide has the view now)

-- ── when the camera fails ────────────────────────────────────────────────────
-- An error of the camera's own (a call one client answers differently) never
-- reaches the conversation: the camera is put back and stays still for the
-- rest of the session, the error kept once for /palaver errors with the stack
-- where it was thrown (Core's keep). Every way in goes through guard.
local broken = false
local stopNow -- (below)
local function trace(err) return { err = err, stack = debugstack and debugstack(2) or "" } end
local function guard(fn)
  local a, b
  local function call() return fn(a, b) end
  return function(x, y)
    if broken then return end
    a, b = x, y
    local ok, e = xpcall(call, trace)
    a, b = nil, nil
    if ok then return end
    broken = true
    pcall(stopNow)
    if ns.core and ns.core.keep then ns.core.keep(e.err, "camera", e.stack) end
  end
end

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

-- A setting kept before anything changes it (false: one this game doesn't have).
local function keep(name)
  local old = getCVar(name)
  if old == nil then return false end
  local b = saved()
  if b.cvars[name] == nil then b.cvars[name] = tostring(old) end
  return true
end
local function change(name, value)
  if keep(name) then setCVar(name, value) end
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

-- How close for an NPC this tall (DialogueUI's bands; nil: too big to come close).
local function distance(height)
  if height < 2 then return 2 end
  if height < 2.6 then return 3 end
  if height < 4 then return 4 end
  if height < 5.1 then return 5 end
  if height < 6.1 then return 6 end
  if height < 8 then return 10 end
  if height + 2 <= 28.5 then return height + 2 end
end

-- ── where the view stands ────────────────────────────────────────────────────
-- The panel's side of the screen: over the right shoulder for a panel on the
-- right, the left one for a panel dragged left (DialogueUI's two sides).
local function onLeft()
  local f = ns.panel and ns.panel.frame()
  local x, mid = f and f:GetCenter(), UIParent:GetCenter()
  if not (x and mid) then return false end
  return x * (f:GetEffectiveScale() or 1) < mid * (UIParent:GetEffectiveScale() or 1)
end
local function multiplier()
  if left then return mounted and -0.3 or -1 end
  return mounted and MOUNTED or 1
end

local function form()
  local _, class = UnitClass("player")
  local id = class == "DRUID" and GetShapeshiftFormID and GetShapeshiftFormID()
  local offset = id and FORMS[id] or SHOULDER
  base, pan = offset, offset / SHOULDER
end

-- How far aside for the zoom the view is at (DialogueUI's line).
local function aside() return ((GetCameraZoom and GetCameraZoom() or 0) * 0.4314 + 0.1057) * pan end

-- The view where it ends: the shoulder for an NPC, aside for no one.
local function place()
  shoulder = multiplier() * (mode == "npc" and base or aside())
  setCVar("test_cameraOverShoulder", shoulder)
end

-- Forever's modern interface keeps its field of view on a mount or gliding
-- (DialogueUI's: the speed's effects would leave it past its maximum).
local function flying()
  if not ns.forever then return false end
  if mountedNow() then return true end
  local I = C_PlayerInfo
  if not (I and I.GetGlidingInfo) then return false end
  local gliding, can = I.GetGlidingInfo()
  return (gliding or can) and true or false
end

-- ── measuring the NPC ────────────────────────────────────────────────────────
PalaverMeasureActorMixin = {}
PalaverMeasureActorMixin.OnModelLoaded = guard(function(self)
  local x1, y1, z1, x2, y2, z2 = self:GetActiveBoundingBox()
  self:ClearModel()
  if not (active and mode == "npc" and self.session == session) then return end
  if not (x1 and y1 and z1 and x2 and y2 and z2) then return end -- (a model without a size)
  local d = distance(z2 - z1)
  if d then zoomTo(d) end
end)

local scene, actor
local function measure()
  if not (CreateFrame and UnitExists("npc")) then return false end
  if C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret and C_Secrets.ShouldUnitIdentityBeSecret("npc") then
    return false
  end
  local ok = pcall(function()
    scene = scene or CreateFrame("ModelScene")
    scene:SetSize(1, 1)
    actor = actor or scene:CreateActor(nil, "PalaverMeasureActorTemplate")
  end)
  if not (ok and actor) then return false end
  actor.session = session
  return (pcall(actor.SetModelByUnit, actor, "npc"))
end

-- ── the moves ────────────────────────────────────────────────────────────────
-- Over a second, eased: the focus's pull on the pitch from none to full, the
-- pitch limit from 88 to 15 (which lowers the view), the field of view to 75,
-- then the limit released to 88 (the view stays where it came to).
local tilt = guard(function(self, elapsed)
  self.t = self.t + elapsed
  local k = math.sin(math.min(1, self.t / DURATION) * math.pi / 2)
  local pitch = 88 - 73 * k
  if self.t >= DURATION then
    ConsoleExec("pitchlimit 15")
    pitch, k = 88, 1
    self:SetScript("OnUpdate", nil)
  end
  if fovFrom then setCVar("cameraFov", fovFrom + (FOV - fovFrom) * k) end
  setCVar("test_cameraTargetFocusInteractStrengthPitch", k)
  ConsoleExec("pitchlimit " .. pitch)
end)

-- No one to look at: the view slides aside as long as the conversation lasts,
-- following the zoom (a step every few hundredths of a second).
local slide = guard(function(self, elapsed)
  self.t = self.t + elapsed
  if self.t <= 0.03 then return end
  self.t = 0
  local goal = multiplier() * aside()
  shoulder = shoulder + (goal - shoulder) * math.min(1, self.blend * elapsed * 60)
  setCVar("test_cameraOverShoulder", shoulder)
end)

-- A mount, a druid's form or the glide changing while it lasts. (Forever,
-- mounted or gliding mid-conversation: the field of view put back. DialogueUI
-- means to, its RestoreCameraFOVIfMounted, but reads the wrong table and
-- never does: Palaver does what it means.)
local function changed(_, event)
  if event == "UPDATE_SHAPESHIFT_FORM" then
    -- (the form's id is the new one a frame later)
    local mine = session
    return C_Timer.After(
      0,
      guard(function()
        if not active or session ~= mine then return end
        local was = base
        form()
        if base ~= was then place() end
      end)
    )
  end
  local now = mountedNow()
  if now ~= mounted then
    mounted = now
    place()
  end
  if fovFrom and flying() then
    fovFrom = nil
    local was = saved().cvars.cameraFov
    if was then setCVar("cameraFov", was) end
  end
end
listener:SetScript("OnEvent", guard(changed))
local EVENTS = { "PLAYER_MOUNT_DISPLAY_CHANGED", "UPDATE_SHAPESHIFT_FORM", "PLAYER_IS_GLIDING_CHANGED" }

-- Who is spoken to is someone to look at: an NPC, not the player (a quest
-- from an item), not an object, not one whose identity the game hides.
local function speaker()
  if not UnitExists("npc") then return false end
  local me = UnitIsUnit("npc", "player")
  if secret(me) or me then return false end
  return true
end

C.start = guard(function()
  if active or not (ns.settings and ns.settings.camera) then return end
  active = true
  session = session + 1
  mode = speaker() and "npc" or "aside"
  mounted, left = mountedNow(), onLeft()
  form()
  quiet()
  local b = saved()
  b.zoom = GetCameraZoom and GetCameraZoom()
  driver.t = 0
  if mode == "npc" then
    for name, value in pairs(FOCUS) do
      change(name, value)
    end
    b.pitch = true
    fovFrom = not flying() and keep("cameraFov") and (tonumber(getCVar("cameraFov")) or 90) or nil
    place()
    driver:SetScript("OnUpdate", tilt)
    if not measure() then zoomTo(distance(UNKNOWN)) end
  else
    keep("test_cameraOverShoulder")
    for name, value in pairs(ASIDE) do
      change(name, value)
    end
    shoulder = tonumber(getCVar("test_cameraOverShoulder")) or 0
    driver.blend = aside() - shoulder > 8 and 0.06 or 0.1
    driver:SetScript("OnUpdate", slide)
    zoomTo(OBJECT, true)
  end
  for _, event in ipairs(EVENTS) do
    pcall(listener.RegisterEvent, listener, event) -- (an event one game lacks)
  end
end)

-- The panel dragged to the other side of the screen: the other shoulder.
C.moved = guard(function()
  if not active then return end
  local now = onLeft()
  if now ~= left then
    left = now
    place()
  end
end)

-- Everything put back: the settings, the pitch limit, the zoom.
local function restore(b)
  for name, value in pairs(b.cvars or {}) do
    setCVar(name, value)
  end
  if b.pitch and ConsoleExec then ConsoleExec("pitchlimit 88") end
  if b.zoom then zoomTo(b.zoom, true) end
end

stopNow = function()
  if not active then return end
  active, mode, fovFrom = false, nil, nil
  driver:SetScript("OnUpdate", nil)
  listener:UnregisterAllEvents()
  restore(saved())
  ns.settings.cameraBackup = nil
  heard()
end
C.stop = guard(stopNow)

-- At login: a conversation the last session never finished left the camera
-- changed. Its settings back (the zoom is the session's own: not kept).
C.recover = guard(function()
  local b = ns.settings and ns.settings.cameraBackup
  if not b then return end
  b.zoom = nil
  quiet()
  restore(b)
  ns.settings.cameraBackup = nil
  heard()
end)

function C.active() return active end
