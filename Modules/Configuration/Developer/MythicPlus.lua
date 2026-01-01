---@diagnostic disable-next-line: undefined-global
local T, W, I, C = unpack(Twich)

--- @class ConfigurationModule
local CM = T:GetModule("Configuration")
--- @type MythicPlusModule
local MythicPlusModule = T:GetModule("MythicPlus")
--- @type ToolsModule
local TM = T:GetModule("Tools")

local LSM = T.Libs and T.Libs.LSM

--- @type DeveloperConfigurationModule
CM.Developer = CM.Developer or {}

--- @class DeveloperMythicPlusConfiguration
local DMP = CM.Developer.MythicPlus or {}
CM.Developer.MythicPlus = DMP

--- Create the Mythic+ developer configuration panels
--- @param order number The order of the panel
function DMP:Create(order)
    return {
        type = "group",
        name = "Mythic+",
        order = order,
        args = {
            description = CM.Widgets:SubmoduleDescription(
                "Developer tools and settings for the Mythic+ module."),
            
            runSharingGroup = {
                type = "group",
                name = "Run Sharing",
                inline = true,
                order = 1,
                args = {
                    description = CM.Widgets:ComponentDescription(0,
                        "Configure settings for sharing and receiving Mythic+ run data (Development Feature)."),

                    notificationGroup = {
                        type = "group",
                        name = "Notifications",
                        inline = true,
                        order = 1,
                        args = {
                            sound = {
                                type = "select",
                                dialogControl = "LSM30_Sound",
                                name = "Notification Sound",
                                desc = "Play a sound when new run data is received.",
                                order = 1,
                                values = LSM and LSM:HashTable("sound") or {},
                                get = function()
                                    return CM:GetProfileSettingSafe("developer.mythicplus.runSharing.sound", "None")
                                end,
                                set = function(_, value)
                                    CM:SetProfileSettingSafe("developer.mythicplus.runSharing.sound", value)
                                end,
                            },
                            ignoreIncoming = {
                                type = "toggle",
                                name = "Ignore Incoming Runs",
                                desc = "If enabled, incoming run data from other players will be ignored.",
                                order = 2,
                                get = function()
                                    return CM:GetProfileSettingSafe("developer.mythicplus.runSharing.ignoreIncoming", false)
                                end,
                                set = function(_, value)
                                    CM:SetProfileSettingSafe("developer.mythicplus.runSharing.ignoreIncoming", value)
                                end,
                            },
                        }
                    }
                }
            },
        }
    }
end
