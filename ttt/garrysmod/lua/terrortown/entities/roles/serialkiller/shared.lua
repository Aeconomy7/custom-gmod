if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_sk.vmt")
end

roles.InitCustomTeam(ROLE.name, {
		icon = "vgui/ttt/dynamic/roles/icon_sk",
		color = Color(49, 105, 109, 255)
})

function ROLE:PreInitialize()
	self.color = Color(49, 105, 109, 255)

	self.abbr = "sk"
	self.score.surviveBonusMultiplier = 0.5
	self.score.timelimitMultiplier = -0.5
	self.score.killsMultiplier = 5
	self.score.teamKillsMultiplier = -16
	self.score.bodyFoundMuliplier = 0

	self.defaultTeam = TEAM_SERIALKILLER
	self.defaultEquipment = SPECIAL_EQUIPMENT

	self.isOmniscientRole = true

	self.conVarData = {
		pct = 0.13,
		maximum = 1,
		minPlayers = 8,
		credits = 1,
		creditsAwardDeadEnable = 1,
		creditsAwardKillEnable = 1,
		random = 20,
		togglable = true,
		shopFallback = SHOP_FALLBACK_TRAITOR
	}
end

function ROLE:Initialize()
	if SERVER and JESTER then
		-- add a easy role filtering to receive all jesters
		-- but just do it, when the role was created, then update it with recommended function
		-- theoretically this function is not necessary to call, but maybe there are some modifications
		-- of other addons. So it's better to use this function
		-- because it calls hooks and is doing some networking
		self.networkRoles = {JESTER}
	end
end

if SERVER then
	--CONSTANTS
	-- Enum for tracker mode
	local TRACKER_MODE = {NONE = 0, RADAR = 1, TRACKER = 2}

	-- Give Loadout on respawn and rolechange
	function ROLE:GiveRoleLoadout(ply, isRoleChange)
		ply:GiveEquipmentWeapon("weapon_ttt_sk_knife")
		if GetConVar("ttt2_serialkiller_tracker_mode"):GetInt() == TRACKER_MODE.RADAR then
			ply:GiveEquipmentItem("item_ttt_radar")
		elseif GetConVar("ttt2_serialkiller_tracker_mode"):GetInt() == TRACKER_MODE.TRACKER then
			ply:GiveEquipmentItem("item_ttt_tracker")
		end
		ply:GiveArmor(GetConVar("ttt2_serialkiller_armor"):GetInt())
	end

	-- Remove Loadout on death and rolechange
	function ROLE:RemoveRoleLoadout(ply, isRoleChange)
		ply:StripWeapon("weapon_ttt_sk_knife")
		if GetConVar("ttt2_serialkiller_tracker_mode"):GetInt() == TRACKER_MODE.RADAR then
			ply:RemoveEquipmentItem("item_ttt_radar")
		elseif GetConVar("ttt2_serialkiller_tracker_mode"):GetInt() == TRACKER_MODE.TRACKER then
			ply:RemoveEquipmentItem("item_ttt_tracker")
		end
		ply:RemoveArmor(GetConVar("ttt2_serialkiller_armor"):GetInt())
	end

	hook.Add("PlayerDeath", "SerialDeath", function(victim, infl, attacker)
		if IsValid(attacker) and attacker:IsPlayer() and attacker:GetSubRole() == ROLE_SERIALKILLER then
			timer.Stop("sksmokechecker")
			timer.Start("sksmokechecker")
			timer.Remove("sksmoke")
		end
	end)

	-- Damage scaling for Serial Killer
    local SK_WEAPON_DAMAGE_SCALE = 0.75   -- Serial Killer takes % damage from weapons
    local SK_GUN_DAMAGE_SCALE = 0.6      -- Serial Killer deals % damage with guns

    hook.Add("EntityTakeDamage", "SK_DamageScaling", function(victim, dmginfo)
        local attacker = dmginfo:GetAttacker()

        -- Reduce damage taken by SK from weapons
        if victim:IsPlayer() and victim:GetSubRole() == ROLE_SERIALKILLER then
            -- Only scale damage from guns
            if dmginfo:IsBulletDamage() then
                dmginfo:ScaleDamage(SK_WEAPON_DAMAGE_SCALE)
            end
        end

        -- Reduce damage dealt by SK with guns
        if attacker:IsPlayer() and attacker:GetSubRole() == ROLE_SERIALKILLER then
            if dmginfo:IsBulletDamage() then
                dmginfo:ScaleDamage(SK_GUN_DAMAGE_SCALE)
            end
        end
    end)
end
