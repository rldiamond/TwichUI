local E, L, V, P, G = unpack(ElvUI)

local twichui = TwichUI
local twichui_utility = TwichUI_Utility
local Logger = TwichUI.Logger
--- @class DataTextAPI
local DataTextAPI = TwichUI.DataTextAPI
--- @class CacheAPI
local CacheAPI = TwichUI.CacheAPI

local utilityMountsSpellIDList = {
    122708,
    457485,
    264058,
    465235,
    61447
}

local cacheUtilityMounts = CacheAPI.New("UtilityMountsCache")
local cacheMounts = CacheAPI.New("MountsCache")

local menuList = {}

local mountsCache = nil
local mountsDirty = true

-- returns true if the mountID is a utility mount, false if not.
local function IsMountUtility(displayIndex)
    local cache = cacheUtilityMounts:get(function()
        local internalCache = {}

        -- get the mountID for each mount by its spellID
        for _, spellID in ipairs(utilityMountsSpellIDList) do
            local mountID = C_MountJournal.GetMountFromSpell(spellID)
            tinsert(internalCache, mountID)
        end

        -- refactor the table so its key is the ID and the value is true
        local utilityMountCache = {}
        for _, mountID in ipairs(internalCache) do
            utilityMountCache[mountID] = true
        end
        return utilityMountCache
    end)

    local mountID = C_MountJournal.GetDisplayedMountID(displayIndex)
    return cache[mountID]
end

local function GetMounts()
    local cache = cacheMounts:get(function()
        local utilityMounts  = {}
        local favoriteMounts = {}

        local numMounts      = C_MountJournal.GetNumMounts()
        for displayIndex = 1, numMounts do
            local isMountUtility  = IsMountUtility(displayIndex)
            local isMountFavorite = false

            if not isMountUtility then
                isMountFavorite = C_MountJournal.GetIsFavorite(displayIndex)
            end

            if (isMountUtility or isMountFavorite) then
                local creatureName, spellID, icon, _, _, _, _, _, _, _, isCollected, mountID =
                    C_MountJournal.GetDisplayedMountInfo(displayIndex)

                if isCollected then
                    local targetList = isMountUtility and utilityMounts or favoriteMounts

                    tinsert(targetList, {
                        name    = creatureName,
                        spellID = spellID,
                        icon    = icon,
                        mountID = mountID,
                    })
                end
            end
        end

        return {
            utility  = utilityMounts,
            favorite = favoriteMounts,
        }
    end)
    return cache
end

local function BuildMenu()
    twichui_utility:Log("Building mount menu")
    wipe(menuList)

    local mounts = GetMounts()
    if not mounts then
        return
    end

    table.insert(menuList, {
        text         = "Favorite Mounts",
        isTitle      = true,
        notClickable = true,
        color        = E:RGBToHex(1, 0.82, 0),
    })

    for _, mount in ipairs(mounts.favorite) do
        local _, _, _, _, isUsable = C_MountJournal.GetMountInfoByID(mount.mountID)
        local textTemplate = "%s"
        if not isUsable then
            textTemplate = "|cff808080%s|r"
        end
        table.insert(menuList, {
            text         = string.format(textTemplate, mount.name),
            icon         = mount.icon,
            notClickable = not isUsable,
            func         = function() C_MountJournal.SummonByID(mount.mountID) end,
            funcOnEnter  = function(btn)
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                GameTooltip:SetMountBySpellID(mount.spellID)
                GameTooltip:Show()
            end,
            funcOnLeave  = function()
                GameTooltip:Hide()
            end,
        })
    end

    table.insert(menuList, {
        text         = "Utility Mounts",
        isTitle      = true,
        notClickable = true,
        color        = E:RGBToHex(1, 0.82, 0),
    })

    for _, mount in ipairs(mounts.utility) do
        local _, _, _, _, isUsable = C_MountJournal.GetMountInfoByID(mount.mountID)
        local textTemplate = "%s"
        if not isUsable then
            textTemplate = "|cff808080%s|r"
        end
        table.insert(menuList, {
            text         = string.format(textTemplate, mount.name),
            icon         = mount.icon,
            notClickable = not isUsable,
            func         = function() C_MountJournal.SummonByID(mount.mountID) end,
            funcOnEnter  = function(btn)
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                GameTooltip:SetMountBySpellID(mount.spellID)
                GameTooltip:Show()
            end,
            funcOnLeave  = function()
                GameTooltip:Hide()
            end,
        })
    end

    table.insert(menuList, {
        text         = "Other",
        isTitle      = true,
        notClickable = true,
        color        = E:RGBToHex(1, 0.82, 0),
    })

    -- change flight style
    table.insert(menuList, {
        text = "Switch Flight Style",
        icon = "Interface\\Icons\\Ability_DragonRiding_DynamicFlight01",
        notClickable = false,
        macro = "/use Switch Flight Style",
        funcOnEnter = function(btn)
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(460002)
            GameTooltip:Show()
        end,
        funcOnLeave = function()
            GameTooltip:Hide()
        end,
    })
end

local displayCache = CacheAPI.New("MountDisplayCache")

--- Generates the display text based on user configuration.
local function GetDisplay()
    local display = displayCache:get(function()
        local db = DataTextAPI:GetDatabase().mounts

        return DataTextAPI:ColorTextByElvUISetting(db, "Mounts")
    end)

    return display
end

local function OnEvent(panel, event, ...)
    Logger:Debug("Mounts datatext received event: " .. tostring(event))

    if event == "ELVUI_FORCE_UPDATE" then
        displayCache:invalidate()
    end

    if event == "COMPANION_UPDATE" or event == "MOUNT_JOURNAL_USABILITY_CHANGED" or event == "MOUNT_JOURNAL_SEARCH_UPDATED" then
        cacheMounts:invalidate()
    end

    panel.text:SetText(GetDisplay())
end

local function OnEnter(self)
    BuildMenu()
    twichui:DropDown(menuList, twichui.menu, self, 0, 2, "twichui_mounts")
end

-----------------------------------------------------------------------
-- Module registration
-----------------------------------------------------------------------

DataTextAPI:NewDataText(
    "TwichMounts",
    "Twich: Mounts",
    { "PLAYER_ENTERING_WORLD", "COMPANION_UPDATE", "MOUNT_JOURNAL_USABILITY_CHANGED", "MOUNT_JOURNAL_SEARCH_UPDATED" },
    OnEvent,
    nil, -- onUpdate
    nil, -- onClick
    OnEnter,
    nil  -- onLeave
)
