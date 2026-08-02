std = "lua51"
max_line_length = 120

-- The luarocks CI action installs into .luarocks/ inside the workspace, so
-- `luacheck .` would otherwise lint the toolchain along with the addon.
exclude_files = {".luarocks/**", ".luarocks", "lua_modules/**"}

-- WoW event handlers always receive (self, event, ...); ignore unused args
-- entirely since callbacks must match Blizzard's fixed signatures.
ignore = {
    "212",           -- unused argument
    "211/addonName", -- every file starts `local addonName, ns = ...`
}

globals = {
    -- SavedVariables declared in the .toc
    "CoyFlightline_GlobalData",

    "SLASH_COYFLIGHTLINE1",
    "SLASH_COYFLIGHTLINE2",
    "SlashCmdList",
}

read_globals = {
    -- Namespaced API tables
    "C_AddOns", "C_CVar", "C_Map", "C_PlayerInfo",

    -- Frame / UI globals
    "CreateFrame", "UIParent", "Minimap", "WorldMapFrame", "BattlefieldMapFrame",
    "GetMinimapShape",

    -- Settings API
    "Settings", "CreateSettingsListSectionHeaderInitializer",
    "MinimalSliderWithSteppersMixin",

    -- Player / world state
    "EventUtil", "GetCVarBool", "GetPlayerFacing", "IsFlying", "IsInInstance",
    "UnitOnTaxi",
}
