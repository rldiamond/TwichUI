local T, W, I, C          = unpack(Twich)

---@type GoldGoblinModule
local GG                  = T:GetModule("GoldGoblin")
---@type ConfigurationModule
local CM                  = T:GetModule("Configuration")
---@type LoggerModule
local LM                  = T:GetModule("Logger")
---@type ToolsModule
local TM                  = T:GetModule("Tools")

---@class GoldBalancerModule
---@field enabled boolean
---@field eventFrame Frame the frame used to register events
local GB                  = GG.GoldBalancer or {}
GG.GoldBalancer           = GB

---@type table<string, ConfigEntry>
GB.CONFIGURATION          = {
    ENABLE = { key = "goldGoblin.goldBalancer.enable", default = false },
    AUTO_DEPOSIT = { key = "goldGoblin.goldBalancer.autoDeposit", default = false },
    AUTO_WITHDRAW = { key = "goldGoblin.goldBalancer.autoWithdraw", default = false },
    TARGET_AMOUNT_COPPER = { key = "goldGoblin.goldBalancer.targetAmountCopper", default = 100 * 100 * 100 }, -- 100 gold
}

local EVENTS              = { "BANKFRAME_OPENED" }
local CanDepositMoney     = C_Bank.CanDepositMoney
local DepositMoney        = C_Bank.DepositMoney
local CanWithdrawMoney    = C_Bank.CanWithdrawMoney
local WithdrawMoney       = C_Bank.WithdrawMoney
local GetMoney            = GetMoney
local FetchDepositedMoney = C_Bank.FetchDepositedMoney
local WARBANK_BANK_TYPE   = Enum.BankType.Account

---@param frame Frame the frame to clear events from
local function ClearFrame(frame)
    if not frame then return end
    frame:UnregisterAllEvents()
    frame:SetScript("OnEvent", nil)
end

---@return number amount of copper in warbank
local function GetWarbankCopper()
    return FetchDepositedMoney(WARBANK_BANK_TYPE)
end

---@param copper number amount of copper to deposit
---@return boolean success whether the deposit was successful
---@return string|nil errMsg error message if any
local function Deposit(copper)
    if type(copper) ~= "number" or copper <= 0 then
        return false, "Invalid amount to deposit"
    end

    if not CanDepositMoney(WARBANK_BANK_TYPE) then
        return false, "Cannot deposit to warbank right now"
    end

    local currentMoney = GetMoney()

    if currentMoney < copper then
        return false, "Not enough gold to deposit"
    end

    DepositMoney(WARBANK_BANK_TYPE, copper)
    return true, nil
end

local function Withdraw(copper)
    if type(copper) ~= "number" or copper <= 0 then
        return false, "Invalid amount to withdraw"
    end

    if not CanWithdrawMoney(WARBANK_BANK_TYPE) then
        return false, "Cannot withdraw from warbank right now"
    end

    local currentWarbankMoney = GetWarbankCopper()
    if currentWarbankMoney < copper then
        WithdrawMoney(WARBANK_BANK_TYPE, currentWarbankMoney)
        return false, "Not enough gold in warbank to meet withdrawal, withdrawing all available gold"
    end

    WithdrawMoney(WARBANK_BANK_TYPE, copper)
    return true, nil
end

local function Balance()
    local autoDeposit = CM:GetProfileSettingByConfigEntry(GB.CONFIGURATION.AUTO_DEPOSIT)
    local autoWithdraw = CM:GetProfileSettingByConfigEntry(GB.CONFIGURATION.AUTO_WITHDRAW)
    local targetAmount = CM:GetProfileSettingByConfigEntry(GB.CONFIGURATION.TARGET_AMOUNT_COPPER)
    local playerCopper = GetMoney()

    if not autoDeposit and not autoWithdraw then
        LM.Debug("Gold balancer: both auto deposit and withdraw are disabled; no action taken")
        return
    end

    if autoDeposit then
        if playerCopper > targetAmount then
            local depositAmount = playerCopper - targetAmount
            local success, errMsg = Deposit(depositAmount)
            if success then
                LM.Info("Gold balancer deposited " .. TM.Text.FormatCopper(depositAmount) .. " to warbank")
            else
                LM.Warn("Gold balancer failed to deposit gold: " .. errMsg)
            end
        end
    end
    if autoWithdraw then
        if playerCopper < targetAmount then
            local withdrawAmount = targetAmount - playerCopper
            local success, errMsg = Withdraw(withdrawAmount)
            if success then
                LM.Info("Gold balancer withdrew " .. TM.Text.FormatCopper(withdrawAmount) .. " from warbank")
            else
                LM.Warn("Gold balancer failed to withdraw gold: " .. errMsg)
            end
        end
    end
end

local function EventHandler(_, event, ...)
    if event == "BANKFRAME_OPENED" then
        Balance()
    end
end

function GB:IsEnabled()
    return self.enabled
end

function GB:Enable()
    if self.enabled then return end

    -- clear the frame if for some reason it still exists
    if self.frame then
        ClearFrame(self.frame)
        self.frame = nil
    end
    self.enabled = true

    for _, event in ipairs(EVENTS) do
        if not self.frame then
            self.frame = _G.CreateFrame("Frame")
        end
        self.frame:RegisterEvent(event)
    end
    self.frame:SetScript("OnEvent", EventHandler)

    LM.Debug("Gold balancer enabled")
end

function GB:Disable()
    if not self.enabled then return end

    -- clear the frame if for some reason it still exists
    if self.frame then
        ClearFrame(self.frame)
        self.frame = nil
    end
    self.enabled = false

    LM.Debug("Gold balancer disabled")
end

function GB:OnInitialize()
    if self:IsEnabled() then return end

    if CM:GetProfileSettingByConfigEntry(self.CONFIGURATION.ENABLE) then
        self:Enable()
    end
end
