local T, W, I, C = unpack(Twich)

--- @class ConfigurationModule
local CM         = T:GetModule("Configuration")
--- @type ToolsModule
local TM         = T:GetModule("Tools")

--- @type GoldGoblinConfigurationModule
local GG         = CM.GoldGoblin or {}

--- @class GoldBalancerConfigurationModule
local GBC        = GG.GoldBalancer or {}
GG.GoldBalancer  = GBC

--- @type GoldGoblinModule
local GGM        = T:GetModule("GoldGoblin")

function GBC:Create()
    return {
        functionGroup = {
            type = "group",
            name = "Functions",
            order = 1,
            inline = true,
            args = {
                desctription = CM.Widgets:ComponentDescription(0,
                    "These settings automate the withdrawal and/or deposit of gold to and from your warbank to help maintain a balanced amount of gold. The 'Target Balance' setting defines the desired amount of gold to keep on your character."
                ),
                autoDepositToggle = {
                    type = "toggle",
                    name = "Auto Deposit",
                    desc = CM:ColorTextKeywords(
                        "Automatically deposit gold into the warbank when opening the bank frame."),
                    order = 1,
                    width = "full",
                    get = function()
                        return CM:GetProfileSettingByConfigEntry(GGM.GoldBalancer.CONFIGURATION.AUTO_DEPOSIT)
                    end,
                    set = function(_, value)
                        CM:SetProfileSettingByConfigEntry(GGM.GoldBalancer.CONFIGURATION.AUTO_DEPOSIT, value)
                    end
                },
                autoWithdrawToggle = {
                    type = "toggle",
                    name = "Auto Withdraw",
                    desc = CM:ColorTextKeywords(
                        "Automatically withdraw gold from the warbank when opening the bank frame."),
                    order = 2,
                    width = "full",
                    get = function()
                        return CM:GetProfileSettingByConfigEntry(GGM.GoldBalancer.CONFIGURATION.AUTO_WITHDRAW)
                    end,
                    set = function(_, value)
                        CM:SetProfileSettingByConfigEntry(GGM.GoldBalancer.CONFIGURATION.AUTO_WITHDRAW, value)
                    end
                },
                targetBalanceInput = {
                    type = "input",
                    name = "Target Balance (Gold)",
                    desc = CM:ColorTextKeywords(
                        "Set the target amount of gold to maintain in the warbank. The Gold Balancer will attempt to keep this amount balanced."),
                    order = 3,
                    width = "full",
                    get = function()
                        local copper = CM:GetProfileSettingByConfigEntry(GGM.GoldBalancer.CONFIGURATION
                            .TARGET_AMOUNT_COPPER)
                        return tostring(copper / 100 / 100)
                    end,
                    set = function(_, value)
                        local gold = tonumber(value)
                        if gold and gold >= 0 then
                            local copper = math.floor(gold * 100 * 100)
                            CM:SetProfileSettingByConfigEntry(GGM.GoldBalancer.CONFIGURATION.TARGET_AMOUNT_COPPER, copper)
                        end
                    end,
                    validate = function(_, value)
                        local gold = tonumber(value)
                        if not gold or gold < 0 then
                            return "Please enter a valid non-negative number for gold."
                        end
                        return true
                    end
                }
            }
        }
    }
end
