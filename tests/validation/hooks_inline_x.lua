-- Standalone pre-validation for Hooks.lua. Stubs every Blizzard global
-- the file touches, then exercises every code path the live integration
-- depends on, including:
--   * loadout row (numeric configID) → X created, sized, shown
--   * Starter Build row (numeric, but == STARTER_BUILD_TRAIT_CONFIG_ID) → no X
--   * sentinel row (non-numeric data, e.g. "Import") → no X
--   * button-pool reuse: a button that rendered a loadout last time
--     now renders a sentinel → cached X is hidden, not left visible
--   * sentinel: indexing a function errors (proves the prior
--     `wrapped._tld_wrapped` sentinel approach was always broken)
-- Run via: lua tld_hooks_validate.lua
-- Exits 0 on all-green, 1 on any failure.

local function fail(msg)
  io.write("FAIL: ", msg, "\n")
  os.exit(1)
end

-- Lua 5.4 (harness) removed global `unpack`; WoW Lua 5.1 has both. Shim
-- so the GetChildren stub's varargs return works under either version.
unpack = unpack or table.unpack

-- ---- Blizzard stubs ----

function hooksecurefunc(t, name, fn)
  local orig = t[name]
  assert(type(orig) == "function", "hooksecurefunc: " .. name .. " is not a function")
  t[name] = function(...)
    orig(...)
    fn(...)
  end
end

local frameSerial = 0
local function makeFrame(name, fields)
  frameSerial = frameSerial + 1
  local f = fields or {}
  f._name = name or ("anon" .. frameSerial)
  f._children = {}
  function f:GetName() return self._name end
  function f:GetChildren() return unpack(self._children) end
  function f:GetNumChildren() return #self._children end
  function f:SetText() end
  function f:SetSize(w, h) self._w, self._h = w, h end
  function f:SetScript(name_, fn)
    self._scripts = self._scripts or {}
    self._scripts[name_] = fn
  end
  function f:ClearAllPoints() self._anchored = false end
  function f:SetPoint() self._anchored = true end
  function f:Show() self._shown = true end
  function f:Hide() self._shown = false end
  function f:IsShown() return self._shown end
  function f:SetNormalTexture(path)
    self._normalTex = {
      _desat = false, _vColor = nil, _texPath = path,
      SetDesaturated = function(self_, v) self_._desat = v end,
      SetVertexColor = function(self_, r, g, b) self_._vColor = { r, g, b } end,
      GetTexture = function(self_) return self_._texPath end,
    }
  end
  function f:GetNormalTexture()
    if not self._normalTex then self:SetNormalTexture(nil) end
    return self._normalTex
  end
  return f
end

local createdButtons = {}
CreateFrame = function(kind, name, parent, template)
  local btn = makeFrame(name)
  table.insert(createdButtons, btn)
  if parent and parent._children then
    table.insert(parent._children, btn)
  end
  return btn
end
IsShiftKeyDown = function() return false end
C_ClassTalents = {
  GetActiveConfigID = function() return 101 end,
  DeleteConfig = function() end,
}
GameTooltip = {
  SetOwner = function() end, SetText = function() end,
  Show = function() end, Hide = function() end,
}

-- STARTER_BUILD_TRAIT_CONFIG_ID is the magic value tlframe.lua line ~815
-- inserts into self.configIDs for the starter build option. Use a
-- distinct sentinel number so test rows don't accidentally collide.
Constants = { TraitConsts = { STARTER_BUILD_TRAIT_CONFIG_ID = -42 } }

-- Build a mockable LoadSystem instance and its Dropdown.
local rootDescBuilder
local mockDropdown = makeFrame("LoadSystemDropdown")
mockDropdown._shown = true
function mockDropdown:SetupMenu(generator)
  self.menuGenerator = generator
  -- Simulate Blizzard's GenerateMenu: build a rootDescription, call the
  -- generator, then render each child desc (which fires our initializer).
  local rootDesc = rootDescBuilder()
  generator(self, rootDesc)
  return rootDesc
end

-- Helper: build a fresh rootDescription with a known mix of child descs.
-- Children:
--   1: loadout row (configID 201)
--   2: loadout row (active configID 101)
--   3: Starter Build (configID == STARTER_BUILD_TRAIT_CONFIG_ID == -42)
--   4: sentinel "Import" (data = nil)
rootDescBuilder = function()
  local rootDesc = { children = {} }
  local function mkDesc(data)
    return {
      _data = data,
      _initializers = {},
      GetData = function(self_) return self_._data end,
      AddInitializer = function(self_, fn)
        table.insert(self_._initializers, fn)
      end,
    }
  end
  rootDesc.children[1] = mkDesc(201)
  rootDesc.children[2] = mkDesc(101)
  rootDesc.children[3] = mkDesc(Constants.TraitConsts.STARTER_BUILD_TRAIT_CONFIG_ID)
  rootDesc.children[4] = mkDesc(nil)  -- sentinel
  rootDesc.EnumerateElementDescriptions = function(self_)
    local i = 0
    return function()
      i = i + 1
      local v = self_.children[i]
      if v == nil then return nil end
      return i, v
    end
  end
  return rootDesc
end

local mockLoadSystem = makeFrame("LoadSystem", { Dropdown = mockDropdown })
mockLoadSystem.possibleSelections = {201, 101, -42}
function mockLoadSystem:UpdateSelectionOptions()
  local function blizzGen(_, _) end
  self.Dropdown:SetupMenu(blizzGen)
end
mockLoadSystem.Dropdown:SetupMenu(function() end)  -- pre-existing blizz generator

PlayerSpellsFrame = makeFrame("PlayerSpellsFrame", {
  TalentsFrame = makeFrame("TalentsFrame", {
    LoadSystem = mockLoadSystem,
    SearchBox = makeFrame("SearchBox"),
  }),
})
DropdownLoadSystemMixin = { UpdateSelectionOptions = function() end }

-- Suppress diagnostic prints from Hooks.lua so test output stays clean.
print = function(...) end

-- ---- Load Hooks.lua ----

local addonName = "TalentLoadoutDeleter"
local ns = {}
local Hooks_chunk, err = loadfile("C:/Users/tekau/Documents/Codex/TalentLoadoutDeleter/TalentLoadoutDeleter/src/Hooks.lua")
if err then fail("loadfile: " .. tostring(err)) end

local ok, loadErr = pcall(Hooks_chunk, addonName, ns)
if not ok then fail("chunk pcall: " .. tostring(loadErr)) end

assert(ns.Hooks, "ns.Hooks should be set")
assert(type(ns.Hooks.Install) == "function", "ns.Hooks.Install missing")

-- ---- Sanity: function field indexing errors ----
do
  local f = function() end
  local ok_, _ = pcall(function() local x = f._foo end)
  if ok_ then
    fail("Expected indexing a function to error (proves prior _tld_wrapped sentinel was broken)")
  end
  io.write("OK function indexing errors as expected\n")
end

-- ---- Install ----
local ok2, installErr = pcall(ns.Hooks.Install)
if not ok2 then fail("Hooks.Install errored: " .. tostring(installErr)) end
io.write("OK Hooks.Install completed without error\n")

-- After install, the dropdown should have our wrapped generator and a
-- rootDescription was built (initializers registered on each child).
local mg = mockDropdown.menuGenerator
assert(type(mg) == "function", "menuGenerator should be a function, got " .. type(mg))
io.write("OK menuGenerator is a function after Install\n")

-- ---- Exercise each child desc's initializer with a fresh button ----
-- buildWrappedGenerator was already called once during Install's
-- pre-existing-wrap path. To get the desc list, call SetupMenu(mg) again
-- — which is what our hook does — to rebuild the rootDescription and
-- run the wrapped generator (which calls blizzGen + registers initializers).
local rootDesc = mockDropdown:SetupMenu(mg)
assert(#rootDesc.children == 4, "expected 4 descs, got " .. #rootDesc.children)

local function newRowButton()
  return makeFrame("rowButton")
end

-- Child 1: loadout row 201 (non-active)
do
  local btn = newRowButton()
  rootDesc.children[1]._initializers[1](btn, rootDesc.children[1], nil)
  if not btn._tldX then fail("loadout row should have created an X button") end
  if btn._tldX._shown ~= true then fail("loadout row X should be shown") end
  if btn._tldX:GetNormalTexture()._desat ~= false then fail("non-active X should not be desaturated") end
  io.write("OK loadout row (configID 201) creates a visible non-greyed X\n")
end

-- Child 2: active loadout 101
do
  local btn = newRowButton()
  rootDesc.children[2]._initializers[1](btn, rootDesc.children[2], nil)
  if not btn._tldX then fail("active loadout row should have created an X button") end
  if btn._tldX._shown ~= true then fail("active X should be shown") end
  if btn._tldX:GetNormalTexture()._desat ~= true then fail("active X should be desaturated") end
  io.write("OK active loadout row (configID 101) creates a desaturated X\n")
end

-- Child 3: Starter Build (numeric, == STARTER_BUILD_TRAIT_CONFIG_ID)
do
  local btn = newRowButton()
  rootDesc.children[3]._initializers[1](btn, rootDesc.children[3], nil)
  if btn._tldX then fail("Starter Build row must NOT create an X (it is filtered as not-deletable)") end
  io.write("OK Starter Build row (configID == STARTER_BUILD) produces no X\n")
end

-- Child 4: sentinel (data = nil)
do
  local btn = newRowButton()
  rootDesc.children[4]._initializers[1](btn, rootDesc.children[4], nil)
  if btn._tldX then fail("sentinel row must NOT create an X (data is not numeric)") end
  io.write("OK sentinel row (data = nil) produces no X\n")
end

-- ---- Orphan X cleanup: button has a prior orphan X attached ----
-- Simulates the user's actual Phase 8 bug: previous broken addon versions
-- attached unmarked X frames to Blizzard menu buttons. /reload doesn't
-- unload Blizzard_Menu's button pool, so the orphans persist. Our new
-- initializer must scan-by-texture and hide them.
do
  local btn = newRowButton()
  -- Pre-attach an "orphan" X from a previous broken session: same
  -- texture, same parent, but NOT tracked via button._tldX.
  local orphan = CreateFrame("Button", nil, btn)
  orphan:SetSize(16, 16)
  orphan:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
  orphan:Show()
  assert(orphan._shown == true, "orphan should start visible")
  assert(#btn._children == 1 and btn._children[1] == orphan, "orphan should be a child of btn")

  -- Now render a SENTINEL desc on this button. The initializer must scan
  -- the children, find the orphan by texture, and hide it.
  rootDesc.children[4]._initializers[1](btn, rootDesc.children[4], nil)
  if orphan._shown ~= false then
    fail("orphan-cleanup: unmarked orphan X (with UI-StopButton texture) must be hidden when the button renders a sentinel row")
  end
  io.write("OK orphan-cleanup: unmarked orphan X hidden on sentinel render\n")

  -- And render a LOADOUT on the same button: orphan still hidden, new X created.
  orphan:Show()  -- re-show the orphan to test the loadout path
  rootDesc.children[1]._initializers[1](btn, rootDesc.children[1], nil)
  if orphan._shown ~= false then
    fail("orphan-cleanup: orphan must be hidden even when rendering a loadout (we replace it with our cached one)")
  end
  if not btn._tldX or btn._tldX._shown ~= true then
    fail("orphan-cleanup: new cached X must still be created on loadout render")
  end
  io.write("OK orphan-cleanup: orphan hidden + new cached X shown on loadout render\n")
end

-- ---- Button-pool reuse: button that rendered a loadout now renders a sentinel ----
-- This is the failure mode the user reported: X appearing on Import/Share/etc.
-- Same button reused across menu opens — cached X must be hidden when the
-- new desc is a non-loadout row.
do
  local btn = newRowButton()
  rootDesc.children[1]._initializers[1](btn, rootDesc.children[1], nil)
  assert(btn._tldX, "expected X after rendering loadout")
  assert(btn._tldX._shown == true, "expected X shown after rendering loadout")

  -- Now reuse the SAME button for the sentinel row.
  rootDesc.children[4]._initializers[1](btn, rootDesc.children[4], nil)
  if btn._tldX._shown ~= false then
    fail("button-pool reuse: X must be HIDDEN when same button is reused for a sentinel row, got _shown=" .. tostring(btn._tldX._shown))
  end
  io.write("OK button-pool reuse: cached X hidden when sentinel reuses a loadout-button\n")

  -- And reusing for Starter Build also hides
  rootDesc.children[3]._initializers[1](btn, rootDesc.children[3], nil)
  if btn._tldX._shown ~= false then
    fail("button-pool reuse: X must be HIDDEN when same button is reused for Starter Build")
  end
  io.write("OK button-pool reuse: cached X hidden when Starter Build reuses a loadout-button\n")

  -- And reusing back for a loadout SHOWS it again
  rootDesc.children[2]._initializers[1](btn, rootDesc.children[2], nil)
  if btn._tldX._shown ~= true then
    fail("button-pool reuse: X must be SHOWN when sentinel-rendered button is reused for a loadout")
  end
  io.write("OK button-pool reuse: cached X re-shown when loadout reuses a sentinel-button\n")
end

-- ---- Sanity: re-invoking the hook does not re-wrap (no recursion) ----
do
  local before = mockDropdown.menuGenerator
  local ok3, hookErr = pcall(function() mockLoadSystem:UpdateSelectionOptions() end)
  if not ok3 then fail("second UpdateSelectionOptions errored: " .. tostring(hookErr)) end
  -- Blizzard's stub UpdateSelectionOptions installs a fresh blizzGen, so
  -- our hook wraps it freshly; that's expected. What we don't want is a
  -- runaway (e.g., wrapping our wrapper, infinite indirection).
  assert(type(mockDropdown.menuGenerator) == "function", "menuGenerator must remain a function")
  io.write("OK second UpdateSelectionOptions invocation safe (no recursion / no field-on-function indexing)\n")
end

io.write("--- ALL CHECKS PASSED ---\n")
os.exit(0)
