-- TalentLoadoutDeleter / Window.lua
-- Bulk-manager window.

local _, ns = ...
ns = ns or {}

local Window = {}
local frame

local function createFrame()
  local f = CreateFrame("Frame", "TalentLoadoutDeleterWindow",
    UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(380, 480)
  f:SetPoint("TOPRIGHT", PlayerSpellsFrame or UIParent, "TOPLEFT", -4, 0)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  f.TitleText = f.TitleText or _G[f:GetName() .. "TitleText"]
  if f.TitleText then
    f.TitleText:SetText("Talent Loadouts")
  end

  -- Scrollable row container.
  local scroll = CreateFrame("ScrollFrame", f:GetName() .. "Scroll",
    f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -36)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 48)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(340, 1)  -- height adjusted per refresh
  scroll:SetScrollChild(content)
  f.scrollContent = content
  f.scrollRows = {}

  f:Hide()
  return f
end

local ROW_HEIGHT = 24

local function renderRows(content, rows, savedRowFrames)
  -- Reuse existing row frames; create more as needed.
  for i = #savedRowFrames + 1, #rows do
    local r = CreateFrame("Frame", nil, content)
    r:SetHeight(ROW_HEIGHT)
    r:SetPoint("LEFT", content, "LEFT", 0, 0)
    r:SetPoint("RIGHT", content, "RIGHT", 0, 0)

    r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
    r.check:SetSize(20, 20)
    r.check:SetPoint("LEFT", r, "LEFT", 0, 0)

    r.label = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.label:SetPoint("LEFT", r.check, "RIGHT", 4, 0)
    r.label:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    r.label:SetJustifyH("LEFT")

    savedRowFrames[i] = r
  end

  for i, row in ipairs(rows) do
    local r = savedRowFrames[i]
    r.configID = row.id
    r.isActive = row.isActive
    if row.isActive then
      r.label:SetText(row.name .. " |cff888888[Active]|r")
      r.check:SetChecked(false)
      r.check:Disable()
    else
      r.label:SetText(row.name)
      r.check:Enable()
      r.check:SetChecked(false)
    end
    r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    r:Show()
  end

  -- Hide any leftover rows from a previous, longer list.
  for i = #rows + 1, #savedRowFrames do
    savedRowFrames[i]:Hide()
  end

  content:SetHeight(math.max(1, #rows * ROW_HEIGHT))
end

local function currentSpecName()
  local specIndex = GetSpecialization()
  if not specIndex then return "" end
  local _, name = GetSpecializationInfo(specIndex)
  return name or ""
end

function Window.Refresh()
  if not frame then return end
  if frame.TitleText then
    local specName = currentSpecName()
    if specName ~= "" then
      frame.TitleText:SetText("Talent Loadouts — " .. specName)
    else
      frame.TitleText:SetText("Talent Loadouts")
    end
  end

  local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID()
  local activeID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
  local rows = (ns.Data and ns.Data.GetLoadouts and specID)
    and ns.Data.GetLoadouts(specID, activeID)
    or {}

  renderRows(frame.scrollContent, rows, frame.scrollRows)
end

function Window.Toggle()
  if not frame then
    frame = createFrame()
  end
  if frame:IsShown() then
    frame:Hide()
  else
    Window.Refresh()
    frame:Show()
  end
end

ns.Window = Window
