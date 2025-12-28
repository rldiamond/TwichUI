local T, W, I, C = unpack(Twich)
local E          = unpack(ElvUI)

--- @class ConfigurationModule
local CM         = T:GetModule("Configuration")
--- @type ToolsModule
local TM         = T:GetModule("Tools")

--- @type GoldGoblinConfigurationModule
local GG         = CM.GoldGoblin or {}

--- @class GoldTrackerConfigurationModule
local GTC        = GG.GoldTracker or {}
GG.GoldTracker   = GTC

local function SanitizeKey(value)
    return tostring(value or ""):gsub("[^%w]", "_")
end

local function CharacterExists(realmName, characterName)
    return type(_G.TwichUIGoldDB) == "table"
        and type(_G.TwichUIGoldDB[realmName]) == "table"
        and type(_G.TwichUIGoldDB[realmName][characterName]) == "table"
end

local function GetCharacterEntries()
    local entries = {}
    if type(_G.TwichUIGoldDB) ~= "table" then
        return entries
    end

    for realmName, chars in pairs(_G.TwichUIGoldDB) do
        if type(chars) == "table" then
            for characterName, data in pairs(chars) do
                if type(data) == "table" then
                    table.insert(entries, {
                        realm = realmName,
                        name = characterName,
                        class = data.class,
                        faction = data.faction,
                        copper = tonumber(data.totalCopper) or 0,
                    })
                end
            end
        end
    end

    table.sort(entries, function(a, b)
        if a.realm == b.realm then
            return tostring(a.name) < tostring(b.name)
        end
        return tostring(a.realm) < tostring(b.realm)
    end)

    return entries
end

local function NotifyOptionsRefresh()
    local ACR = (T.Libs and T.Libs.AceConfigRegistry)
        or _G.LibStub("AceConfigRegistry-3.0-ElvUI", true)
        or _G.LibStub("AceConfigRegistry-3.0", true)
    if ACR and ACR.NotifyChange then
        pcall(ACR.NotifyChange, ACR, "ElvUI")
    end

    if E and type(E.RefreshOptions) == "function" then
        pcall(E.RefreshOptions, E)
    end
end

function GTC:RebuildCharacterDataOptions()
    if not (E and E.Options and E.Options.args and E.Options.args.TwichUI) then
        return
    end

    local twichUI = E.Options.args.TwichUI
    local goldGoblin = twichUI.args and twichUI.args.goldGoblin
    local goldTrackerSubmodule = goldGoblin and goldGoblin.args and goldGoblin.args.goldTrackerSubmodule

    if goldTrackerSubmodule and goldTrackerSubmodule.args then
        goldTrackerSubmodule.args.characterData = self:CreateCharacterDataGroup()
        NotifyOptionsRefresh()
    end
end

function GTC:ResetCharacterData(realmName, characterName)
    if not CharacterExists(realmName, characterName) then
        return
    end

    local UnitName = UnitName
    local GetRealmName = GetRealmName
    local GetMoney = GetMoney
    local UnitClass = UnitClass
    local UnitFactionGroup = UnitFactionGroup

    local isCurrentCharacter = (GetRealmName() == realmName) and (UnitName("player") == characterName)

    local data = _G.TwichUIGoldDB[realmName][characterName]

    if isCurrentCharacter then
        data.totalCopper = GetMoney() or 0
        data.class = select(2, UnitClass("player")) or data.class
        data.faction = UnitFactionGroup("player") or data.faction
    else
        data.totalCopper = 0
    end

    if TM and TM.Money and type(TM.Money.NotifyGoldUpdated) == "function" then
        TM.Money:NotifyGoldUpdated()
    end

    self:RebuildCharacterDataOptions()
end

function GTC:DeleteCharacterData(realmName, characterName)
    if not CharacterExists(realmName, characterName) then
        return
    end

    local UnitName = UnitName
    local GetRealmName = GetRealmName
    if (GetRealmName() == realmName) and (UnitName("player") == characterName) then
        return
    end

    _G.TwichUIGoldDB[realmName][characterName] = nil
    if type(_G.TwichUIGoldDB[realmName]) == "table" and next(_G.TwichUIGoldDB[realmName]) == nil then
        _G.TwichUIGoldDB[realmName] = nil
    end

    if TM and TM.Money and type(TM.Money.NotifyGoldUpdated) == "function" then
        TM.Money:NotifyGoldUpdated()
    end

    self:RebuildCharacterDataOptions()
end

function GTC:CreateCharacterDataGroup()
    local entries = GetCharacterEntries()

    local args = {
        description = CM.Widgets:ComponentDescription(1,
            "This list shows the Gold Tracker's cached, account-wide character gold data. " ..
            "Deleting or resetting entries affects all profiles."
        ),
    }

    if #entries == 0 then
        args.empty = {
            type = "description",
            name = TM.Text.Color(TM.Colors.TWICH.TEXT_SECONDARY, "No cached character gold data found."),
            order = 2,
            fontSize = "medium",
        }
        return {
            type = "group",
            name = "Character Data",
            order = 20,
            args = args,
        }
    end

    local function GetLocalizedClassName(classFile)
        if not classFile then return nil end
        local male = _G.LOCALIZED_CLASS_NAMES_MALE
        if type(male) == "table" and male[classFile] then
            return male[classFile]
        end
        local female = _G.LOCALIZED_CLASS_NAMES_FEMALE
        if type(female) == "table" and female[classFile] then
            return female[classFile]
        end
        return classFile
    end

    local function ColorFaction(faction)
        if not faction then return nil end
        if TM and TM.Text and type(TM.Text.ColorByFaction) == "function" then
            return TM.Text.ColorByFaction(faction, faction) or faction
        end
        return faction
    end

    local function ClassIcon(classFile, size)
        if not (TM and TM.Textures and type(TM.Textures.GetClassTextureString) == "function") then
            return ""
        end
        return TM.Textures:GetClassTextureString(classFile, size) or ""
    end

    local function ColorClass(classFile, text)
        if not (TM and TM.Text and type(TM.Text.ColorByClass) == "function") then
            return text
        end
        return TM.Text.ColorByClass(classFile, text)
    end

    local function FormatGold(copper)
        if TM and TM.Text and type(TM.Text.FormatCopper) == "function" then
            return TM.Text.FormatCopper(copper or 0)
        end
        return tostring(copper or 0)
    end

    local order = 10
    for _, entry in ipairs(entries) do
        local realmName, characterName = entry.realm, entry.name
        local key = "char_" .. SanitizeKey(realmName) .. "_" .. SanitizeKey(characterName)

        local isCurrentCharacter = (GetRealmName() == realmName) and (UnitName("player") == characterName)

        local classFile = entry.class
        local className = GetLocalizedClassName(classFile) or "Unknown"
        local factionName = entry.faction or "Unknown"
        local nameRealm = string.format("%s-%s", tostring(characterName), tostring(realmName))

        local icon = ClassIcon(classFile, 18)
        local nameColored = classFile and ColorClass(classFile, nameRealm) or nameRealm
        local classColored = classFile and ColorClass(classFile, className) or className
        local factionColored = ColorFaction(factionName) or factionName
        local goldColored = FormatGold(entry.copper)

        args["row_" .. key] = {
            type = "description",
            order = order,
            fontSize = "medium",
            width = 1.7,
            hidden = function()
                return not CharacterExists(realmName, characterName)
            end,
            name = string.format(
                "%s %s  %s  %s  %s",
                tostring(icon),
                tostring(nameColored),
                TM.Text.Color(TM.Colors.TWICH.TEXT_SECONDARY, "•"),
                tostring(classColored .. " / " .. factionColored),
                tostring(goldColored)
            ),
        }

        args["reset_" .. key] = {
            type = "execute",
            name = "Reset",
            order = order + 0.01,
            width = 0.5,
            confirm = true,
            confirmText = string.format("Reset cached gold for %s - %s to 0?", tostring(characterName),
                tostring(realmName)),
            func = function()
                GTC:ResetCharacterData(realmName, characterName)
            end,
        }

        args["delete_" .. key] = {
            type = "execute",
            name = "Delete",
            order = order + 0.02,
            width = 0.5,
            confirm = true,
            confirmText = string.format("Delete cached gold for %s - %s?", tostring(characterName), tostring(realmName)),
            disabled = isCurrentCharacter,
            func = function()
                GTC:DeleteCharacterData(realmName, characterName)
            end,
        }

        args["spacer_" .. key] = {
            type = "description",
            name = " ",
            order = order + 0.03,
            width = "full",
        }

        order = order + 1
    end

    return {
        type = "group",
        name = "Character Data",
        order = 20,
        args = args,
    }
end

function GTC:Create()
    return {
        characterData = self:CreateCharacterDataGroup(),
    }
end
