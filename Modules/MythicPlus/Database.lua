local T = unpack(Twich)

--- @type MythicPlusModule
local MythicPlusModule = T:GetModule("MythicPlus")

--- @type ConfigurationModule
local CM = T:GetModule("Configuration")

--- @type LoggerModule
local Logger = T:GetModule("Logger")

--- @class MythicPlusDatabaseSubmodule
local Database = MythicPlusModule.Database or {}
MythicPlusModule.Database = Database

--[[
    MythicPlus Database Structure
]]
---@class MythicPlusDatabase_CharacterEntry_Metadata
---@field characterName string
---@field realmName string
---@field class string
---@field faction string

---@class MythicPlusDatabase_CharacterEntry_Keystone

---@class MythicPlusDatabase_CharacterEntry
---@field Metadata MythicPlusDatabase_CharacterEntry_Metadata
---@field KeystoneData MythicPlusDatabase_CharacterEntry_Keystone


---@class MythicPlusDatabase
---@field Characters table<string, MythicPlusDatabase_CharacterEntry> key is UnitGUID
local TwichUIDungeonDB = _G.TwichUIDungeonDB or {} -- saved variable


--- local cached vars
local UnitGUID = UnitGUID
local UnitName = UnitName
local GetRealmName = GetRealmName
local UnitClass = UnitClass
local UnitFactionGroup = UnitFactionGroup

---@param guid string the UnitGUID for the current character
local function InitCurrentCharacter(guid)
    -- checking if already initialized
    if TwichUIDungeonDB[guid] then
        return
    end

    Logger.Debug("Initializing Mythic+ database for character GUID: " .. guid)

    TwichUIDungeonDB[guid] = {
        Metadata = {
            characterName = UnitName("player") or "Unknown",
            realmName = GetRealmName() or "Unknown",
            class = select(2, UnitClass("player")) or "Unknown",
            faction = UnitFactionGroup("player") or "Unknown",
        },
        KeystoneData = {
            -- to be filled later
        },
    }
end

function Database:GetForCurrentCharacter()
    local playerGUID = UnitGUID("player")

    if not TwichUIDungeonDB[playerGUID] then
        InitCurrentCharacter(playerGUID)
    end
end
