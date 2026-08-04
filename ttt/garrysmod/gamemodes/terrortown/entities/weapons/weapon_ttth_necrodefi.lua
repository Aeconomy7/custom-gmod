if SERVER then
    AddCSLuaFile()
end

local flags = { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }

DEFINE_BASECLASS("weapon_ttt_defibrillator")

SWEP.Base = "weapon_ttt_defibrillator"

if CLIENT then
    SWEP.EquipMenuData = {
        type = "item_weapon",
        name = "necro_defi_name",
        desc = "necro_defi_desc",
    }

    SWEP.Icon = "vgui/ttt/icon_defi_necro"
end

SWEP.Kind = WEAPON_EQUIP2
SWEP.CanBuy = nil
SWEP.notBuyable = true

SWEP.EnableConfigurableClip = true
SWEP.ConfigurableClip = 3

SWEP.AllowDrop = false

SWEP.cvars = {
    reviveBraindead = CreateConVar("ttt_necro_defibrillator_revive_braindead", "1", flags),
    playSound = CreateConVar("ttt_necro_defibrillator_play_sounds", "0", flags),
    reviveTime = CreateConVar("ttt_necro_defibrillator_revive_time", "3.0", flags),
    errorTime = CreateConVar("ttt_necro_defibrillator_error_time", "1.5", flags),
    successChance = CreateConVar("ttt_necro_defibrillator_success_chance", "100", flags),
    resetConfirmation = CreateConVar("ttt_necro_defibrillator_reset_confirm", "0", flags),
    revivalHealth = CreateConVar("ttt_necro_defibrillator_revival_health", "75", flags),
    revivalMaxHealth = CreateConVar("ttt_necro_defibrillator_revival_max_health", "75", flags),
}

local cvReviveZombies = CreateConVar("ttt_necro_defibrillator_revive_zombies", "0", flags)

SWEP.revivalReason = "revived_by_necromancer"

if SERVER then
    -- Local copies of base-file constants (they're local there, not accessible here).
    local DEFI_BUSY              = 1
    local DEFI_ERROR_LOST_TARGET = 3
    local DEFI_ERROR_PLAYER_ALIVE = 7

    function SWEP:OnDrop()
        self:Remove()
    end

    -- Override Think with a 100ms offset instead of the base's 10ms.
    -- GMod processes timer callbacks before Think hooks within the same server tick
    -- (~15ms at 66fps). The base 10ms window is not wide enough: when both the Revive
    -- timer and Think become due in the same tick, the timer fires first, causing
    -- SpawnForRound to run before AddZombie → the player spawns with their original role.
    -- 100ms ≈ 7 ticks of lead time, making that race condition practically impossible.
    function SWEP:Think()
        if self:GetState() ~= DEFI_BUSY then return end

        local owner  = self:GetOwner()
        local target = CORPSE.GetPlayer(self.defiTarget)

        if CurTime() >= self:GetStartTime() + self.cvars.reviveTime:GetFloat() - 0.1 then
            self:FinishRevival(target, owner)
        elseif not owner:KeyDown(IN_ATTACK) or owner:GetEyeTrace(MASK_SHOT_HULL).Entity ~= self.defiTarget then
            self:CancelRevival(target)
            self:Error(DEFI_ERROR_LOST_TARGET, self.defiTarget)
        elseif IsValid(target) and target:IsTerror() then
            self:CancelRevival(target)
            self:Error(DEFI_ERROR_PLAYER_ALIVE, target)
        end
    end

    function SWEP:OnRevive(ply, owner)
        AddZombie(ply, owner)

        -- Belt-and-suspenders: if the timing race still managed to let SpawnForRound
        -- fire before AddZombie (e.g. server lag spike), the player will have spawned
        -- with their original role's loadout. Re-strip and re-apply zombie loadout
        -- in the next tick, after any remaining spawn callbacks have settled.
        timer.Simple(0, function()
            if not IsValid(ply) or not ply:Alive() or ply:GetSubRole() ~= ROLE_ZOMBIE then return end

            ply:StripAll()
            ply:GetSubRoleData():GiveRoleLoadout(ply, true)
        end)
    end

    function SWEP:OnReviveStart(ply, owner)
        if not cvReviveZombies:GetBool() and ply:GetSubRole() == ROLE_ZOMBIE then
            LANG.Msg(owner, "necrodefi_error_zombie", nil, MSG_MSTACK_WARN)

            return false
        end
    end
end

if CLIENT then
    function SWEP:AddToSettingsMenu(parent)
        BaseClass.AddToSettingsMenu(self, parent)

        local form = vgui.CreateTTT2Form(parent, "header_equipment_necrodefi")

        form:MakeCheckBox({
            label = "label_necro_defibrillator_revive_zombies",
            serverConvar = "ttt_necro_defibrillator_revive_zombies",
        })
    end
end
