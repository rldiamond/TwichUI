--[[
    RunSharingFrame displays received Mythic+ run logs and allows interaction (view, simulate, delete).
]]

local T = unpack(Twich)
local _G = _G
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local tinsert = _G.table.insert
local tremove = _G.table.remove
local date = _G.date

---@type MythicPlusModule
local MythicPlusModule = T:GetModule("MythicPlus")
---@type MythicPlusRunSharingSubmodule
local RunSharing = MythicPlusModule.RunSharing
---@type MythicPlusSimulatorSubmodule
local Simulator = MythicPlusModule.Simulator
---@type ConfigurationModule
local CM = T:GetModule("Configuration")

---@class MythicPlusRunSharingFrameSubmodule
local RunSharingFrame = MythicPlusModule.RunSharingFrame or {}
MythicPlusModule.RunSharingFrame = RunSharingFrame

-- ElvUI Integration
local E = _G.ElvUI and _G.ElvUI[1]
local Skins = E and E.GetModule and E:GetModule("Skins", true)

-- Constants
local ROW_HEIGHT = 20
local MAX_ROWS = 15

-- JSON Helpers (Copied from RunLogger to ensure availability)
local function IsArrayTable(t)
    if type(t) ~= "table" then return false end
    local count = 0
    local max = 0
    for k, _ in pairs(t) do
        if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
            return false
        end
        if k > max then max = k end
        count = count + 1
        if count > 5000 then return false end
    end
    return max == count
end

local function EscapeJSON(s)
    s = tostring(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\b", "\\b")
    s = s:gsub("\f", "\\f")
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    s = s:gsub("\t", "\\t")
    return s
end

local function EncodeJSON(v)
    local tv = type(v)
    if tv == "nil" then return "null" end
    if tv == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "null" end
        return tostring(v)
    end
    if tv == "boolean" then return v and "true" or "false" end
    if tv == "string" then return '"' .. EscapeJSON(v) .. '"' end
    if tv ~= "table" then return '"' .. EscapeJSON(tostring(v)) .. '"' end

    if IsArrayTable(v) then
        local parts = {}
        for i = 1, #v do
            parts[#parts + 1] = EncodeJSON(v[i])
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end

    local parts = {}
    for k, val in pairs(v) do
        local keyStr = (type(k) == "string") and k or tostring(k)
        parts[#parts + 1] = '"' .. EscapeJSON(keyStr) .. '":' .. EncodeJSON(val)
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

-- JSON Decoder (Minimal implementation)
local ParseValue

local function SkipWS(s, i)
    while true do
        local c = s:sub(i, i)
        if c == "" then return i end
        if c ~= " " and c ~= "\t" and c ~= "\r" and c ~= "\n" then
            return i
        end
        i = i + 1
    end
end

local function ParseString(s, i)
    if s:sub(i, i) ~= '"' then return nil, i, "expected string" end
    i = i + 1
    local out = {}
    while true do
        local c = s:sub(i, i)
        if c == "" then return nil, i, "unterminated string" end
        if c == '"' then return table.concat(out), i + 1, nil end
        if c == "\\" then
            local esc = s:sub(i + 1, i + 1)
            if esc == '"' or esc == "\\" or esc == "/" then
                out[#out + 1] = esc; i = i + 2
            elseif esc == "b" then
                out[#out + 1] = "\b"; i = i + 2
            elseif esc == "f" then
                out[#out + 1] = "\f"; i = i + 2
            elseif esc == "n" then
                out[#out + 1] = "\n"; i = i + 2
            elseif esc == "r" then
                out[#out + 1] = "\r"; i = i + 2
            elseif esc == "t" then
                out[#out + 1] = "\t"; i = i + 2
            elseif esc == "u" then
                local hex = s:sub(i + 2, i + 5)
                if not hex:match("^%x%x%x%x$") then return nil, i, "invalid unicode escape" end
                local code = tonumber(hex, 16)
                if code and code >= 32 and code <= 126 then out[#out + 1] = string.char(code) else out[#out + 1] = "?" end
                i = i + 6
            else
                return nil, i, "invalid escape"
            end
        else
            out[#out + 1] = c; i = i + 1
        end
    end
end

local function ParseNumber(s, i)
    local start = i
    if s:sub(i, i) == "-" then i = i + 1 end
    while s:sub(i, i):match("%d") do i = i + 1 end
    if s:sub(i, i) == "." then
        i = i + 1; while s:sub(i, i):match("%d") do i = i + 1 end
    end
    if s:sub(i, i):match("[eE]") then
        i = i + 1; if s:sub(i, i):match("[+-]") then i = i + 1 end; while s:sub(i, i):match("%d") do i = i + 1 end
    end
    local n = tonumber(s:sub(start, i - 1))
    if not n then return nil, start, "invalid number" end
    return n, i, nil
end

local function ParseArray(s, i)
    if s:sub(i, i) ~= "[" then return nil, i, "expected array" end
    i = i + 1
    local out = {}
    i = SkipWS(s, i)
    if s:sub(i, i) == "]" then return out, i + 1, nil end
    while true do
        local v, ni, err = ParseValue(s, i)
        if err then return nil, i, err end
        out[#out + 1] = v
        i = SkipWS(s, ni)
        local c = s:sub(i, i)
        if c == "," then
            i = SkipWS(s, i + 1)
        elseif c == "]" then
            return out, i + 1, nil
        else
            return nil, i, "expected ',' or ']'"
        end
    end
end

local function ParseObject(s, i)
    if s:sub(i, i) ~= "{" then return nil, i, "expected object" end
    i = i + 1
    local out = {}
    i = SkipWS(s, i)
    if s:sub(i, i) == "}" then return out, i + 1, nil end
    while true do
        local key, ni, err = ParseString(s, i)
        if err then return nil, i, err end
        i = SkipWS(s, ni)
        if s:sub(i, i) ~= ":" then return nil, i, "expected ':'" end
        i = SkipWS(s, i + 1)
        local v, ni2, err2 = ParseValue(s, i)
        if err2 then return nil, i, err2 end
        out[key] = v
        i = SkipWS(s, ni2)
        local c = s:sub(i, i)
        if c == "," then
            i = SkipWS(s, i + 1)
        elseif c == "}" then
            return out, i + 1, nil
        else
            return nil, i, "expected ',' or '}'"
        end
    end
end

ParseValue = function(s, i)
    i = SkipWS(s, i)
    local c = s:sub(i, i)
    if c == '"' then return ParseString(s, i) end
    if c == "{" then return ParseObject(s, i) end
    if c == "[" then return ParseArray(s, i) end
    if c == "-" or c:match("%d") then return ParseNumber(s, i) end
    if s:sub(i, i + 3) == "true" then return true, i + 4, nil end
    if s:sub(i, i + 4) == "false" then return false, i + 5, nil end
    if s:sub(i, i + 3) == "null" then return nil, i + 4, nil end
    return nil, i, "unexpected token"
end

local function DecodeJSON(s)
    if type(s) ~= "string" or s == "" then return nil, "empty input" end
    local v, i, err = ParseValue(s, 1)
    if err then return nil, err end
    return v, nil
end

function RunSharingFrame:Initialize()
    if self.initialized then return end
    self.initialized = true
    self:CreateFrame()
end

function RunSharingFrame:Toggle()
    if not self.frame then
        self:CreateFrame()
    end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:UpdateList()
        self:UpdateSpeedSlider()
        self.frame:Show()
    end
end

function RunSharingFrame:GetDB()
    local key = "TwichUIRunLoggerDB"
    local db = _G[key]
    if type(db) ~= "table" then
        db = { version = 1, remoteRuns = {} }
        _G[key] = db
    end
    if not db.remoteRuns then db.remoteRuns = {} end
    return db
end

function RunSharingFrame:CreateFrame()
    local frame = CreateFrame("Frame", "TwichUI_RunSharingFrame", UIParent, "BackdropTemplate")
    frame:SetSize(800, 500)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Skinning
    if Skins then
        Skins:HandleFrame(frame, true, nil, -5, 0, -5, 0)
    else
        if frame.SetTemplate then
            frame:SetTemplate("Transparent")
        else
            frame:SetBackdrop({
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            frame:SetBackdropColor(0, 0, 0, 0.9)
        end
    end

    self.frame = frame

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText("Received Mythic+ Runs")

    -- Close Button
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    if Skins then Skins:HandleCloseButton(close) end

    -- List ScrollFrame
    local listScroll = CreateFrame("ScrollFrame", "TwichUI_RunSharing_ListScroll", frame, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -50)
    listScroll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 50)
    listScroll:SetWidth(250)
    if Skins and listScroll.ScrollBar then Skins:HandleScrollBar(listScroll.ScrollBar) end

    -- List Content
    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetSize(250, 1)
    listScroll:SetScrollChild(listContent)
    self.listContent = listContent

    -- Separator
    local sep = frame:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    sep:SetPoint("TOPLEFT", listScroll, "TOPRIGHT", 25, 0)
    sep:SetPoint("BOTTOMLEFT", listScroll, "BOTTOMRIGHT", 25, 0)
    sep:SetWidth(1)

    -- Details / JSON View
    local detailsScroll = CreateFrame("ScrollFrame", "TwichUI_RunSharing_DetailsScroll", frame,
        "UIPanelScrollFrameTemplate")
    detailsScroll:SetPoint("TOPLEFT", sep, "TOPRIGHT", 5, 0)
    detailsScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 80) -- Raised bottom to make room for slider
    if Skins and detailsScroll.ScrollBar then Skins:HandleScrollBar(detailsScroll.ScrollBar) end

    local detailsEditBox = CreateFrame("EditBox", nil, detailsScroll)
    detailsEditBox:SetMultiLine(true)
    detailsEditBox:SetAutoFocus(false)
    detailsEditBox:SetFontObject("ChatFontNormal")
    detailsEditBox:SetWidth(480)
    detailsEditBox:SetScript("OnTextChanged", function(self)
        detailsScroll:UpdateScrollChildRect()
    end)
    detailsScroll:SetScrollChild(detailsEditBox)
    self.detailsEditBox = detailsEditBox

    -- Speed Slider
    local speedSlider = CreateFrame("Slider", "TwichUI_RunSharing_SpeedSlider", frame, "OptionsSliderTemplate")
    speedSlider:SetPoint("BOTTOM", frame, "BOTTOM", 0, 50)
    speedSlider:SetMinMaxValues(0.5, 50)
    speedSlider:SetValue(10)
    speedSlider:SetWidth(200)
    speedSlider:SetOrientation("HORIZONTAL")

    _G[speedSlider:GetName() .. 'Low']:SetText('0.5x')
    _G[speedSlider:GetName() .. 'High']:SetText('50x')
    _G[speedSlider:GetName() .. 'Text']:SetText('Sim Speed: 10x')

    speedSlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value * 10) / 10
        _G[self:GetName() .. 'Text']:SetText('Sim Speed: ' .. val .. 'x')
        CM:SetProfileSettingSafe("developer.mythicplus.simulator.playbackSpeed", val)
    end)

    if Skins then Skins:HandleSliderFrame(speedSlider) end
    self.speedSlider = speedSlider

    -- Buttons
    local btnWidth = 100
    local btnHeight = 24

    -- Simulate Button
    local simBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    simBtn:SetSize(btnWidth, btnHeight)
    simBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    simBtn:SetText("Simulate")
    simBtn:SetScript("OnClick", function() self:OnSimulateClick() end)
    if Skins then Skins:HandleButton(simBtn) end
    self.simBtn = simBtn

    -- Stop Button
    local stopBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    stopBtn:SetSize(btnWidth, btnHeight)
    stopBtn:SetPoint("RIGHT", simBtn, "LEFT", -10, 0)
    stopBtn:SetText("Stop")
    stopBtn:SetScript("OnClick", function() self:OnStopClick() end)
    if Skins then Skins:HandleButton(stopBtn) end
    self.stopBtn = stopBtn

    -- Stop Button
    local stopBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    stopBtn:SetSize(btnWidth, btnHeight)
    stopBtn:SetPoint("RIGHT", simBtn, "LEFT", -10, 0)
    stopBtn:SetText("Stop")
    stopBtn:SetScript("OnClick", function() self:OnStopClick() end)
    if Skins then Skins:HandleButton(stopBtn) end
    self.stopBtn = stopBtn

    -- Delete Button
    local delBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    delBtn:SetSize(btnWidth, btnHeight)
    delBtn:SetPoint("RIGHT", stopBtn, "LEFT", -10, 0)
    delBtn:SetText("Delete")
    delBtn:SetScript("OnClick", function() self:OnDeleteClick() end)
    if Skins then Skins:HandleButton(delBtn) end
    self.delBtn = delBtn

    -- Clear All Button
    local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearBtn:SetSize(btnWidth, btnHeight)
    clearBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    clearBtn:SetText("Clear All")
    clearBtn:SetScript("OnClick", function() self:OnClearAllClick() end)
    if Skins then Skins:HandleButton(clearBtn) end
    self.clearBtn = clearBtn

    -- Import Button
    local importBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    importBtn:SetSize(btnWidth, btnHeight)
    importBtn:SetPoint("LEFT", clearBtn, "RIGHT", 10, 0)
    importBtn:SetText("Import JSON")
    importBtn:SetScript("OnClick", function() self:OnImportClick() end)
    if Skins then Skins:HandleButton(importBtn) end
    self.importBtn = importBtn

    self.rows = {}
end

function RunSharingFrame:UpdateSpeedSlider()
    if not self.speedSlider then return end
    local speed = CM:GetProfileSettingSafe("developer.mythicplus.simulator.playbackSpeed", 10)
    self.speedSlider:SetValue(speed)
    _G[self.speedSlider:GetName() .. 'Text']:SetText('Sim Speed: ' .. speed .. 'x')
end

function RunSharingFrame:UpdateList()
    local db = self:GetDB()
    local runs = db.remoteRuns or {}

    -- Clear existing rows
    for _, row in ipairs(self.rows) do
        row:Hide()
    end

    local yOffset = 0
    for i, run in ipairs(runs) do
        local row = self.rows[i]
        if not row then
            row = CreateFrame("Button", nil, self.listContent)
            row:SetSize(250, ROW_HEIGHT)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

            local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", 5, 0)
            text:SetJustifyH("LEFT")
            row.text = text

            row:SetScript("OnClick", function() self:SelectRun(i) end)
            self.rows[i] = row
        end

        row:SetPoint("TOPLEFT", 0, -yOffset)
        row:Show()

        local dateStr = date("%m/%d %H:%M", run.receivedAt)
        local sender = run.sender or "Unknown"
        local dungeon = run.data and run.data.dungeonName or "Unknown"
        local level = run.data and run.data.keystoneLevel or "?"

        row.text:SetText(string.format("%s: +%s %s (%s)", dateStr, level, dungeon, sender))

        yOffset = yOffset + ROW_HEIGHT
    end

    self.listContent:SetHeight(math.max(1, yOffset))
end

function RunSharingFrame:SelectRun(index)
    self.selectedIndex = index
    local db = self:GetDB()
    local run = db.remoteRuns[index]

    if run and run.data then
        local json = EncodeJSON(run.data)
        self.detailsEditBox:SetText(json)
    else
        self.detailsEditBox:SetText("")
    end
end

function RunSharingFrame:OnSimulateClick()
    if not self.selectedIndex then return end
    local db = self:GetDB()
    local run = db.remoteRuns[self.selectedIndex]

    if run and run.data then
        if Simulator and Simulator.StartSimulationFromData then
            Simulator:StartSimulationFromData(run.data)
        elseif Simulator and Simulator.StartSimulationFromJSON then
            -- Fallback if we can convert to JSON, but we can't easily.
            -- We should add StartSimulationFromData to Simulator.lua
            print("Simulator: StartSimulationFromData not found.")
        end
    end
end

function RunSharingFrame:OnStopClick()
    if Simulator and Simulator.StopSimulation then
        Simulator:StopSimulation()
    end
end

function RunSharingFrame:OnDeleteClick()
    if not self.selectedIndex then return end
    local db = self:GetDB()
    tremove(db.remoteRuns, self.selectedIndex)
    self.selectedIndex = nil
    self.detailsEditBox:SetText("")
    self:UpdateList()
end

function RunSharingFrame:OnClearAllClick()
    local db = self:GetDB()
    db.remoteRuns = {}
    self.selectedIndex = nil
    self.detailsEditBox:SetText("")
    self:UpdateList()
end

function RunSharingFrame:OnImportClick()
    self:ShowImportDialog()
end

function RunSharingFrame:ShowImportDialog()
    if self.importFrame then
        self.importFrame:Show()
        return
    end

    local frame = CreateFrame("Frame", "TwichUI_RunSharing_ImportFrame", self.frame, "BackdropTemplate")
    frame:SetSize(500, 400)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(self.frame:GetFrameLevel() + 10)

    if Skins then
        Skins:HandleFrame(frame, true, nil, -5, 0, -5, 0)
    else
        if frame.SetTemplate then
            frame:SetTemplate("Transparent")
        else
            frame:SetBackdrop({
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 16,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            frame:SetBackdropColor(0, 0, 0, 0.9)
        end
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("Import Run JSON")

    local scroll = CreateFrame("ScrollFrame", "TwichUI_RunSharing_ImportScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -40)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 50)
    if Skins and scroll.ScrollBar then Skins:HandleScrollBar(scroll.ScrollBar) end

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(true)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(450)
    editBox:SetScript("OnTextChanged", function(self)
        scroll:UpdateScrollChildRect()
    end)
    scroll:SetScrollChild(editBox)

    local importBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    importBtn:SetSize(100, 24)
    importBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function()
        local text = editBox:GetText()
        local data, err = DecodeJSON(text)
        if not data then
            print("TwichUI: Import failed - " .. (err or "Unknown error"))
            return
        end

        -- Basic validation
        if type(data) ~= "table" or not data.events then
            print("TwichUI: Invalid run data format")
            return
        end

        local db = self:GetDB()
        tinsert(db.remoteRuns, {
            sender = "Imported",
            receivedAt = _G.time(),
            data = data
        })
        self:UpdateList()
        frame:Hide()
        editBox:SetText("")
        print("TwichUI: Run imported successfully")
    end)
    if Skins then Skins:HandleButton(importBtn) end

    local cancelBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cancelBtn:SetSize(100, 24)
    cancelBtn:SetPoint("RIGHT", importBtn, "LEFT", -10, 0)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function() frame:Hide() end)
    if Skins then Skins:HandleButton(cancelBtn) end

    self.importFrame = frame
end
