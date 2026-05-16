-- TalentLoadoutDeleter / Window.lua
-- Bulk-manager window.

local _, ns = ...
ns = ns or {}

local Window = {}
ns.state = ns.state or { isBulkDeleting = false }
local frame
local updateFooter  -- forward-declared; defined below so createFrame closures
                    -- (selectAll OnClick) capture the local upvalue, not _G.

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

  local header = CreateFrame("Frame", nil, f)
  header:SetHeight(20)
  header:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -32)
  header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -32, -32)

  local selectAll = CreateFrame("CheckButton", nil, header, "UICheckButtonTemplate")
  selectAll:SetSize(20, 20)
  selectAll:SetPoint("LEFT", header, "LEFT", 0, 0)
  f.selectAll = selectAll

  local selectAllLabel = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  selectAllLabel:SetPoint("LEFT", selectAll, "RIGHT", 4, 0)
  selectAllLabel:SetText("Select All")

  local countLabel = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  countLabel:SetPoint("RIGHT", header, "RIGHT", 0, 0)
  countLabel:SetText("0 of 0 selected")
  f.countLabel = countLabel

  -- Scrollable row container.
  local scroll = CreateFrame("ScrollFrame", f:GetName() .. "Scroll",
    f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -56)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 48)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(340, 1)  -- height adjusted per refresh
  scroll:SetScrollChild(content)
  f.scrollContent = content
  f.scrollRows = {}

  local footer = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  footer:SetSize(340, 28)
  footer:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
  footer:SetText("Delete Selected (0)")
  footer:Disable()
  f.footer = footer

  footer:SetScript("OnClick", function()
    local toDelete = {}
    for _, r in ipairs(f.scrollRows) do
      if r:IsShown() and r.check:GetChecked() and not r.isActive then
        table.insert(toDelete, r.configID)
      end
    end
    if #toDelete == 0 then return end

    if ns.state then ns.state.isBulkDeleting = true end
    for _, id in ipairs(toDelete) do
      pcall(C_ClassTalents.DeleteConfig, id)
    end
    if ns.state then ns.state.isBulkDeleting = false end

    Window.Refresh()
  end)

  selectAll:SetScript("OnClick", function(self)
    local checked = self:GetChecked()
    for _, r in ipairs(f.scrollRows) do
      if r:IsShown() and not r.isActive then
        r.check:SetChecked(checked)
      end
    end
    updateFooter(f)
  end)

  f:Hide()
  return f
end

local function currentSpecName()
  local specIndex = GetSpecialization()
  if not specIndex then return "" end
  local _, name = GetSpecializationInfo(specIndex)
  return name or ""
end

updateFooter = function(f)
  local selected = 0
  local total = 0
  for _, r in ipairs(f.scrollRows) do
    if r:IsShown() and not r.isActive then
      total = total + 1
      if r.check:GetChecked() then selected = selected + 1 end
    end
  end
  f.footer:SetText(("Delete Selected (%d)"):format(selected))
  if selected > 0 then f.footer:Enable() else f.footer:Disable() end
  if f.countLabel then
    f.countLabel:SetText(("%d of %d selected"):format(selected, total))
  end
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
    r.check:SetScript("OnClick", function()
      updateFooter(content:GetParent():GetParent()) -- content -> scroll -> frame
    end)

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
  updateFooter(content:GetParent():GetParent())
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
