---@diagnostic disable-next-line: undefined-global
local T, W, I, C = unpack(Twich)

local LSM = T.Libs and T.Libs.LSM

--- @type ConfigurationModule
local CM = T:GetModule("Configuration")
--- @type ToolsModule
local TM = T:GetModule("Tools")

local TT = (TM and TM.Text) or { Color = function(_, text) return text end }
local CT = (TM and TM.Colors) or { TWICH = { SECONDARY_ACCENT = { r = 1, g = 1, b = 1 } } }


--- @class MythicPlusConfigurationModule
local MP = CM.MythicPlus or {}
CM.MythicPlus = MP

function MP:Create(order)
    ---@return MythicPlusModule module
    local function GetModule()
        return T:GetModule("MythicPlus")
    end

    return CM.Widgets:ModuleGroup(order, "Mythic+", "This module provides numerous tools for Mythic+ players.",
        {
            moduleEnableToggle = {
                type = "toggle",
                name = TT.Color(CT.TWICH.SECONDARY_ACCENT, "Enable"),
                desc = CM:ColorTextKeywords("Enable the Mythic+ module."),
                descStyle = "inline",
                order = 2,
                width = "full",
                get = function()
                    return CM:GetProfileSettingByConfigEntry(GetModule().CONFIGURATION.ENABLED)
                end,
                set = function(_, value)
                    CM:SetProfileSettingByConfigEntry(GetModule().CONFIGURATION.ENABLED, value)
                    local module = GetModule()
                    if value then
                        module:Enable()
                    else
                        module:Disable()
                    end
                end
            },
            enabledSpacer = CM.Widgets:Spacer(3),
            enabledSubmodulesText = {
                type = "description",
                order = 4,
                name = CM:ColorTextKeywords(
                    "Now that the module is enabled, you can find available submodules to the left, under the module's section.\n\n"
                ),
                hidden = function()
                    return not CM:GetProfileSettingByConfigEntry(GetModule().CONFIGURATION.ENABLED)
                end,
            },

            mainWindowGroup = {
                type = "group",
                name = "Main Window",
                inline = true,
                order = 10,
                hidden = function()
                    return not CM:GetProfileSettingByConfigEntry(GetModule().CONFIGURATION.ENABLED)
                end,
                args = {
                    description = CM.Widgets:ComponentDescription(0,
                        "This is the main Mythic+ window. Keep it simple now; features will be added as sub-panels later."),
                    showToggle = {
                        type = "toggle",
                        name = "Show Window",
                        desc = CM:ColorTextKeywords("Toggles the Mythic+ main window."),
                        order = 1,
                        width = "full",
                        get = function()
                            local module = GetModule()
                            return module.MainWindow and module.MainWindow.IsEnabled and module.MainWindow:IsEnabled() or
                                CM:GetProfileSettingByConfigEntry(module.CONFIGURATION.MAIN_WINDOW_ENABLED)
                        end,
                        set = function(_, value)
                            local module = GetModule()
                            if not module.MainWindow then return end
                            if value then
                                module.MainWindow:Enable(true)
                            else
                                module.MainWindow:Disable(true)
                            end
                        end,
                    },
                    lockedToggle = {
                        type = "toggle",
                        name = "Lock Window",
                        desc = CM:ColorTextKeywords("When locked, the window cannot be dragged."),
                        order = 2,
                        width = 1,
                        get = function()
                            local module = GetModule()
                            return CM:GetProfileSettingByConfigEntry(module.CONFIGURATION.MAIN_WINDOW_LOCKED)
                        end,
                        set = function(_, value)
                            local module = GetModule()
                            CM:SetProfileSettingByConfigEntry(module.CONFIGURATION.MAIN_WINDOW_LOCKED, value)
                            if module.MainWindow and module.MainWindow.RefreshLayout then
                                module.MainWindow:RefreshLayout()
                            end
                        end,
                    },
                    frameWidth = {
                        type = "range",
                        name = "Width",
                        order = 3,
                        min = 280,
                        max = 900,
                        step = 10,
                        bigStep = 50,
                        get = function()
                            local module = GetModule()
                            return CM:GetProfileSettingByConfigEntry(module.CONFIGURATION.MAIN_WINDOW_WIDTH)
                        end,
                        set = function(_, value)
                            local module = GetModule()
                            CM:SetProfileSettingByConfigEntry(module.CONFIGURATION.MAIN_WINDOW_WIDTH, value)
                            if module.MainWindow and module.MainWindow.RefreshLayout then
                                module.MainWindow:RefreshLayout()
                            end
                        end,
                    },
                    frameHeight = {
                        type = "range",
                        name = "Height",
                        order = 4,
                        min = 200,
                        max = 700,
                        step = 10,
                        bigStep = 50,
                        get = function()
                            local module = GetModule()
                            return CM:GetProfileSettingByConfigEntry(module.CONFIGURATION.MAIN_WINDOW_HEIGHT)
                        end,
                        set = function(_, value)
                            local module = GetModule()
                            CM:SetProfileSettingByConfigEntry(module.CONFIGURATION.MAIN_WINDOW_HEIGHT, value)
                            if module.MainWindow and module.MainWindow.RefreshLayout then
                                module.MainWindow:RefreshLayout()
                            end
                        end,
                    },
                    frameScale = {
                        type = "range",
                        name = "Scale",
                        order = 5,
                        min = 0.5,
                        max = 2.0,
                        step = 0.1,
                        bigStep = 0.25,
                        isPercent = true,
                        get = function()
                            local module = GetModule()
                            return CM:GetProfileSettingByConfigEntry(module.CONFIGURATION.MAIN_WINDOW_SCALE)
                        end,
                        set = function(_, value)
                            local module = GetModule()
                            CM:SetProfileSettingByConfigEntry(module.CONFIGURATION.MAIN_WINDOW_SCALE, value)
                            if module.MainWindow and module.MainWindow.RefreshLayout then
                                module.MainWindow:RefreshLayout()
                            end
                        end,
                    },
                    frameAlpha = {
                        type = "range",
                        name = "Transparency",
                        order = 6,
                        min = 0.1,
                        max = 1.0,
                        step = 0.05,
                        bigStep = 0.1,
                        isPercent = true,
                        get = function()
                            local module = GetModule()
                            return CM:GetProfileSettingByConfigEntry(module.CONFIGURATION.MAIN_WINDOW_ALPHA)
                        end,
                        set = function(_, value)
                            local module = GetModule()
                            CM:SetProfileSettingByConfigEntry(module.CONFIGURATION.MAIN_WINDOW_ALPHA, value)
                            if module.MainWindow and module.MainWindow.RefreshLayout then
                                module.MainWindow:RefreshLayout()
                            end
                        end,
                    },
                    font = {
                        type = "select",
                        name = "Font",
                        order = 7,
                        width = 1.5,
                        dialogControl = "LSM30_Font",
                        values = function()
                            if not LSM then return {} end
                            return LSM:HashTable("font")
                        end,
                        get = function()
                            local module = GetModule()
                            return CM:GetProfileSettingByConfigEntry(module.CONFIGURATION.MAIN_WINDOW_FONT)
                        end,
                        set = function(_, value)
                            local module = GetModule()
                            CM:SetProfileSettingByConfigEntry(module.CONFIGURATION.MAIN_WINDOW_FONT, value)
                            if module.MainWindow and module.MainWindow.RefreshLayout then
                                module.MainWindow:RefreshLayout()
                            end
                        end,
                    },
                    titleFontSize = {
                        type = "range",
                        name = "Title Font Size",
                        order = 8,
                        min = 10,
                        max = 24,
                        step = 1,
                        get = function()
                            local module = GetModule()
                            return CM:GetProfileSettingByConfigEntry(module.CONFIGURATION.MAIN_WINDOW_TITLE_FONT_SIZE)
                        end,
                        set = function(_, value)
                            local module = GetModule()
                            CM:SetProfileSettingByConfigEntry(module.CONFIGURATION.MAIN_WINDOW_TITLE_FONT_SIZE, value)
                            if module.MainWindow and module.MainWindow.RefreshLayout then
                                module.MainWindow:RefreshLayout()
                            end
                        end,
                    },
                    titleColor = {
                        type = "color",
                        name = "Title Color",
                        order = 9,
                        get = function()
                            local module = GetModule()
                            local c = CM:GetProfileSettingByConfigEntry(module.CONFIGURATION
                                    .MAIN_WINDOW_TITLE_TEXT_COLOR) or
                                { r = 1, g = 1, b = 1 }
                            return c.r, c.g, c.b
                        end,
                        set = function(_, r, g, b)
                            local module = GetModule()
                            CM:SetProfileSettingByConfigEntry(module.CONFIGURATION.MAIN_WINDOW_TITLE_TEXT_COLOR,
                                { r = r, g = g, b = b })
                            if module.MainWindow and module.MainWindow.RefreshLayout then
                                module.MainWindow:RefreshLayout()
                            end
                        end,
                    },
                },
            },

            dungeonsGroup = {
                type = "group",
                name = "Dungeons Panel",
                inline = true,
                order = 20,
                hidden = function()
                    return not CM:GetProfileSettingByConfigEntry(GetModule().CONFIGURATION.ENABLED)
                end,
                args = {
                    leftColWidth = {
                        type = "range",
                        name = "Left Column Width",
                        order = 1,
                        min = 180,
                        max = 420,
                        step = 10,
                        bigStep = 20,
                        get = function()
                            local module = GetModule()
                            return CM:GetProfileSettingByConfigEntry(module.CONFIGURATION.DUNGEONS_LEFT_COL_WIDTH)
                        end,
                        set = function(_, value)
                            local module = GetModule()
                            CM:SetProfileSettingByConfigEntry(module.CONFIGURATION.DUNGEONS_LEFT_COL_WIDTH, value)
                            if module.Dungeons and module.Dungeons.Refresh then
                                module.Dungeons:Refresh()
                            end
                        end,
                    },
                    rowTexture = {
                        type = "select",
                        name = "Row Texture",
                        order = 2,
                        width = 1.5,
                        dialogControl = "LSM30_Statusbar",
                        values = function()
                            if not LSM then return {} end
                            return LSM:HashTable("statusbar")
                        end,
                        get = function()
                            local module = GetModule()
                            return CM:GetProfileSettingByConfigEntry(module.CONFIGURATION.DUNGEONS_ROW_TEXTURE)
                        end,
                        set = function(_, value)
                            local module = GetModule()
                            CM:SetProfileSettingByConfigEntry(module.CONFIGURATION.DUNGEONS_ROW_TEXTURE, value)
                            if module.Dungeons and module.Dungeons.Refresh then
                                module.Dungeons:Refresh()
                            end
                        end,
                    },
                    rowColor = {
                        type = "color",
                        name = "Row Color",
                        order = 2.2,
                        get = function()
                            local module = GetModule()
                            local color = CM:GetProfileSettingByConfigEntry(module.CONFIGURATION.DUNGEONS_ROW_COLOR) or
                                { r = 1, g = 1, b = 1 }
                            return color.r, color.g, color.b
                        end,
                        set = function(_, r, g, b)
                            local module = GetModule()
                            CM:SetProfileSettingByConfigEntry(module.CONFIGURATION.DUNGEONS_ROW_COLOR,
                                { r = r, g = g, b = b })
                            if module.Dungeons and module.Dungeons.Refresh then
                                module.Dungeons:Refresh()
                            end
                        end,
                    },
                    rowAlpha = {
                        type = "range",
                        name = "Row Texture Alpha",
                        order = 3,
                        min = 0,
                        max = 1,
                        step = 0.05,
                        isPercent = true,
                        get = function()
                            local module = GetModule()
                            return CM:GetProfileSettingByConfigEntry(module.CONFIGURATION.DUNGEONS_ROW_ALPHA)
                        end,
                        set = function(_, value)
                            local module = GetModule()
                            CM:SetProfileSettingByConfigEntry(module.CONFIGURATION.DUNGEONS_ROW_ALPHA, value)
                            if module.Dungeons and module.Dungeons.Refresh then
                                module.Dungeons:Refresh()
                            end
                        end,
                    },
                    rowHoverColor = {
                        type = "color",
                        name = "Row Hover Color",
                        order = 4.2,
                        get = function()
                            local module = GetModule()
                            local color = CM:GetProfileSettingByConfigEntry(module.CONFIGURATION
                                    .DUNGEONS_ROW_HOVER_COLOR)
                                or { r = 1, g = 1, b = 1 }
                            return color.r, color.g, color.b
                        end,
                        set = function(_, r, g, b)
                            local module = GetModule()
                            CM:SetProfileSettingByConfigEntry(module.CONFIGURATION.DUNGEONS_ROW_HOVER_COLOR,
                                { r = r, g = g, b = b })
                            if module.Dungeons and module.Dungeons.Refresh then
                                module.Dungeons:Refresh()
                            end
                        end,
                    },
                    rowHoverAlpha = {
                        type = "range",
                        name = "Row Hover Alpha",
                        order = 4,
                        min = 0,
                        max = 1,
                        step = 0.05,
                        isPercent = true,
                        get = function()
                            local module = GetModule()
                            return CM:GetProfileSettingByConfigEntry(module.CONFIGURATION.DUNGEONS_ROW_HOVER_ALPHA)
                        end,
                        set = function(_, value)
                            local module = GetModule()
                            CM:SetProfileSettingByConfigEntry(module.CONFIGURATION.DUNGEONS_ROW_HOVER_ALPHA, value)
                            if module.Dungeons and module.Dungeons.Refresh then
                                module.Dungeons:Refresh()
                            end
                        end,
                    },
                    imageZoom = {
                        type = "range",
                        name = "Dungeon Image Zoom",
                        order = 5,
                        min = 0,
                        max = 0.75,
                        step = 0.01,
                        get = function()
                            local module = GetModule()
                            return CM:GetProfileSettingByConfigEntry(module.CONFIGURATION.DUNGEONS_IMAGE_ZOOM)
                        end,
                        set = function(_, value)
                            local module = GetModule()
                            CM:SetProfileSettingByConfigEntry(module.CONFIGURATION.DUNGEONS_IMAGE_ZOOM, value)
                            if module.Dungeons and module.Dungeons.Refresh then
                                module.Dungeons:Refresh()
                            end
                        end,
                    },
                    detailsBgAlpha = {
                        type = "range",
                        name = "Details Background Alpha",
                        order = 6,
                        min = 0,
                        max = 1,
                        step = 0.05,
                        isPercent = true,
                        get = function()
                            local module = GetModule()
                            return CM:GetProfileSettingByConfigEntry(module.CONFIGURATION.DUNGEONS_DETAILS_BG_ALPHA)
                        end,
                        set = function(_, value)
                            local module = GetModule()
                            CM:SetProfileSettingByConfigEntry(module.CONFIGURATION.DUNGEONS_DETAILS_BG_ALPHA, value)
                            if module.Dungeons and module.Dungeons.Refresh then
                                module.Dungeons:Refresh()
                            end
                        end,
                    },
                    debugToggle = {
                        type = "toggle",
                        name = "Debug Logs",
                        desc =
                        "Prints extra debug information for dungeon background images (temporary troubleshooting).",
                        order = 20,
                        width = "full",
                        get = function()
                            local module = GetModule()
                            return CM:GetProfileSettingByConfigEntry(module.CONFIGURATION.DUNGEONS_DEBUG)
                        end,
                        set = function(_, value)
                            local module = GetModule()
                            CM:SetProfileSettingByConfigEntry(module.CONFIGURATION.DUNGEONS_DEBUG, value)
                            if module.Dungeons and module.Dungeons.Refresh then
                                module.Dungeons:Refresh()
                            end
                        end,
                    },
                },
            },
        }
    )
end
