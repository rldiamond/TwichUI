--[[
    RunSharing handles the transmission of run data between players.
    Uses AceComm-3.0 and AceSerializer-3.0 for efficient data transfer.
]]

local T = unpack(Twich)
local _G = _G

---@type MythicPlusModule
local MythicPlusModule = T:GetModule("MythicPlus")

---@class MythicPlusRunSharingSubmodule
---@field enabled boolean
---@field receiver string|nil
local RunSharing = MythicPlusModule.RunSharing or {}
MythicPlusModule.RunSharing = RunSharing

---@type LoggerModule
local Logger = T:GetModule("Logger")
---@type ConfigurationModule
local CM = T:GetModule("Configuration")
---@type ToolsModule
local Tools = T:GetModule("Tools")

local time = _G.time
local UnitName = _G.UnitName
local LibStub = _G.LibStub
local C_Timer = _G.C_Timer

local PREFIX = "TWICH_RL"

-- Embed Ace libraries
local AceComm = LibStub("AceComm-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")

AceComm:Embed(RunSharing)
AceSerializer:Embed(RunSharing)

local function NotifyConfigChanged()
    local ACR = (T.Libs and T.Libs.AceConfigRegistry) or LibStub("AceConfigRegistry-3.0-ElvUI", true) or
        LibStub("AceConfigRegistry-3.0", true)
    if ACR then
        ACR:NotifyChange("ElvUI")
    end
end

---@return TwichUIRunLoggerDB
local function GetDB()
    local key = "TwichUIRunLoggerDB"
    local db = _G[key]
    if type(db) ~= "table" then
        db = { version = 1 }
        _G[key] = db
    end
    if not db.remoteRuns then
        db.remoteRuns = {}
    end

    if type(db.registeredReceivers) ~= "table" then
        db.registeredReceivers = {}
    end
    return db
end

function RunSharing:Initialize()
    if self.initialized then return end
    self.initialized = true

    self:RegisterComm(PREFIX, "OnCommReceived")

    self.OnRunAcknowledged = Tools.Callback:New()
    self.OnConnectionEstablished = Tools.Callback:New()
    self.OnReceiverRegistered = Tools.Callback:New()

    local db = GetDB()
    self.receiver = db.linkedReceiver
    -- Persist registrations across /reload.
    -- Key: character name (as seen by AceComm sender), Value: lastSeenUnix
    self.registeredReceivers = db.registeredReceivers
    self.connectionStatus = "NONE"

    -- Status for registration operations against the configured "Register With" target.
    self.registerWithStatus = self.registerWithStatus or "NONE"           -- NONE|PENDING|SUCCESS|FAILED
    self.registerWithTarget = self.registerWithTarget or nil
    self.registrationCheckStatus = self.registrationCheckStatus or "NONE" -- NONE|PENDING|SUCCESS|FAILED
    self.registrationCheckTarget = self.registrationCheckTarget or nil
    self.registrationCheckResult = self.registrationCheckResult or nil    -- boolean|nil
end

function RunSharing:SetReceiver(name)
    local db = GetDB()
    db.linkedReceiver = name
    self.receiver = name
    Logger.Info("Run Sharing linked to: " .. (name or "None"))
end

---@return string[]
function RunSharing:GetRecipients()
    local recipients = {}
    local seen = {}

    local function Add(name)
        if type(name) ~= "string" or name == "" then return end
        if not seen[name] then
            seen[name] = true
            recipients[#recipients + 1] = name
        end
    end

    Add(self.receiver)

    if type(self.registeredReceivers) == "table" then
        local myName = type(UnitName) == "function" and UnitName("player") or nil
        for name, _ in pairs(self.registeredReceivers) do
            if not myName or name ~= myName then
                Add(name)
            end
        end
    end

    return recipients
end

---@return string[]
function RunSharing:GetRegisteredReceiversList()
    local out = {}
    if type(self.registeredReceivers) ~= "table" then
        return out
    end

    for name in pairs(self.registeredReceivers) do
        if type(name) == "string" and name ~= "" then
            out[#out + 1] = name
        end
    end
    table.sort(out)
    return out
end

function RunSharing:ClearRegisteredReceivers()
    if type(self.registeredReceivers) ~= "table" then
        return
    end

    for name in pairs(self.registeredReceivers) do
        self.registeredReceivers[name] = nil
    end

    NotifyConfigChanged()
end

---@param targetName string|nil
function RunSharing:RegisterToReceive(targetName)
    local target = targetName
        or CM:GetProfileSettingSafe("developer.mythicplus.runSharing.registerWith", nil)
    if type(target) ~= "string" or target == "" then return end

    local payload = { type = "REGISTER", ts = time() }
    local serialized = self:Serialize(payload)
    if serialized then
        self:SendCommMessage(PREFIX, serialized, "WHISPER", target)
    end
end

---@param targetName string|nil
---@param silent boolean|nil
function RunSharing:RegisterWithTarget(targetName, silent)
    local target = targetName
        or CM:GetProfileSettingSafe("developer.mythicplus.runSharing.registerWith", nil)
    if type(target) ~= "string" or target == "" then return end

    -- Send the registration request
    self:RegisterToReceive(target)

    -- Then ping the target so we can show a success/fail indicator (online + addon present)
    local payload = { type = "PING", silent = true, purpose = "REGISTER" }
    local serialized = self:Serialize(payload)
    if not serialized then return end

    self.registerWithTarget = target
    self.registerWithStatus = "PENDING"
    self._registerPingToken = (self._registerPingToken or 0) + 1
    local token = self._registerPingToken

    self:SendCommMessage(PREFIX, serialized, "WHISPER", target)
    NotifyConfigChanged()

    if not silent then
        print("|cff9580ffTwichUI:|r Sending registration request to " .. target .. "...")
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(5, function()
            if self.registerWithStatus == "PENDING" and self._registerPingToken == token then
                self.registerWithStatus = "FAILED"
                NotifyConfigChanged()
            end
        end)
    end
end

---@param targetName string|nil
---@param silent boolean|nil
function RunSharing:CheckRegistrationWithTarget(targetName, silent)
    local target = targetName
        or CM:GetProfileSettingSafe("developer.mythicplus.runSharing.registerWith", nil)
    if type(target) ~= "string" or target == "" then return end

    local payload = { type = "REG_QUERY", ts = time() }
    local serialized = self:Serialize(payload)
    if not serialized then return end

    self.registrationCheckTarget = target
    self.registrationCheckStatus = "PENDING"
    self.registrationCheckResult = nil
    self._registrationCheckToken = (self._registrationCheckToken or 0) + 1
    local token = self._registrationCheckToken

    self:SendCommMessage(PREFIX, serialized, "WHISPER", target)
    NotifyConfigChanged()

    if not silent then
        print("|cff9580ffTwichUI:|r Checking registration status with " .. target .. "...")
    end

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(5, function()
            if self.registrationCheckStatus == "PENDING" and self._registrationCheckToken == token then
                self.registrationCheckStatus = "FAILED"
                NotifyConfigChanged()
            end
        end)
    end
end

---@param targetName string|nil
function RunSharing:UnregisterToReceive(targetName)
    local target = targetName
        or CM:GetProfileSettingSafe("developer.mythicplus.runSharing.registerWith", nil)
    if type(target) ~= "string" or target == "" then return end

    local payload = { type = "UNREGISTER", ts = time() }
    local serialized = self:Serialize(payload)
    if serialized then
        self:SendCommMessage(PREFIX, serialized, "WHISPER", target)
    end
end

---@param runData table
---@param overrideReceiver string|nil
function RunSharing:SendRun(runData, overrideReceiver)
    local target = overrideReceiver or self.receiver
    if not target then return end

    local serialized = self:Serialize(runData)
    if not serialized then
        Logger.Error("Run Sharing: Failed to serialize run data")
        return
    end

    Logger.Info("Sending run data to " .. target)
    self:SendCommMessage(PREFIX, serialized, "WHISPER", target)
end

function RunSharing:SendPing(silent)
    if not self.receiver then return end

    local payload = { type = "PING", silent = silent }
    local serialized = self:Serialize(payload)
    if serialized then
        self.connectionStatus = "PENDING"
        self:SendCommMessage(PREFIX, serialized, "WHISPER", self.receiver)

        if not silent then
            print("|cff9580ffTwichUI:|r Sending connection test to " .. self.receiver .. "...")
        end

        local ACR = (T.Libs and T.Libs.AceConfigRegistry) or LibStub("AceConfigRegistry-3.0-ElvUI", true) or
            LibStub("AceConfigRegistry-3.0", true)
        if ACR then ACR:NotifyChange("ElvUI") end

        -- Timeout check (5 seconds)
        _G.C_Timer.After(5, function()
            if self.connectionStatus == "PENDING" then
                self.connectionStatus = "FAILED"
                local ACR = (T.Libs and T.Libs.AceConfigRegistry) or LibStub("AceConfigRegistry-3.0-ElvUI", true) or
                    LibStub("AceConfigRegistry-3.0", true)
                if ACR then ACR:NotifyChange("ElvUI") end
            end
        end)
    end
end

function RunSharing:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= PREFIX then return end

    local success, data = self:Deserialize(message)
    if not success then
        Logger.Error("Run Sharing: Failed to deserialize data from " .. sender)
        return
    end

    if type(data) == "table" then
        if data.type == "PING" then
            -- Reply with PONG
            local pong = { type = "PONG", silent = data.silent, purpose = data.purpose }
            local serialized = self:Serialize(pong)
            if serialized then
                self:SendCommMessage(PREFIX, serialized, "WHISPER", sender)
            end
            return
        elseif data.type == "PONG" then
            if data.purpose == "REGISTER" and self.registerWithTarget and sender == self.registerWithTarget then
                self.registerWithStatus = "SUCCESS"
                NotifyConfigChanged()
                if not data.silent then
                    print("|cff9580ffTwichUI:|r Registration target responded: " .. sender)
                end
            else
                self.connectionStatus = "SUCCESS"
                if not data.silent then
                    print("|cff9580ffTwichUI:|r Connection confirmed! Received response from " .. sender)
                end
                local ACR = (T.Libs and T.Libs.AceConfigRegistry) or LibStub("AceConfigRegistry-3.0-ElvUI", true) or
                    LibStub("AceConfigRegistry-3.0", true)
                if ACR then ACR:NotifyChange("ElvUI") end

                if self.OnConnectionEstablished then
                    self.OnConnectionEstablished:Invoke(sender)
                end
            end
            return
        elseif data.type == "ACK" then
            if self.OnRunAcknowledged then
                self.OnRunAcknowledged:Invoke(data.runId, sender)
            end
            return
        elseif data.type == "REG_QUERY" then
            if CM:GetProfileSettingSafe("developer.mythicplus.runSharing.ignoreRegistrations", false) then
                return
            end

            local isRegistered = false
            if type(self.registeredReceivers) == "table" then
                isRegistered = not not self.registeredReceivers[sender]
            end

            local resp = { type = "REG_STATUS", registered = isRegistered }
            local serialized = self:Serialize(resp)
            if serialized then
                self:SendCommMessage(PREFIX, serialized, "WHISPER", sender)
            end
            return
        elseif data.type == "REG_STATUS" then
            -- Response to our CheckRegistrationWithTarget().
            if self.registrationCheckTarget and sender ~= self.registrationCheckTarget then
                return
            end

            self.registrationCheckResult = not not data.registered
            self.registrationCheckStatus = (self.registrationCheckResult and "SUCCESS") or "FAILED"
            NotifyConfigChanged()
            return
        elseif data.type == "REGISTER" then
            if CM:GetProfileSettingSafe("developer.mythicplus.runSharing.ignoreRegistrations", false) then
                return
            end

            if type(self.registeredReceivers) ~= "table" then
                self.registeredReceivers = {}
            end

            -- Receiver registers directly with you (typically via WHISPER).
            self.registeredReceivers[sender] = time()
            Logger.Info("Run Sharing: " .. sender .. " registered to receive run logs")

            NotifyConfigChanged()

            if self.OnReceiverRegistered then
                self.OnReceiverRegistered:Invoke(sender)
            end
            return
        elseif data.type == "UNREGISTER" then
            if CM:GetProfileSettingSafe("developer.mythicplus.runSharing.ignoreRegistrations", false) then
                return
            end

            if type(self.registeredReceivers) == "table" then
                self.registeredReceivers[sender] = nil
            end

            NotifyConfigChanged()
            return
        end
    end

    self:ProcessReceivedRun(sender, data)
end

function RunSharing:ProcessReceivedRun(sender, runData)
    -- Basic validation
    if type(runData) ~= "table" or not runData.id then return end

    -- Send ACK
    local ack = { type = "ACK", runId = runData.id }
    local serialized = self:Serialize(ack)
    if serialized then
        self:SendCommMessage(PREFIX, serialized, "WHISPER", sender)
    end

    -- Check if we should ignore incoming runs
    if CM:GetProfileSettingSafe("developer.mythicplus.runSharing.ignoreIncoming", false) then
        Logger.Info("Run Sharing: Ignored incoming run data from " .. sender .. " (setting enabled)")
        return
    end

    local db = GetDB()

    table.insert(db.remoteRuns, {
        sender = sender,
        receivedAt = time(),
        data = runData -- Storing as Lua table
    })

    Logger.Info("Received Mythic+ run data from " .. sender)

    -- Play notification sound
    local sound = CM:GetProfileSettingSafe("developer.mythicplus.runSharing.sound", "None")
    if sound and sound ~= "None" then
        local LSM = T.Libs and T.Libs.LSM
        if LSM then
            local soundFile = LSM:Fetch("sound", sound)
            if soundFile then
                _G.PlaySoundFile(soundFile, "Master")
            end
        end
    end

    -- Notify UI if available
    if MythicPlusModule.RunSharingFrame and MythicPlusModule.RunSharingFrame.UpdateList then
        MythicPlusModule.RunSharingFrame:UpdateList()
    end
end
