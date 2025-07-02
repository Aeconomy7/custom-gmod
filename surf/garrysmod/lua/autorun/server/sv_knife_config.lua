-- sv_knife_config.lua
-- Dynamically builds KnifeSkins table for !knife menu

if not SERVER then return end

KnifeSkins = {}

-- Find all SWEP files following the naming pattern
local swepFiles = file.Find("lua/weapons/csgo_*.lua", "GAME")

if not swepFiles or #swepFiles == 0 then
    print("[KnifeConfig] No SWEPs found matching csgo_*.lua")
    return
end

for _, fileName in ipairs(swepFiles) do
    local className = string.StripExtension(fileName) -- e.g. csgo_butterfly_fade
    local displayName = className:gsub("csgo_", ""):gsub("_", " ")
    displayName = displayName:sub(1,1):upper() .. displayName:sub(2) -- capitalize first letter

    -- Example icon path: materials/vgui/entities/csgo_butterfly_fade.vmt
    local iconPath = "vgui/entities/" .. className .. ".vmt"

    -- Confirm material exists
    if not file.Exists("materials/" .. iconPath, "GAME") then
        print("[KnifeConfig] WARNING: Icon not found for", className, "- fallback to vgui/white")
        iconPath = "vgui/white"
    end

    table.insert(KnifeSkins, {
        name = displayName,
        class = className,
        icon = iconPath
    })
end

print("[KnifeConfig] Loaded knife skins:")
PrintTable(KnifeSkins)