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
        }
    }
end
