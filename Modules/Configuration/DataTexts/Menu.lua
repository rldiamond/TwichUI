local T, W, I, C = unpack(Twich)

--- @class ConfigurationModule
local CM = T:GetModule("Configuration")
local E = unpack(ElvUI)
local LSM = E.Libs.LSM

--- @type DataTextsConfigurationModule
local DT = CM.DataTexts or {}
CM.DataTexts = DT

--- @class DataTextsMenuConfigurationModule
local DTM = DT.Menu or {}
DT.Menu = DTM

function DTM:Create()
    ---@return DataTextsModule
    local function GetModule()
        return T:GetModule("DataTexts")
    end

    local Menu = GetModule().Menu

    return {
        menuGroup = {
            type = "group",
            name = "Menu",
            order = 20,
            inline = true,
            args = {
                description = CM.Widgets:ComponentDescription(1,
                    "Customize the appearance and behavior of menus used by datatexts. Icons are skinnable through the use of Masque."),

                titleFontGroup = {
                    type = "group",
                    name = "Title Font",
                    order = 2,
                    inline = true,
                    args = {
                        titleColor = {
                            type = "color",
                            name = "Title Color",
                            desc = "Default color used for title entries.",
                            order = 2,
                            get = function()
                                local c = CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.TITLE_COLOR) or
                                    { r = 1, g = 0.82, b = 0 }
                                return c.r, c.g, c.b
                            end,
                            set = function(_, r, g, b)
                                CM:SetProfileSettingByConfigEntry(Menu.CONFIGURATION.TITLE_COLOR, { r = r, g = g, b = b })
                            end,
                        },

                        useElvuiTitleFont = {
                            type = "toggle",
                            name = "Use ElvUI Font Settings (Titles)",
                            desc = "When enabled, title entries inherit ElvUI general font settings.",
                            order = 1,
                            width = "full",
                            get = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.USE_ELVUI_TITLE_FONT)
                            end,
                            set = function(_, value)
                                CM:SetProfileSettingByConfigEntry(Menu.CONFIGURATION.USE_ELVUI_TITLE_FONT, value)
                            end,
                        },

                        titleFont = {
                            type = "select",
                            name = "Title Font",
                            order = 3,
                            width = 1.5,
                            dialogControl = "LSM30_Font",
                            values = function() return LSM:HashTable("font") end,
                            disabled = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.USE_ELVUI_TITLE_FONT)
                            end,
                            get = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.TITLE_FONT)
                            end,
                            set = function(_, value)
                                CM:SetProfileSettingByConfigEntry(Menu.CONFIGURATION.TITLE_FONT, value)
                            end,
                        },

                        titleFontSize = {
                            type = "range",
                            name = "Title Font Size",
                            order = 4,
                            min = 8,
                            max = 24,
                            step = 1,
                            disabled = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.USE_ELVUI_TITLE_FONT)
                            end,
                            get = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.TITLE_FONT_SIZE)
                            end,
                            set = function(_, value)
                                CM:SetProfileSettingByConfigEntry(Menu.CONFIGURATION.TITLE_FONT_SIZE, value)
                            end,
                        },

                        titleFontFlag = {
                            type = "select",
                            name = "Title Font Outline",
                            order = 5,
                            width = 1.0,
                            disabled = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.USE_ELVUI_TITLE_FONT)
                            end,
                            values = {
                                NONE = "None",
                                OUTLINE = "Outline",
                                MONOCHROMEOUTLINE = "Monochrome Outline",
                                THICKOUTLINE = "Thick Outline",
                            },
                            get = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.TITLE_FONT_FLAG)
                            end,
                            set = function(_, value)
                                CM:SetProfileSettingByConfigEntry(Menu.CONFIGURATION.TITLE_FONT_FLAG, value)
                            end,
                        },
                    },
                },

                fontGroup = {
                    type = "group",
                    name = "Font (Entries)",
                    order = 3,
                    inline = true,
                    args = {
                        useElvuiFont = {
                            type = "toggle",
                            name = "Use ElvUI Font Settings",
                            desc = CM:ColorTextKeywords("When enabled, menus inherit " ..
                                "ElvUI" .. " general font settings."),
                            order = 1,
                            width = "full",
                            get = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.USE_ELVUI_FONT)
                            end,
                            set = function(_, value)
                                CM:SetProfileSettingByConfigEntry(Menu.CONFIGURATION.USE_ELVUI_FONT, value)
                            end,
                        },

                        textColor = {
                            type = "color",
                            name = "Text Color",
                            desc =
                            "Default color used for non-title menu entries (unless an entry provides its own color).",
                            order = 2,
                            get = function()
                                local c = CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.TEXT_COLOR) or
                                    { r = 1, g = 1, b = 1 }
                                return c.r, c.g, c.b
                            end,
                            set = function(_, r, g, b)
                                CM:SetProfileSettingByConfigEntry(Menu.CONFIGURATION.TEXT_COLOR, { r = r, g = g, b = b })
                            end,
                        },

                        font = {
                            type = "select",
                            name = "Font",
                            order = 3,
                            width = 1.5,
                            dialogControl = "LSM30_Font",
                            values = function() return LSM:HashTable("font") end,
                            disabled = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.USE_ELVUI_FONT)
                            end,
                            get = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.FONT)
                            end,
                            set = function(_, value)
                                CM:SetProfileSettingByConfigEntry(Menu.CONFIGURATION.FONT, value)
                            end,
                        },

                        fontSize = {
                            type = "range",
                            name = "Font Size",
                            order = 4,
                            min = 8,
                            max = 24,
                            step = 1,
                            disabled = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.USE_ELVUI_FONT)
                            end,
                            get = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.FONT_SIZE)
                            end,
                            set = function(_, value)
                                CM:SetProfileSettingByConfigEntry(Menu.CONFIGURATION.FONT_SIZE, value)
                            end,
                        },

                        fontFlag = {
                            type = "select",
                            name = "Font Outline",
                            order = 5,
                            width = 1.0,
                            disabled = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.USE_ELVUI_FONT)
                            end,
                            values = {
                                NONE = "None",
                                OUTLINE = "Outline",
                                MONOCHROMEOUTLINE = "Monochrome Outline",
                                THICKOUTLINE = "Thick Outline",
                            },
                            get = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.FONT_FLAG)
                            end,
                            set = function(_, value)
                                CM:SetProfileSettingByConfigEntry(Menu.CONFIGURATION.FONT_FLAG, value)
                            end,
                        },
                    },
                },

                otherGroup = {
                    type = "group",
                    name = "Other",
                    order = 4,
                    inline = true,
                    args = {
                        padding = {
                            type = "range",
                            name = "Padding",
                            order = 1,
                            min = 4,
                            max = 24,
                            step = 1,
                            get = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.PADDING)
                            end,
                            set = function(_, value)
                                CM:SetProfileSettingByConfigEntry(Menu.CONFIGURATION.PADDING, value)
                            end,
                        },

                        iconTextSpacing = {
                            type = "range",
                            name = "Icon/Text Spacing",
                            desc = "Space (in pixels) between the icon texture and the menu text.",
                            order = 2,
                            min = 0,
                            max = 20,
                            step = 1,
                            get = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.ICON_TEXT_SPACING)
                            end,
                            set = function(_, value)
                                CM:SetProfileSettingByConfigEntry(Menu.CONFIGURATION.ICON_TEXT_SPACING, value)
                            end,
                        },

                        hoverAlpha = {
                            type = "range",
                            name = "Hover Alpha",
                            order = 3,
                            min = 0,
                            max = 0.30,
                            step = 0.01,
                            isPercent = false,
                            get = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.HOVER_ALPHA)
                            end,
                            set = function(_, value)
                                CM:SetProfileSettingByConfigEntry(Menu.CONFIGURATION.HOVER_ALPHA, value)
                            end,
                        },

                        autoHideDelay = {
                            type = "range",
                            name = "Auto Hide Delay",
                            desc = "Seconds before menus automatically hide when the mouse leaves.",
                            order = 4,
                            min = 0.5,
                            max = 10,
                            step = 0.5,
                            get = function()
                                return CM:GetProfileSettingByConfigEntry(Menu.CONFIGURATION.AUTO_HIDE_DELAY)
                            end,
                            set = function(_, value)
                                CM:SetProfileSettingByConfigEntry(Menu.CONFIGURATION.AUTO_HIDE_DELAY, value)
                            end,
                        },
                    },
                },
            }
        }
    }
end
