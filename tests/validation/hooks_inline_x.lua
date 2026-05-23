-- Standalone pre-validation for Hooks.lua. Verifies the inline [X] uses
-- the canonical Blizzard menu compositor APIs and does NOT taint the
-- session-wide menu button pool.
--
-- Run via: lua tests/validation/hooks_inline_x.lua
-- Exits 0 on all-green, 1 on any failure.
--
-- Why this file exists: addon-dev-learning.md item B1 documents the bug
-- where raw key writes on pooled menu buttons, insecure CreateFrame with
-- pooled parent, and iteration of Blizzard-owned children all leak taint
-- onto the pool. The taint surfaces session-wide at every secure access
-- of CastingBarTypeInfo (e.g. CastingBarMixin:GetTypeInfo on
-- UNIT_SPELLCAST_START). The fix uses Menu.ModifyMenu + MenuTemplates.Attach*
-- so the compositor cleans every attachment on menu close.

local function fail(msg)
  io.write("FAIL: ", msg, "\n")
  os.exit(1)
end

unpack = unpack or table.unpack

-- ---- Frame stub ----
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
  return f
end

-- ---- Blizzard global stubs ----

function hooksecurefunc(t, name, fn)
  local orig = t[name]
  assert(type(orig) == "function", "hooksecurefunc: " .. name .. " is not a function")
  t[name] = function(...)
    orig(...)
    fn(...)
  end
end

-- Track CreateFrame calls so we can assert nothing creates a Button with a
-- pooled-menu-button parent (the taint anti-pattern).
local createFrameCalls = {}
CreateFrame = function(kind, name, parent, template)
  table.insert(createFrameCalls, { kind = kind, name = name, parent = parent, template = template })
  local f = makeFrame(name)
  if parent and parent._children then
    table.insert(parent._children, f)
  end
  return f
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
Constants = { TraitConsts = { STARTER_BUILD_TRAIT_CONFIG_ID = -42 } }

-- Menu / MenuTemplates stubs — record every call so we can assert the
-- new safe pattern is used.
local modifyMenuCalls = {}
local attachUtilityCalls = {}
local clickHandlerCalls = {}
local tooltipCalls = {}
local lockedStateCalls = {}

Menu = {
  ModifyMenu = function(tag, callback)
    table.insert(modifyMenuCalls, { tag = tag, callback = callback })
  end,
}

-- Each attached utility button is a fake "menuButton-pooled" frame the
-- compositor manages. Its OnClick is set via SetUtilityButtonClickHandler.
local function makeUtilityButton(parent, textureAsset, width, height)
  local btn = makeFrame("utilityButton", {
    _parent = parent,
    _textureAsset = textureAsset,
    _w = width, _h = height,
    _locked = nil,  -- nil = not set; true/false = SetUtilityButtonLockedEnabledState called
    _onClick = nil,
    _tooltipText = nil,
  })
  btn._shown = true
  return btn
end

MenuTemplates = {
  AttachUtilityButton = function(parent, textureAsset, width, height)
    local btn = makeUtilityButton(parent, textureAsset, width, height)
    table.insert(attachUtilityCalls, {
      parent = parent, textureAsset = textureAsset,
      width = width, height = height, button = btn,
    })
    return btn
  end,
  SetUtilityButtonClickHandler = function(button, handler)
    button._onClick = handler
    table.insert(clickHandlerCalls, { button = button, handler = handler })
  end,
  SetUtilityButtonTooltipText = function(button, text)
    button._tooltipText = text
    table.insert(tooltipCalls, { button = button, text = text })
  end,
  SetUtilityButtonLockedEnabledState = function(button, value)
    button._locked = value
    table.insert(lockedStateCalls, { button = button, value = value })
  end,
}

-- LoadSystem / PlayerSpellsFrame — minimal shape for Hooks.Install.
local mockLoadSystem = makeFrame("LoadSystem", {
  Dropdown = makeFrame("LoadSystemDropdown"),
})
mockLoadSystem._shown = true
function mockLoadSystem:UpdateSelectionOptions() end

PlayerSpellsFrame = makeFrame("PlayerSpellsFrame", {
  TalentsFrame = makeFrame("TalentsFrame", {
    LoadSystem = mockLoadSystem,
    SearchBox = makeFrame("SearchBox"),
  }),
})

-- Suppress addon prints.
print = function(...) end

-- ---- Static anti-pattern checks on the source file ----
-- These are belt-and-suspenders against the bug ever returning: any
-- future edit that reintroduces a tainting pattern fails the test even
-- if the runtime path the test exercises doesn't happen to hit it.

local hooksPath = "C:/Users/tekau/Documents/Codex/TalentLoadoutDeleter/src/Hooks.lua"
local fh = io.open(hooksPath, "r")
if not fh then fail("cannot open " .. hooksPath) end
local hooksSource = fh:read("*a")
fh:close()

if hooksSource:find("_tldX") then
  fail("static: Hooks.lua must not write the raw key '_tldX' on pooled menu buttons (compositor taint)")
end
if hooksSource:find("_tldOwned") then
  fail("static: Hooks.lua must not write the raw key '_tldOwned' on pooled menu buttons (compositor taint)")
end
if hooksSource:find("menuButton:GetChildren") then
  fail("static: Hooks.lua must not iterate menuButton:GetChildren() (taints Blizzard-owned pooled widgets)")
end
if hooksSource:find("CreateFrame%([^)]*menuButton") then
  fail("static: Hooks.lua must not CreateFrame(...) with a pooled menuButton parent (insecure-parent taint)")
end
if not hooksSource:find('Menu%.ModifyMenu%(%s*"MENU_CLASS_TALENT_PROFILE"') then
  fail("static: Hooks.lua must call Menu.ModifyMenu(\"MENU_CLASS_TALENT_PROFILE\", ...) to decorate the loadout dropdown")
end
if not hooksSource:find("MenuTemplates%.AttachUtilityButton") then
  fail("static: Hooks.lua must create the X via MenuTemplates.AttachUtilityButton (compositor-managed)")
end
io.write("OK static checks: no taint anti-patterns; canonical Menu.ModifyMenu + MenuTemplates path used\n")

-- ---- Load Hooks.lua ----

local addonName = "TalentLoadoutDeleter"
local ns = {}
local Hooks_chunk, err = loadfile(hooksPath)
if err then fail("loadfile: " .. tostring(err)) end

local ok, loadErr = pcall(Hooks_chunk, addonName, ns)
if not ok then fail("chunk pcall: " .. tostring(loadErr)) end

assert(ns.Hooks, "ns.Hooks should be set")
assert(type(ns.Hooks.Install) == "function", "ns.Hooks.Install missing")

-- ---- Install ----
local ok2, installErr = pcall(ns.Hooks.Install)
if not ok2 then fail("Hooks.Install errored: " .. tostring(installErr)) end
io.write("OK Hooks.Install completed without error\n")

-- ---- Assert Menu.ModifyMenu was called exactly once with the right tag ----
if #modifyMenuCalls ~= 1 then
  fail("expected exactly 1 Menu.ModifyMenu call, got " .. #modifyMenuCalls)
end
if modifyMenuCalls[1].tag ~= "MENU_CLASS_TALENT_PROFILE" then
  fail("Menu.ModifyMenu was called with tag '" .. tostring(modifyMenuCalls[1].tag) ..
       "', expected 'MENU_CLASS_TALENT_PROFILE'")
end
io.write("OK Menu.ModifyMenu(\"MENU_CLASS_TALENT_PROFILE\", ...) registered exactly once\n")

-- ---- Invoke the callback with a fake rootDescription ----
-- Build 4 children: loadout 201, active 101, Starter Build (-42), sentinel (nil).
local function buildRootDescription()
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
  rootDesc.children[4] = mkDesc(nil)
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

local rootDesc = buildRootDescription()
local mockOwner = mockLoadSystem.Dropdown
local cb = modifyMenuCalls[1].callback

-- Reset trackers before running the callback so we can assert exact counts.
attachUtilityCalls = {}
clickHandlerCalls = {}
tooltipCalls = {}
lockedStateCalls = {}
createFrameCalls = {}

local okCb, cbErr = pcall(cb, mockOwner, rootDesc, nil)
if not okCb then fail("ModifyMenu callback errored: " .. tostring(cbErr)) end
io.write("OK ModifyMenu callback ran without error\n")

-- ---- Only loadout descs (1, 2) should have an initializer attached ----
if #rootDesc.children[1]._initializers ~= 1 then
  fail("loadout desc 201 must have 1 initializer, got " .. #rootDesc.children[1]._initializers)
end
if #rootDesc.children[2]._initializers ~= 1 then
  fail("active loadout desc 101 must have 1 initializer, got " .. #rootDesc.children[2]._initializers)
end
if #rootDesc.children[3]._initializers ~= 0 then
  fail("Starter Build desc must have 0 initializers (filtered as non-deletable), got "
       .. #rootDesc.children[3]._initializers)
end
if #rootDesc.children[4]._initializers ~= 0 then
  fail("sentinel desc (nil data) must have 0 initializers, got " .. #rootDesc.children[4]._initializers)
end
io.write("OK initializers attached only to loadout rows (skipped Starter Build + sentinel)\n")

-- ---- Fire each loadout initializer with a fake pooled menuButton ----

-- Child 1: non-active loadout 201
do
  local btn = makeFrame("pooledMenuButton")
  rootDesc.children[1]._initializers[1](btn, rootDesc.children[1], nil)

  -- Must have called AttachUtilityButton with our button as parent.
  local matched = nil
  for _, call in ipairs(attachUtilityCalls) do
    if call.parent == btn then matched = call; break end
  end
  if not matched then
    fail("non-active loadout: AttachUtilityButton was not called with the pooled menuButton as parent")
  end
  if not matched.textureAsset or not matched.textureAsset:find("UI%-StopButton") then
    fail("non-active loadout: AttachUtilityButton textureAsset should reference UI-StopButton, got "
         .. tostring(matched.textureAsset))
  end
  -- Click handler should be wired (Shift-gated DeleteConfig).
  local handlerForBtn = nil
  for _, call in ipairs(clickHandlerCalls) do
    if call.button == matched.button then handlerForBtn = call.handler; break end
  end
  if not handlerForBtn then
    fail("non-active loadout: SetUtilityButtonClickHandler was not called on the X")
  end
  -- Tooltip should be set.
  local tooltipForBtn = nil
  for _, call in ipairs(tooltipCalls) do
    if call.button == matched.button then tooltipForBtn = call.text; break end
  end
  if not tooltipForBtn then
    fail("non-active loadout: SetUtilityButtonTooltipText was not called")
  end
  -- Active row must NOT be the path taken — locked-enabled state should not be false here.
  for _, call in ipairs(lockedStateCalls) do
    if call.button == matched.button and call.value == false then
      fail("non-active loadout: must NOT lock the X to disabled (only the active row should)")
    end
  end
  io.write("OK non-active loadout (201): X created via Attach, click handler + tooltip wired\n")
end

-- Reset trackers for the active-row test.
local activeAttachCount = #attachUtilityCalls
local activeLockedCount = #lockedStateCalls

-- Child 2: active loadout 101
do
  local btn = makeFrame("pooledMenuButton")
  rootDesc.children[2]._initializers[1](btn, rootDesc.children[2], nil)

  local matched = nil
  for i = activeAttachCount + 1, #attachUtilityCalls do
    if attachUtilityCalls[i].parent == btn then matched = attachUtilityCalls[i]; break end
  end
  if not matched then
    fail("active loadout: AttachUtilityButton was not called with the pooled menuButton as parent")
  end
  -- Active row must be locked-disabled so the click does nothing and the
  -- texture desaturates via MenuTemplates.SetHierarchyEnabled.
  local locked = nil
  for i = activeLockedCount + 1, #lockedStateCalls do
    if lockedStateCalls[i].button == matched.button then locked = lockedStateCalls[i].value; break end
  end
  if locked ~= false then
    fail("active loadout: must call SetUtilityButtonLockedEnabledState(x, false) to disable+desaturate, got "
         .. tostring(locked))
  end
  io.write("OK active loadout (101): X created via Attach + locked to disabled (desaturates via hierarchy)\n")
end

-- ---- Shift gate on click ----
do
  -- Find a non-active click handler from the first call above.
  local handler = nil
  for _, call in ipairs(clickHandlerCalls) do
    -- Skip the active-row handler if present.
    local isActiveRow = false
    for _, lockCall in ipairs(lockedStateCalls) do
      if lockCall.button == call.button and lockCall.value == false then
        isActiveRow = true; break
      end
    end
    if not isActiveRow then handler = call.handler; break end
  end
  if not handler then fail("no non-active click handler available to test shift gate") end

  local deleteCalls = {}
  C_ClassTalents.DeleteConfig = function(id) table.insert(deleteCalls, id) end

  -- Shift NOT down → no delete.
  IsShiftKeyDown = function() return false end
  handler()
  if #deleteCalls ~= 0 then
    fail("shift gate: DeleteConfig called with Shift not held (got " .. #deleteCalls .. " calls)")
  end

  -- Shift down → delete fires with the desc's configID.
  IsShiftKeyDown = function() return true end
  handler()
  if #deleteCalls ~= 1 then
    fail("shift gate: DeleteConfig should fire once when Shift is held, got " .. #deleteCalls)
  end
  if deleteCalls[1] ~= 201 then
    fail("shift gate: DeleteConfig should receive configID 201, got " .. tostring(deleteCalls[1]))
  end
  io.write("OK shift gate: DeleteConfig blocked without Shift, fires with Shift on correct configID\n")
end

-- ---- No raw CreateFrame() with the pooled menuButton as parent ----
do
  for _, call in ipairs(createFrameCalls) do
    -- The pooledMenuButton stubs we created have ._name == "pooledMenuButton".
    if call.parent and call.parent._name == "pooledMenuButton" then
      fail("anti-pattern: CreateFrame(" .. tostring(call.kind) .. ", ...) was called with the pooled menuButton as parent")
    end
  end
  io.write("OK no insecure-parent CreateFrame on pooled menuButtons\n")
end

io.write("--- ALL CHECKS PASSED ---\n")
os.exit(0)
