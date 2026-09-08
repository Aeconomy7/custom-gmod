-- Speed modifier based on held weapon type.
-- Holstered / melee / grenade / equipment → 1.2x
-- Secondary (pistol) → 1.1x
-- Primary (heavy) → 1.0x
-- Disabled entirely during knife_round and crowbar_ffa.

local SKIP_MODES = { knife_round = true, crowbar_ffa = true }

hook.Add("SetupMove", "sc0b_WeaponSpeedMod", function(ply, mv)
    if not ply:IsPlayer() or not ply:Alive() then return end

    local mode = SC0B_GetCurrentSpecialMode and SC0B_GetCurrentSpecialMode()
    if mode and SKIP_MODES[mode] then return end

    local wep  = ply:GetActiveWeapon()
    local base = mv:GetMaxSpeed()
    local kind = IsValid(wep) and wep.Kind or nil

    if kind == WEAPON_HEAVY then
        -- primary — no modifier
    elseif kind == WEAPON_PISTOL then
        mv:SetMaxSpeed(base * 1.1)
    else
        -- melee, nade, equip, holstered
        mv:SetMaxSpeed(base * 1.2)
    end
end)
