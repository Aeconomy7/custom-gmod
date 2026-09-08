-- Pre-register convars expected by addons whose dependencies aren't installed.
-- This file is named "compat_..." so it loads before those addons alphabetically.

-- xj9_enable_expressions: expected by jenny_wakeman_comportamiento.lua (XJ9 playermodel addon)
if not GetConVar("xj9_enable_expressions") then
    CreateConVar("xj9_enable_expressions", "1", { FCVAR_REPLICATED }, "Enable XJ9 face expressions")
end
