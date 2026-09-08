if not SERVER then return end

CreateConVar("special_round_pct", "5", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Base percent chance of a special round; increases by this amount each normal round and resets when a special round fires", 0, 100)

util.AddNetworkString("sc0b_SpecialRoundType")
util.AddNetworkString("sc0b_PlantDefuseBlind")
util.AddNetworkString("TTT_C4PDDisarmResult")

-- ─────────────────────────────────────────────
-- Mode definitions
-- ─────────────────────────────────────────────
local SPECIAL_MODES = {
    -- { id = "tank",           name = "Tank Mode",       scale = 1.5, health = 250 },
    { id = "tiny",             name = "Tiny Mode",         scale = 0.5, health = 50  },
    { id = "speed",            name = "Speed Mode",        speed_mult = 1.5          },
    { id = "bhop",             name = "Bunny Hop Mode"                               },
    { id = "superman",         name = "Superman Mode"                                },
    { id = "screw_jump",       name = "Screw Jump Mode"                              },
    { id = "chaos",            name = "Chaos Mode"                                   },
    { id = "knife_round",      name = "Knife Round"                                  },
    { id = "crowbar_ffa",      name = "GO BONKERS!"                                  },
    { id = "low_grav",         name = "Low Gravity"                                  },
    -- { id = "double_time",    name = "Double Time"                                 },
    { id = "slow_mo",          name = "Slow Motion"                                  },
    { id = "exploding_props",  name = "Exploding Props"                              },
    { id = "oops_all_zombies",  name = "Oops All Zombies"                              },
    { id = "plant_and_defuse", name = "Plant and Defuse", min_players = 5             },
}

-- ─────────────────────────────────────────────
-- Random selection (equal weight)
-- ─────────────────────────────────────────────
local function PickRandomMode()
    local n = #player.GetAll()
    local available = {}
    for _, m in ipairs(SPECIAL_MODES) do
        if not m.min_players or n >= m.min_players then
            available[#available + 1] = m
        end
    end
    if #available == 0 then return nil end
    return available[math.random(#available)]
end

-- ─────────────────────────────────────────────
-- State
-- ─────────────────────────────────────────────
local currentMode    = nil   -- active only during ROUND_ACTIVE
local pendingMode    = nil   -- chosen during prep, promoted to currentMode at TTTBeginRound

-- Used by roundendmusicserver.lua to pick special-round music.
-- sc0b_GetLastRoundModeID is preferred: it's captured before cleanup so hook order doesn't matter.
function sc0b_GetCurrentModeID()
    return currentMode and currentMode.id or nil
end
local lastRoundModeID = nil  -- set at round-end, cleared at next prep
function sc0b_GetLastRoundModeID()
    return lastRoundModeID
end
local forcedMode     = nil   -- set by admin command; consumed on next TTTBeginRound
local currentPct     = nil   -- lazily initialized; tracks rolling chance; persisted across map changes
local roundCount     = 0     -- total rounds started this session
local lastWasSpecial = false -- whether the previous round was a special round

-- ─────────────────────────────────────────────
-- Persistence (survives map changes)
-- ─────────────────────────────────────────────
local PCT_FILE = "sc0b_special_round_pct.txt"

local function SavePct()
    file.Write(PCT_FILE, tostring(currentPct))
end

local function LoadPct()
    if file.Exists(PCT_FILE, "DATA") then
        return tonumber(file.Read(PCT_FILE, "DATA"))
    end
end

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────
local VIEW_OFFSET_STAND  = Vector(0, 0, 64)
local VIEW_OFFSET_DUCKED = Vector(0, 0, 28)

local function ApplyMode(ply, mode)
    if not IsValid(ply) then return end

    -- Scale / health
    if mode.scale then
        local ok, err = pcall(ply.SetModelScale, ply, mode.scale, 0)
        if not ok then
            print("[SR] SetModelScale failed for " .. ply:Nick() .. ": " .. tostring(err))
        end
        ply:SetViewOffset(VIEW_OFFSET_STAND  * mode.scale)
        ply:SetViewOffsetDucked(VIEW_OFFSET_DUCKED * mode.scale)
    end
    if mode.health then
        ply:SetMaxHealth(mode.health)
        ply:SetHealth(mode.health)
    end

    -- Speed
    if mode.speed_mult then
        ply.sr_orig_walk = ply:GetWalkSpeed()
        ply.sr_orig_run  = ply:GetRunSpeed()
        ply:SetWalkSpeed(ply.sr_orig_walk * mode.speed_mult)
        ply:SetRunSpeed(ply.sr_orig_run  * mode.speed_mult)
    end

    -- Screw jump
    if mode.id == "screw_jump" then
        local jumps = GetConVar("multijump_screw_jumps"):GetInt()
        ply:SetMaxJumpLevel(jumps)
    end

    -- Bhop: single jump only (auto-bhop via StartCommand hook)
    if mode.id == "bhop" then
        ply:SetMaxJumpLevel(0)
    end

    -- Chaos: give everyone enough credits so shop items are not greyed out
    if mode.id == "chaos" then
        ply:SetCredits(9999)
    end

    -- Superman: give all passive buff items via TTT2's item system
    if mode.id == "superman" and items then
        for _, item in pairs(items.GetList()) do
            if item.EquipMenuData and item.EquipMenuData.type == "item_passive" then
                ply:GiveEquipmentItem(item.id)
            end
        end
    end

end

local function ClearMode(ply)
    if not IsValid(ply) then return end

    -- Scale / health
    pcall(ply.SetModelScale, ply, 1.0, 0)
    ply:SetMaxHealth(100)
    ply:SetHealth(math.min(ply:Health(), 100))
    ply:SetViewOffset(VIEW_OFFSET_STAND)
    ply:SetViewOffsetDucked(VIEW_OFFSET_DUCKED)

    -- Speed
    if ply.sr_orig_walk then
        ply:SetWalkSpeed(ply.sr_orig_walk)
        ply.sr_orig_walk = nil
    end
    if ply.sr_orig_run then
        ply:SetRunSpeed(ply.sr_orig_run)
        ply.sr_orig_run = nil
    end

    -- Jump level - restore to server default
    local default_jumps = GetConVar("multijump_default_jumps")
    if default_jumps then
        ply:SetMaxJumpLevel(default_jumps:GetInt())
    end

    -- Superman: strip all passive buff items
    if items then
        for _, item in pairs(items.GetList()) do
            if item.EquipMenuData and item.EquipMenuData.type == "item_passive" then
                if ply:HasEquipmentItem(item.id) then
                    ply:RemoveEquipmentItem(item.id)
                end
            end
        end
    end
end

-- ─────────────────────────────────────────────
-- Bhop: strip IN_JUMP while airborne so the engine
--       treats landing with space held as a fresh press.
--       Emit a jump sound audible to nearby players.
-- ─────────────────────────────────────────────
local bhopWasOnGround = {}

hook.Add("StartCommand", "sc0b_BhopMode", function(ply, cmd)
    if not currentMode or currentMode.id ~= "bhop" then return end
    if not IsValid(ply) or ply:IsSpec() then return end

    local sid      = ply:SteamID64()
    local onGround = ply:IsOnGround()

    -- Auto-bhop: strip jump input while airborne
    if not onGround and cmd:KeyDown(IN_JUMP) then
        cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(IN_JUMP)))
    end

    -- Emit jump sound the tick the player leaves the ground
    if bhopWasOnGround[sid] and not onGround then
        ply:EmitSound("player/footsteps/jump1.wav", 75, math.random(95, 105), 0.7)
    end

    bhopWasOnGround[sid] = onGround
end)

-- ─────────────────────────────────────────────
-- Knife Round: CSGO knife skin pool (skinned variants only)
-- ─────────────────────────────────────────────
local KNIFE_SKINS = {
    -- Bayonet
    "csgo_bayonet_autotronic","csgo_bayonet_black_laminate","csgo_bayonet_bluesteel",
    "csgo_bayonet_boreal","csgo_bayonet_bright_water","csgo_bayonet_case",
    "csgo_bayonet_crimsonwebs","csgo_bayonet_damascus","csgo_bayonet_ddpat",
    "csgo_bayonet_fade","csgo_bayonet_freehand","csgo_bayonet_gamma_doppler",
    "csgo_bayonet_lore","csgo_bayonet_marblefade","csgo_bayonet_night",
    "csgo_bayonet_rustcoat","csgo_bayonet_slaughter","csgo_bayonet_tiger",
    "csgo_bayonet_ultraviolet",
    -- Bowie
    "csgo_bowie_bluesteel","csgo_bowie_boreal","csgo_bowie_bright_water",
    "csgo_bowie_case","csgo_bowie_crimsonwebs","csgo_bowie_damascus",
    "csgo_bowie_ddpat","csgo_bowie_fade","csgo_bowie_freehand",
    "csgo_bowie_gamma_doppler","csgo_bowie_marblefade","csgo_bowie_night",
    "csgo_bowie_rustcoat","csgo_bowie_slaughter","csgo_bowie_tiger",
    "csgo_bowie_ultraviolet",
    -- Butterfly
    "csgo_butterfly_bluesteel","csgo_butterfly_boreal","csgo_butterfly_bright_water",
    "csgo_butterfly_case","csgo_butterfly_crimsonwebs","csgo_butterfly_damascus",
    "csgo_butterfly_ddpat","csgo_butterfly_fade","csgo_butterfly_freehand",
    "csgo_butterfly_gamma_doppler","csgo_butterfly_marblefade","csgo_butterfly_night",
    "csgo_butterfly_rustcoat","csgo_butterfly_slaughter","csgo_butterfly_tiger",
    "csgo_butterfly_ultraviolet",
    -- Daggers
    "csgo_daggers_bluesteel","csgo_daggers_boreal","csgo_daggers_bright_water",
    "csgo_daggers_case","csgo_daggers_damascus","csgo_daggers_ddpat",
    "csgo_daggers_fade","csgo_daggers_freehand","csgo_daggers_gamma_doppler",
    "csgo_daggers_greyscaled","csgo_daggers_marblefade","csgo_daggers_night",
    "csgo_daggers_rustcoat","csgo_daggers_slaughter","csgo_daggers_tiger",
    "csgo_daggers_ultraviolet","csgo_daggers_webs",
    -- Falchion
    "csgo_falchion_bluesteel","csgo_falchion_boreal","csgo_falchion_bright_water",
    "csgo_falchion_case","csgo_falchion_crimsonwebs","csgo_falchion_damascus",
    "csgo_falchion_ddpat","csgo_falchion_fade","csgo_falchion_freehand",
    "csgo_falchion_gamma_doppler","csgo_falchion_marblefade","csgo_falchion_night",
    "csgo_falchion_rustcoat","csgo_falchion_slaughter","csgo_falchion_tiger",
    "csgo_falchion_ultraviolet",
    -- Flip
    "csgo_flip_autotronic","csgo_flip_black_laminate","csgo_flip_bluesteel",
    "csgo_flip_boreal","csgo_flip_bright_water","csgo_flip_case",
    "csgo_flip_crimsonwebs","csgo_flip_damascus","csgo_flip_ddpat",
    "csgo_flip_fade","csgo_flip_freehand","csgo_flip_gamma_doppler",
    "csgo_flip_lore","csgo_flip_marblefade","csgo_flip_night",
    "csgo_flip_rustcoat","csgo_flip_slaughter","csgo_flip_tiger",
    "csgo_flip_ultraviolet",
    -- Gut
    "csgo_gut_autotronic","csgo_gut_black_laminate","csgo_gut_bluesteel",
    "csgo_gut_boreal","csgo_gut_bright_water","csgo_gut_case",
    "csgo_gut_crimsonwebs","csgo_gut_damascus","csgo_gut_ddpat",
    "csgo_gut_fade","csgo_gut_freehand","csgo_gut_gamma_doppler",
    "csgo_gut_lore","csgo_gut_marblefade","csgo_gut_night",
    "csgo_gut_rustcoat","csgo_gut_slaughter","csgo_gut_tiger",
    "csgo_gut_ultraviolet",
    -- Huntsman
    "csgo_huntsman_bluesteel","csgo_huntsman_boreal","csgo_huntsman_bright_water",
    "csgo_huntsman_case","csgo_huntsman_crimsonwebs","csgo_huntsman_damascus",
    "csgo_huntsman_ddpat","csgo_huntsman_fade","csgo_huntsman_freehand",
    "csgo_huntsman_gamma_doppler","csgo_huntsman_marblefade","csgo_huntsman_night",
    "csgo_huntsman_rustcoat","csgo_huntsman_slaughter","csgo_huntsman_tiger",
    "csgo_huntsman_ultraviolet",
    -- Karambit
    "csgo_karambit_autotronic","csgo_karambit_black_laminate","csgo_karambit_bluesteel",
    "csgo_karambit_boreal","csgo_karambit_bright_water","csgo_karambit_case",
    "csgo_karambit_crimsonwebs","csgo_karambit_damascus","csgo_karambit_ddpat",
    "csgo_karambit_fade","csgo_karambit_freehand","csgo_karambit_gamma_doppler",
    "csgo_karambit_lore","csgo_karambit_marblefade","csgo_karambit_night",
    "csgo_karambit_rustcoat","csgo_karambit_slaughter","csgo_karambit_tiger",
    "csgo_karambit_ultraviolet",
    -- M9
    "csgo_m9_autotronic","csgo_m9_black_laminate","csgo_m9_bluesteel",
    "csgo_m9_boreal","csgo_m9_bright_water","csgo_m9_case",
    "csgo_m9_crimsonwebs","csgo_m9_damascus","csgo_m9_ddpat",
    "csgo_m9_fade","csgo_m9_freehand","csgo_m9_gamma_doppler",
    "csgo_m9_lore","csgo_m9_marblefade","csgo_m9_night",
    "csgo_m9_rustcoat","csgo_m9_slaughter","csgo_m9_tiger",
    "csgo_m9_ultraviolet",
}

-- Crowbar Brawl: assign everyone ROLE_FFA (team "ffas") for a true free-for-all
hook.Add("TTT2ModifyFinalRoles", "sc0b_CrowbarFFARoles", function(finalRoles)
    if not pendingMode or pendingMode.id ~= "crowbar_ffa" then return end
    for ply in pairs(finalRoles) do
        if IsValid(ply) then
            finalRoles[ply] = ROLE_FFA
        end
    end
end)

-- Knife Round: same 50/50 Red/Blue split as Chaos
hook.Add("TTT2ModifyFinalRoles", "sc0b_KnifeRoundRoleFilter", function(finalRoles)
    if not pendingMode or pendingMode.id ~= "knife_round" then return end

    local allPlayers = {}
    for ply in pairs(finalRoles) do
        if IsValid(ply) then allPlayers[#allPlayers + 1] = ply end
    end

    local total    = #allPlayers
    local redCount = math.ceil(total / 2)

    for i = total, 2, -1 do
        local j = math.random(i)
        allPlayers[i], allPlayers[j] = allPlayers[j], allPlayers[i]
    end

    for i, ply in ipairs(allPlayers) do
        finalRoles[ply] = (i <= redCount) and ROLE_REDTEAM or ROLE_BLUETEAM
    end
end)

-- ─────────────────────────────────────────────
-- Chaos: restrict to innocents + traitors only,
--        open T shop to everyone with infinite credits
-- ─────────────────────────────────────────────

-- Before roles are assigned, force a ~50/50 innocent/traitor split
hook.Add("TTT2ModifyFinalRoles", "sc0b_ChaosRoleFilter", function(finalRoles)
    if not pendingMode or pendingMode.id ~= "chaos" then return end

    local allPlayers = {}
    for ply in pairs(finalRoles) do
        if IsValid(ply) then
            allPlayers[#allPlayers + 1] = ply
        end
    end

    local total = #allPlayers
    local redCount = math.ceil(total / 2)

    -- Fisher-Yates shuffle
    for i = total, 2, -1 do
        local j = math.random(i)
        allPlayers[i], allPlayers[j] = allPlayers[j], allPlayers[i]
    end

    for i, ply in ipairs(allPlayers) do
        finalRoles[ply] = (i <= redCount) and ROLE_REDTEAM or ROLE_BLUETEAM
    end
end)

-- ─────────────────────────────────────────────
-- Chaos: per-team shops
-- Edit these lists to control what each team can buy.
-- On first run they are written to the ShopEditor SQL tables;
-- afterwards the admin can also adjust them in-game via F1 → Roles.
-- ─────────────────────────────────────────────
local CHAOS_RED_SHOP = {
    "item_ttt_armor",
    "item_ttt_radar",
    "item_ttt_speedrun",
    "weapon_ttt_frag",
    "weapon_ttt_knife",
    "weapon_ttt_ak47",
    "weapon_ttt_m16",
    "weapon_ttt_smokegrenade",
}

local CHAOS_BLUE_SHOP = {
    "item_ttt_armor",
    "item_ttt_radar",
    "item_ttt_speedrun",
    "weapon_ttt_frag",
    "weapon_ttt_knife",
    "weapon_ttt_cloak",
    "weapon_ttt_binoculars",
    "weapon_ttt_smokegrenade",
}

hook.Add("LoadedFallbackShops", "sc0b_SeedChaosTeamShops", function()
    local function seedShop(roleName, itemList)
        local tbl = "ttt2_shop_" .. roleName
        if not sql.TableExists(tbl) then return end
        local row = sql.QueryRow("SELECT COUNT(*) as c FROM " .. tbl)
        if row and tonumber(row.c) > 0 then return end  -- already configured
        for _, id in ipairs(itemList) do
            sql.Query("INSERT OR IGNORE INTO " .. tbl .. " VALUES (" .. sql.SQLStr(id) .. ")")
        end
    end

    seedShop("redteam",  CHAOS_RED_SHOP)
    seedShop("blueteam", CHAOS_BLUE_SHOP)
end)

local WEAPON_ONLY_MODES = { knife_round = true, crowbar_ffa = true, plant_and_defuse = true }

-- Allow everyone to buy from shop during Chaos mode, for free
hook.Add("TTT2CanOrderEquipment", "sc0b_ChaosShop", function(ply, equipmentName, isItem, credits)
    if currentMode and currentMode.id == "chaos" then
        return true, true  -- allow purchase + ignore credit cost
    end
    -- Block all purchases during weapon-only rounds
    if currentMode and WEAPON_ONLY_MODES[currentMode.id] then
        return false
    end
end)

-- Block PS2 perma-weapons in weapon-only rounds (knife_round, crowbar_ffa).
-- PS2's sh_base_weapon.lua checks this hook before calling ply:Give(); returning
-- false is the intended suppression point, preventing the OnRoundSet timer from
-- re-arming players after our TTTBeginRound StripAll.
hook.Add("PS2_WeaponShouldSpawn", "sc0b_WeaponOnlyRoundBlockPS2", function(ply)
    if currentMode and WEAPON_ONLY_MODES[currentMode.id] then
        return false
    end
end)

-- Block no-explosion-damage item during Exploding Props (unfair immunity)
hook.Add("TTT2CanOrderEquipment", "sc0b_ExplodingPropsShopBlock", function(ply, equipmentName)
    local mode = pendingMode or currentMode
    if mode and mode.id == "exploding_props" then
        if equipmentName == "item_ttt_noexplosiondmg" then
            return false
        end
    end
end)

-- Plant and Defuse: 1 planter per 5 players (floor), rest defusers
hook.Add("TTT2ModifyFinalRoles", "sc0b_PlantAndDefuseRoles", function(finalRoles)
    if not pendingMode or pendingMode.id ~= "plant_and_defuse" then return end

    local allPlayers = {}
    for ply in pairs(finalRoles) do
        if IsValid(ply) then allPlayers[#allPlayers + 1] = ply end
    end

    local total       = #allPlayers
    local planterCount = math.max(1, math.floor(total / 5))

    -- Fisher-Yates shuffle
    for i = total, 2, -1 do
        local j = math.random(i)
        allPlayers[i], allPlayers[j] = allPlayers[j], allPlayers[i]
    end

    for i, ply in ipairs(allPlayers) do
        finalRoles[ply] = (i <= planterCount) and ROLE_PLANTER or ROLE_DEFUSER
    end
end)

-- Tank: strip Jester and Marker before role assignment
hook.Add("TTT2ModifyFinalRoles", "sc0b_TankRoleFilter", function(finalRoles)
    if not pendingMode or pendingMode.id ~= "tank" then return end

    for ply, roleID in pairs(finalRoles) do
        if roleID == ROLE_JESTER or roleID == ROLE_MARKER then
            finalRoles[ply] = ROLE_INNOCENT
        end
    end
end)

-- Oops All Zombies: force everyone to ROLE_ZOMBIE before round start.
hook.Add("TTT2ModifyFinalRoles", "sc0b_OopsAllZombiesRoles", function(finalRoles)
    if not pendingMode or pendingMode.id ~= "oops_all_zombies" then return end

    for ply in pairs(finalRoles) do
        if IsValid(ply) then
            finalRoles[ply] = ROLE_ZOMBIE
        end
    end
end)

-- Oops All Zombies: custom FFA win condition.
-- Counts individual alive players rather than teams, so the round only ends
-- when one zombie is left standing. Returning non-nil here prevents
-- GM:TTTCheckForWin (the default team-based check) from running at all.
hook.Add("TTTCheckForWin", "sc0b_OopsAllZombiesWin", function()
    if not currentMode or currentMode.id ~= "oops_all_zombies" then return end

    local alive = 0
    local lastTeam, lastSteamID
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsTerror() then
            alive       = alive + 1
            lastTeam    = ply:GetTeam()
            lastSteamID = ply:SteamID64()
        end
    end

    if alive > 1 then return WIN_NONE end     -- round continues
    if alive == 1 then
        SC0B_OAZ_WinnerSteamID = lastSteamID
        return lastTeam
    end
    return TEAM_NONE                          -- everyone died at once
end)

-- Crowbar Brawl: last FFA player standing wins.
-- Overriding TTTCheckForWin entirely prevents the default team-based check
-- (which would instantly end the round since there are no traitors).
hook.Add("TTTCheckForWin", "sc0b_CrowbarFFAWin", function()
    if not currentMode or currentMode.id ~= "crowbar_ffa" then return end

    local alive = 0
    local lastTeam, lastSteamID
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsTerror() then
            alive       = alive + 1
            lastTeam    = ply:GetTeam()
            lastSteamID = ply:SteamID64()
        end
    end

    if alive > 1 then return WIN_NONE end
    if alive == 1 then
        SC0B_CBR_WinnerSteamID = lastSteamID
        SC0B_OAZ_WinnerSteamID = lastSteamID  -- sv_log_rounds picks this up for winner_steamid
        return lastTeam
    end
    return TEAM_NONE
end)

-- TDM balance revive: if Red vs Blue teams are uneven by 1, the first player
-- to die on the smaller team is revived, equalising total lives.
local TDM_MODES = { knife_round = true, chaos = true }

hook.Add("PlayerDeath", "sc0b_TDMBalanceRevive", function(victim, inflictor, attacker)
    if not currentMode or not TDM_MODES[currentMode.id] then return end
    if not currentMode._balanceReviveTeam then return end
    if not IsValid(victim) or victim:GetTeam() ~= currentMode._balanceReviveTeam then return end

    -- Consume the single revive
    currentMode._balanceReviveTeam = nil

    local skin = (currentMode.id == "knife_round") and victim.kr_skin or nil

    victim:Revive(3, function(p)
        if not IsValid(p) then return end
        if skin then
            p:StripAll()
            p:Give(skin)
            if IsValid(p:GetWeapon(skin)) then p:SelectWeapon(skin) end
        end
    end, nil, false, REVIVAL_BLOCK_ALL)

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            ply:PrintMessage(HUD_PRINTTALK,
                "[TDM] Teams were uneven - " .. victim:Nick() .. " has been granted a revive!")
        end
    end
end)

-- OAZ kill refund: +1 bullet to zombie pistol clip on each kill
hook.Add("PlayerDeath", "sc0b_OAZKillRefund", function(victim, inflictor, attacker)
    if not currentMode or currentMode.id ~= "oops_all_zombies" then return end
    if not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim then return end
    local wep = attacker:GetWeapon("weapon_ttth_zombpistol")
    if not IsValid(wep) then return end
    local newClip = math.min(wep:Clip1() + 1, wep.Primary.ClipMax or 35)
    wep:SetClip1(newClip)
    attacker:PrintMessage(HUD_PRINTTALK, "[OAZ] Kill refund: +1 bullet (" .. newClip .. "/" .. (wep.Primary.ClipMax or 35) .. ")")
end)

-- ─────────────────────────────────────────────
-- Plant and Defuse: ttt_c4_pd explosion means planters win (ttt_c4_pd:Explode fires the hook)
hook.Add("TTTC4Explode", "sc0b_PlantAndDefuseNoExplode", function(bomb)
    if not currentMode or currentMode.id ~= "plant_and_defuse" then return end
    if bomb:GetClass() ~= "ttt_c4_pd" then return end
    if SERVER and currentMode._defusePhaseStarted then
        currentMode._planterWin = true
    end
    return false
end)

-- Prevent planters from manually arming during the plant phase (server arms at T+30)
hook.Add("TTTC4Arm", "sc0b_PlantDefuseBlockManualArm", function(bomb, ply)
    if not currentMode or currentMode.id ~= "plant_and_defuse" then return end
    if not currentMode._defusePhaseStarted then
        return false, "c4_armed" -- suppress arm; bomb arms automatically
    end
end)

-- Plant and Defuse: custom win condition
hook.Add("TTTCheckForWin", "sc0b_PlantAndDefuseWin", function()
    if not currentMode or currentMode.id ~= "plant_and_defuse" then return end

    -- Explicit win flags (set by TTTC4Explode or 0-bomb plant phase)
    if currentMode._planterWin then return TEAM_PLANTER end
    if currentMode._defuserWin then return TEAM_DEFUSER end

    -- Plant phase still active - hold the round open
    if not currentMode._defusePhaseStarted then return WIN_NONE end

    -- If all defusers are dead, planters win (nobody left to defuse)
    local defuserAlive = false
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and not ply:IsSpec()
            and TEAM_DEFUSER and ply:GetTeam() == TEAM_DEFUSER
        then
            defuserAlive = true
            break
        end
    end
    if not defuserAlive then
        currentMode._planterWin = true
        return TEAM_PLANTER
    end

    -- Count currently armed ttt_c4_pd bombs
    local armedCount = 0
    for _, ent in ipairs(ents.FindByClass("ttt_c4_pd")) do
        if IsValid(ent) and ent:GetArmed() then
            local etime = ent:GetExplodeTime()
            if etime ~= 0 and etime < CurTime() then
                currentMode._planterWin = true
                return TEAM_PLANTER
            end
            armedCount = armedCount + 1
        end
    end

    -- All bombs defused
    if armedCount == 0 and currentMode._bombsArmed > 0 then
        return TEAM_DEFUSER
    end

    return WIN_NONE
end)

-- ─────────────────────────────────────────────
-- Admin-only messaging
-- ─────────────────────────────────────────────
local function notifyAdmins(msg)
    print(msg)
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsSuperAdmin() then
            ply:PrintMessage(HUD_PRINTTALK, "[ADMIN ONLY] " .. msg)
        end
    end
end

concommand.Add("sc0b_force_special", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        adminMsg(ply, "[SPECIAL ROUNDS] Superadmin required.")
        return
    end

    local arg = args[1] or ""

    if arg == "" or arg == "list" then
        local parts = {}
        for _, m in ipairs(SPECIAL_MODES) do
            table.insert(parts, m.id .. " (" .. m.name .. ", " .. m.rarity .. ")")
        end
        notifyAdmins("[SPECIAL ROUNDS] Modes: " .. table.concat(parts, ", "))
        if forcedMode then
            notifyAdmins("[SPECIAL ROUNDS] Currently queued: " .. forcedMode.name)
        end
        return
    end

    if arg == "clear" or arg == "none" then
        forcedMode = nil
        notifyAdmins("[SPECIAL ROUNDS] Forced mode cleared.")
        return
    end

    local found
    for _, m in ipairs(SPECIAL_MODES) do
        if m.id == arg then found = m; break end
    end

    if not found then
        notifyAdmins("[SPECIAL ROUNDS] Unknown mode '" .. arg .. "'. Use sc0b_force_special list.")
        return
    end

    forcedMode = found
    notifyAdmins("[SPECIAL ROUNDS] Next round forced to " .. found.name .. " by " .. (IsValid(ply) and ply:Nick() or "console"))
end)

-- ─────────────────────────────────────────────
-- Prep phase: roll and tease
-- ─────────────────────────────────────────────
local PREP_HINTS_BY_MODE = {
    tiny = {
        "Someone left the terrorists in the dryer too long.",
        "Fun-sized round. Unfun-sized consequences.",
        "Big problems. Little terrorists.",
        "Duck. No, literally - you are the duck now.",
        "Watch your step.",
    },
    speed = {
        "We've upgraded the terrorists to sport mode.",
        "Try not to run into a wall. You will.",
        "The detective's running shoes have finally paid off.",
        "Things are about to get fast. Dangerously fast.",
        "The traitor booked it before you could.",
    },
    bhop = {
        "Space bar. That's the hint.",
        "The terrorists have discovered pogo sticks.",
        "Floor is not lava. But you should act like it.",
        "The rhythm is everything this round.",
        "Momentum is now your responsibility.",
    },
    superman = {
        "Someone left the traitor supply closet unlocked.",
        "The union negotiated better benefits. Effective immediately.",
        "Perks have been distributed. Equally. (Sure.)",
        "Everyone packed extra this round.",
        "The quartermaster is not asking questions today.",
    },
    screw_jump = {
        "Gravity is a suggestion. Seven of them.",
        "The map is taller than you think.",
        "Who needs stairs.",
        "Air superiority has never been more accessible.",
        "The roof is just another floor.",
    },
    chaos = {
        "Someone's been selling equipment to both sides.",
        "The armory declared itself neutral ground.",
        "Shop's open. No ID required.",
        "The traitors have competition this round.",
        "Everyone is equally dangerous. Especially you.",
    },
    low_grav = {
        "The facility's gravity generator is under maintenance.",
        "Please secure all loose items.",
        "What goes up is now everyone's problem.",
        "HVAC has been repurposed.",
        "Footwear with grip is recommended.",
    },
    slow_mo = {
        "This round is brought to you in cinematic mode.",
        "Time is running out. Slowly.",
        "Take your time. You'll have to.",
        "Bullet time is not a metaphor this round.",
        "The server has entered a contemplative state.",
    },
    exploding_props = {
        "Touch nothing.",
        "The maintenance crew left some things unattended.",
        "The furniture has taken a stance.",
        "Hazmat is on the way. Eventually.",
        "The environment is feeling reactive today.",
    },
    oops_all_zombies = {
        "A vaccination was not provided.",
        "The infection memo was not optional.",
        "Braaaains. Also: Deagles.",
        "Last one groaning wins.",
        "Good news: you're all the same. Bad news: you're all the same.",
    },
    knife_round = {
        "The armory ran out of guns. They found something else.",
        "Gun check. Knife check. Good luck.",
        "Close quarters have been enforced.",
        "The quartermaster made a very specific purchase.",
        "No ammo needed where you're going.",
    },
    crowbar_ffa = {
        "The armory is closed. The maintenance closet is open.",
        "Every person for themselves! And the tool is a crowbar.",
        "Gordon Freeman would feel right at home.",
        "No teams. No guns. Just leverage.",
        "The last one swinging wins.",
    },
    plant_and_defuse = {
        "The C4 has been checked out. Please return it promptly.",
        "Some players have been issued packages. Others will receive nothing.",
        "The armory has a very specific request this round.",
        "Plant. Run. Hope they can't find it.",
        "Somewhere on this map, a countdown has begun.",
    },
}

local PREP_HINTS = {
    -- Ominous / vague
    "Something special is brewing...",
    "The air feels different this round.",
    "Something is rumbling beneath the surface.",
    "An unusual energy fills the room.",
    "This round feels... different.",
    "Something wicked this way comes.",
    "The laws of nature seem unstable.",
    "Forces beyond comprehension stir.",
    "The server has a funny feeling about this one.",
    "Reality is looking a little... wobbly.",
    "The cosmos are misaligned. Proceed with caution.",
    "A disturbance has been detected. Source: unknown.",
    "Something in the walls is breathing.",
    "The traitors are not the only thing to fear this round.",
    "Fate has shuffled the deck.",
    "An anomaly has been detected. Investigating...",
    "The usual rules may not apply.",
    "Trust nothing. Not even gravity.",
    "This round has been flagged as irregular.",
    "A strange signal was intercepted before the round began.",
    "The detective's notes read: 'something is wrong.'",
    "Even the innocent are suspicious this round.",
    "The map looks the same. It is not.",
    "A prophecy was spoken. It was vague and concerning.",
    "Management has been notified. Management does not care.",
    "The briefing has been redacted.",
    "Proceed as normal. (You cannot proceed as normal.)",
    "All systems nominal. (They are not nominal.)",
    "This round has been marked for review.",
    "Something has changed. You will figure it out.",
    "The last person who asked questions did not survive.",
    "Reading the fine print would have helped.",
    "An unseen force has taken an interest in this round.",
    "A coin was flipped. It landed on its edge.",
    "The universe rolled a die. You won't like the result.",
    "Conditions are... suboptimal.",
    "The pre-round inspection revealed several concerns.",
    "Your horoscope today: avoid open spaces.",
    "A meteorologist would not enjoy this round.",
    "Scientists have no comment at this time.",
}

hook.Add("TTTPrepareRound", "sc0b_SpecialRoundPrep", function()
    currentMode     = nil
    pendingMode     = nil
    lastRoundModeID = nil
    roundCount  = roundCount + 1

    -- Safety: clear any leftover plant_and_defuse blind from a previous round
    net.Start("sc0b_PlantDefuseBlind")
        net.WriteBool(false)
    net.Broadcast()

    -- Safety: restore global effects in case last round's cleanup was missed
    if GetConVar("sv_gravity"):GetInt() ~= 285 then
        game.ConsoleCommand("sv_gravity 285\n")
    end
    game.SetTimeScale(1)
    RunConsoleCommand("ttt_inno_shop_fallback", "DISABLED")

    local base = GetConVar("special_round_pct"):GetInt()
    if currentPct == nil then currentPct = LoadPct() or base end

    if forcedMode then
        pendingMode    = forcedMode
        forcedMode     = nil
        currentPct     = base
        lastWasSpecial = true
        SavePct()
        notifyAdmins("[SPECIAL ROUNDS] Forced: " .. pendingMode.name .. " - chance reset to " .. base .. "%")
    else
        if base > 0 and math.random(100) <= currentPct then
            pendingMode = PickRandomMode()
            if not pendingMode then
                -- No eligible modes (e.g. player count too low for all min_players modes)
                currentPct = math.min(currentPct + base, 100)
                lastWasSpecial = false
                SavePct()
                return
            end
            notifyAdmins("[SPECIAL ROUNDS] Rolled at " .. currentPct .. "%: " .. pendingMode.name .. " - resetting to " .. base .. "%")
            currentPct     = base
            lastWasSpecial = true
            SavePct()
        else
            if lastWasSpecial then
                notifyAdmins("[SPECIAL ROUNDS] Last round was special - chance reset to " .. currentPct .. "%")
            elseif roundCount % 2 == 0 then
                notifyAdmins("[SPECIAL ROUNDS] Current special round chance: " .. currentPct .. "%")
            end
            currentPct     = math.min(currentPct + base, 100)
            lastWasSpecial = false
            SavePct()
            return
        end
    end

    -- Prep-phase hint: mode-specific if available, generic otherwise
    local hintPool = (pendingMode and PREP_HINTS_BY_MODE[pendingMode.id]) or PREP_HINTS
    local hint = hintPool[math.random(#hintPool)]
    for _, ply in ipairs(player.GetAll()) do
        ply:PrintMessage(HUD_PRINTTALK, "[GREATSEA] " .. hint)
    end
end)

-- ─────────────────────────────────────────────
-- Exploding Props helper (defined here so TTTBeginRound can call it)
-- ─────────────────────────────────────────────
local EXPLOSIVE_PROP_CLASSES = {
    ["prop_physics"]             = true,
    ["prop_physics_multiplayer"] = true,
    ["prop_physics_override"]    = true,
    ["func_physbox"]             = true,
}

local function MakePropExplosive(ent)
    if not IsValid(ent) then return end
    if not EXPLOSIVE_PROP_CLASSES[ent:GetClass()] then return end
    ent:SetHealth(100)
    ent:SetKeyValue("ExplodeDamage", "200")
    ent:SetKeyValue("ExplodeRadius", "250")
    ent:SetKeyValue("physdamagescale", "1.0")
    -- Ensure the prop can be damaged by bullets/explosions (not just physics)
    ent:SetKeyValue("nodamageforces", "0")
end

-- ─────────────────────────────────────────────
-- Round start: apply mode and announce
-- ─────────────────────────────────────────────
hook.Add("TTTBeginRound", "sc0b_SpecialRoundBegin", function()
    -- Guard: restore karma if a previous FFA round crashed without cleanup
    local karmaCV = GetConVar("ttt_karma")
    if karmaCV and karmaCV:GetInt() == 0 then
        RunConsoleCommand("ttt_karma", "1")
    end

    -- Promote pending → current now that the round is actually active
    currentMode = pendingMode
    pendingMode = nil

    if not currentMode then return end

    -- Global effects (not per-player)
    if currentMode.id == "low_grav" then
        currentMode._origGrav = GetConVar("sv_gravity"):GetInt()
        game.ConsoleCommand("sv_gravity 75\n")
    elseif currentMode.id == "double_time" then
        game.SetTimeScale(1.5)
    elseif currentMode.id == "slow_mo" then
        game.SetTimeScale(0.5)
    elseif currentMode.id == "exploding_props" then
        for class in pairs(EXPLOSIVE_PROP_CLASSES) do
            for _, ent in ipairs(ents.FindByClass(class)) do
                MakePropExplosive(ent)
            end
        end
    elseif currentMode.id == "oops_all_zombies" then
        currentMode._origKarma = GetConVar("ttt_karma"):GetInt()
        RunConsoleCommand("ttt_karma", "0")
        -- PlayerSpawn fires before TTTBeginRound (during SpawnPlayers in gameloop.Begin),
        -- so pointshop perma guns are already in players' inventories by now.
        -- Strip everything and give only the zombie pistol.
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() and not ply:IsSpec() then
                ply:StripAll()
                ply:GiveEquipmentWeapon("weapon_ttth_zombpistol")
            end
        end
        -- Passive ammo regen: +1 bullet to clip every 90 seconds
        timer.Create("sc0b_OAZAmmoRegen", 90, 0, function()
            if not currentMode or currentMode.id ~= "oops_all_zombies" then
                timer.Remove("sc0b_OAZAmmoRegen")
                return
            end
            for _, ply in ipairs(player.GetAll()) do
                if not IsValid(ply) or not ply:Alive() or ply:IsSpec() then continue end
                local wep = ply:GetWeapon("weapon_ttth_zombpistol")
                if not IsValid(wep) then continue end
                local newClip = math.min(wep:Clip1() + 1, wep.Primary.ClipMax or 35)
                wep:SetClip1(newClip)
                ply:PrintMessage(HUD_PRINTTALK, "[OAZ] Ammo regen: +" .. 1 .. " bullet (" .. newClip .. "/" .. (wep.Primary.ClipMax or 35) .. ")")
            end
        end)
    elseif currentMode.id == "knife_round" then
        -- Remove every world weapon before giving knives so players can't grab a gun
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and ent:IsWeapon() then
                local owner = ent:GetOwner()
                if not IsValid(owner) or not owner:IsPlayer() then
                    ent:Remove()
                end
            end
        end

        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() and not ply:IsSpec() then
                ply:StripAll()
                local skin = KNIFE_SKINS[math.random(#KNIFE_SKINS)]
                ply.kr_skin = skin
                ply:Give(skin)
                local wep = ply:GetWeapon(skin)
                if IsValid(wep) then ply:SelectWeapon(skin) end
            end
        end
        -- PS2 perma-weapons re-arm via OnRoundSet -> timer.Simple(0) -> timer.Simple(0.01).
        -- Strip everything except the assigned knife once those timers have fired.
        timer.Simple(0.5, function()
            if not currentMode or currentMode.id ~= "knife_round" then return end
            for _, ply in ipairs(player.GetAll()) do
                if not IsValid(ply) or not ply:Alive() or ply:IsSpec() then continue end
                local keep = ply.kr_skin
                for _, wep in ipairs(ply:GetWeapons()) do
                    if IsValid(wep) and wep:GetClass() ~= keep then
                        ply:StripWeapon(wep:GetClass())
                    end
                end
                -- Re-select the knife in case focus changed during the strip
                if keep and IsValid(ply:GetWeapon(keep)) then
                    ply:SelectWeapon(keep)
                end
            end
        end)
    elseif currentMode.id == "crowbar_ffa" then
        currentMode._origKarma = GetConVar("ttt_karma"):GetInt()
        RunConsoleCommand("ttt_karma", "0")
        -- Remove world weapons so no guns can be picked up
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and ent:IsWeapon() then
                local owner = ent:GetOwner()
                if not IsValid(owner) or not owner:IsPlayer() then
                    ent:Remove()
                end
            end
        end
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() and not ply:IsSpec() then
                ply:StripAll()
                ply:Give("weapon_zm_improvised")
                ply:SelectWeapon("weapon_zm_improvised")
                ply:GiveEquipmentItem(EQUIP_RADAR)
            end
        end
        -- Deferred strip: PS2 re-arms via OnRoundSet timers
        timer.Simple(0.5, function()
            if not currentMode or currentMode.id ~= "crowbar_ffa" then return end
            for _, ply in ipairs(player.GetAll()) do
                if not IsValid(ply) or not ply:Alive() or ply:IsSpec() then continue end
                for _, wep in ipairs(ply:GetWeapons()) do
                    if IsValid(wep) and wep:GetClass() ~= "weapon_zm_improvised" then
                        ply:StripWeapon(wep:GetClass())
                    end
                end
                if IsValid(ply:GetWeapon("weapon_zm_improvised")) then
                    ply:SelectWeapon("weapon_zm_improvised")
                end
            end
        end)
    elseif currentMode.id == "plant_and_defuse" then
        currentMode._origKarma   = GetConVar("ttt_karma"):GetInt()
        currentMode._planterWin  = false
        currentMode._defuserWin  = false
        currentMode._defusePhaseStarted = false
        currentMode._bombsArmed  = 0

        -- Read TTT2's actual phase end time so the fuse matches the real round clock
        currentMode._roundEndTime = gameloop.GetPhaseEnd()

        RunConsoleCommand("ttt_karma", "0")

        -- Remove world weapons so no guns can be grabbed
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and ent:IsWeapon() then
                local owner = ent:GetOwner()
                if not IsValid(owner) or not owner:IsPlayer() then
                    ent:Remove()
                end
            end
        end

        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) or not ply:Alive() or ply:IsSpec() then continue end

            if ply:GetTeam() == TEAM_PLANTER then
                ply:StripAll()
                ply:Give("weapon_ttt_c4")
            else
                -- Defuser: freeze and blind for the plant phase
                ply:StripAll()
                ply:Freeze(true)
            end
        end

        -- Blind defusers only
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() and not ply:IsSpec() and ply:GetTeam() == TEAM_DEFUSER then
                net.Start("sc0b_PlantDefuseBlind")
                    net.WriteBool(true)
                net.Send(ply)
            end
        end

        -- Deferred strip: block PS2 perma-weapons re-arming
        timer.Simple(0.5, function()
            if not currentMode or currentMode.id ~= "plant_and_defuse" then return end
            for _, ply in ipairs(player.GetAll()) do
                if not IsValid(ply) or not ply:Alive() or ply:IsSpec() then continue end
                if ply:GetTeam() == TEAM_PLANTER then
                    for _, wep in ipairs(ply:GetWeapons()) do
                        if IsValid(wep) and wep:GetClass() ~= "weapon_ttt_c4" then
                            ply:StripWeapon(wep:GetClass())
                        end
                    end
                else
                    ply:StripAll()
                end
            end
        end)

        -- Plant phase ends after 30 seconds: arm all placed C4s, release defusers
        timer.Create("sc0b_PlantPhaseEnd", 30, 1, function()
            if not currentMode or currentMode.id ~= "plant_and_defuse" then return end

            -- Strip C4 from planters and give them a pistol for the fight
            for _, ply in ipairs(player.GetAll()) do
                if not IsValid(ply) or not ply:Alive() or ply:IsSpec() then continue end
                if ply:GetTeam() == TEAM_PLANTER then
                    ply:StripWeapon("weapon_ttt_c4")
                    ply:Give("weapon_ttt_pistol")
                    ply:SelectWeapon("weapon_ttt_pistol")
                end
            end

            -- Swap each placed ttt_c4 for ttt_c4_pd and arm it with remaining round time.
            -- ttt_c4_pd:Arm always makes all wires safe and has no beep or explosion effects.
            local armTime    = math.max(10, math.floor(currentMode._roundEndTime - CurTime() - 1))
            local bombsArmed = 0
            local c4List     = ents.FindByClass("ttt_c4")
            print("[sc0b PlantDefuse] T+30 swap: found " .. #c4List .. " ttt_c4 entities, armTime=" .. armTime)

            for _, ent in ipairs(c4List) do
                if not IsValid(ent) then continue end

                local pos      = ent:GetPos()
                local ang      = ent:GetAngles()
                -- GetOriginator is set at deploy time (ThrowEntity/StickEntity);
                -- GetThrower is only set during Arm, so it's nil on an unarmed entity.
                local originator = ent:GetOriginator()
                ent:Remove()

                local pd = ents.Create("ttt_c4_pd")
                if not IsValid(pd) then
                    print("[sc0b PlantDefuse] WARNING: ents.Create(ttt_c4_pd) failed")
                    continue
                end

                pd:SetPos(pos)
                pd:SetAngles(ang)
                pd:Spawn()
                pd:Activate()

                -- Pass originator only if valid player; Arm handles nil gracefully
                local owner = (IsValid(originator) and originator:IsPlayer()) and originator or nil
                pd:Arm(owner, armTime)
                bombsArmed = bombsArmed + 1
            end

            print("[sc0b PlantDefuse] T+30 swap: " .. bombsArmed .. " ttt_c4_pd armed")

            currentMode._bombsArmed          = bombsArmed
            currentMode._defusePhaseStarted  = true

            -- Unfreeze and arm defusers
            for _, ply in ipairs(player.GetAll()) do
                if not IsValid(ply) or not ply:Alive() or ply:IsSpec() then continue end
                if ply:GetTeam() == TEAM_DEFUSER then
                    ply:Freeze(false)
                    ply:Give("weapon_ttt_pistol")
                    ply:SelectWeapon("weapon_ttt_pistol")
                end
            end

            -- Remove blind overlay
            net.Start("sc0b_PlantDefuseBlind")
                net.WriteBool(false)
            net.Broadcast()

            -- Announce
            local msg = bombsArmed > 0
                and ("[GREATSEA] GO! Defuse " .. bombsArmed .. " bomb" .. (bombsArmed == 1 and "" or "s") .. "!")
                or  "[GREATSEA] No bombs were planted - defusers win!"

            for _, ply in ipairs(player.GetAll()) do
                ply:PrintMessage(HUD_PRINTTALK, msg)
            end

            if bombsArmed == 0 then
                currentMode._defuserWin = true
            end
        end)
    end

    -- Apply per-player effects
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and not ply:IsSpec() then
            ApplyMode(ply, currentMode)
        end
    end


    -- TDM balance revive: mark the smaller team if counts are uneven by 1
    if TDM_MODES[currentMode.id] then
        local redCount, blueCount = 0, 0
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() and not ply:IsSpec() then
                local t = ply:GetTeam()
                if t == TEAM_REDTEAM then
                    redCount = redCount + 1
                elseif t == TEAM_BLUETEAM then
                    blueCount = blueCount + 1
                end
            end
        end
        if redCount ~= blueCount then
            currentMode._balanceReviveTeam = (redCount < blueCount) and TEAM_REDTEAM or TEAM_BLUETEAM
        end
    end

    -- Chat announcement
    for _, ply in ipairs(player.GetAll()) do
        ply:PrintMessage(HUD_PRINTTALK, "[GREATSEA] Special Round: " .. currentMode.name .. "!")
    end

    -- Client HUD notification
    net.Start("sc0b_SpecialRoundType")
        net.WriteString(currentMode.id)
        net.WriteString(currentMode.name)
    net.Broadcast()

    -- Update the rounds row - deferred so sv_log_rounds.lua's INSERT runs first
    timer.Simple(0, function()
        local round_id = GetGlobalInt("sc0b_currentRoundID", 0)
        if round_id == 0 then return end
        sql.Query(string.format(
            "UPDATE rounds SET round_type = '%s' WHERE round_id = %d",
            currentMode.id, round_id
        ))
        -- Tank: correct any jester/marker rows that were forced to innocent
        if currentMode.id == "tank" then
            sql.Query(string.format([[
                UPDATE round_players
                SET role = 'innocent', team = 'innocents', starting_role = 'innocent'
                WHERE round_id = %d AND (role = 'jester' OR role = 'marker')
            ]], round_id))
        end
        notifyAdmins("[SPECIAL ROUNDS] Round " .. round_id .. " set to: " .. currentMode.id)
    end)
end)

-- ─────────────────────────────────────────────
-- Round end - restore all players
-- ─────────────────────────────────────────────
hook.Add("TTTEndRound", "sc0b_SpecialRoundEnd", function()
    -- Capture before clearing so music server can read it regardless of hook order
    lastRoundModeID = currentMode and currentMode.id or nil

    if currentMode then
        -- Restore global effects
        if currentMode.id == "low_grav" then
            game.ConsoleCommand("sv_gravity " .. (currentMode._origGrav or 285) .. "\n")
        elseif currentMode.id == "double_time" or currentMode.id == "slow_mo" then
            game.SetTimeScale(1)
        elseif currentMode.id == "oops_all_zombies" then
            timer.Remove("sc0b_OAZAmmoRegen")
            RunConsoleCommand("ttt_karma", tostring(currentMode._origKarma or 1))
        elseif currentMode.id == "crowbar_ffa" then
            RunConsoleCommand("ttt_karma", tostring(currentMode._origKarma or 1))
        elseif currentMode.id == "plant_and_defuse" then
            timer.Remove("sc0b_PlantPhaseEnd")
            RunConsoleCommand("ttt_karma", tostring(currentMode._origKarma or 1))
            -- Unfreeze any still-frozen defusers
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) then ply:Freeze(false) end
            end
            -- Clear client blindfold
            net.Start("sc0b_PlantDefuseBlind")
                net.WriteBool(false)
            net.Broadcast()
            -- Remove any remaining bombs (no cleanup explosion)
            for _, ent in ipairs(ents.FindByClass("ttt_c4")) do
                if IsValid(ent) then ent:Remove() end
            end
            for _, ent in ipairs(ents.FindByClass("ttt_c4_pd")) do
                if IsValid(ent) then ent:Remove() end
            end
        end

    end

    if currentMode then currentMode._balanceReviveTeam = nil end
    currentMode = nil
    pendingMode = nil

    for _, ply in ipairs(player.GetAll()) do
        ply.kr_skin = nil
        ClearMode(ply)
    end
end)

-- ─────────────────────────────────────────────
-- Exploding Props: give all prop_physics the same engine-level
-- explosive properties as an explosive barrel
-- ─────────────────────────────────────────────
-- Exploding Props: set explosive properties on newly spawned props
-- ─────────────────────────────────────────────
hook.Add("OnEntityCreated", "sc0b_ExplodingPropsInit", function(ent)
    if not currentMode or currentMode.id ~= "exploding_props" then return end
    timer.Simple(0, function()
        MakePropExplosive(ent)
    end)
end)

-- Weapon-only rounds: destroy any weapon entity that lands in the world.
-- Deferred one tick so the entity's owner is set before we check it.
hook.Add("OnEntityCreated", "sc0b_WeaponOnlyRoundRemoveWorldWeapons", function(ent)
    if not currentMode or not WEAPON_ONLY_MODES[currentMode.id] then return end
    if not IsValid(ent) or not ent:IsWeapon() then return end
    timer.Simple(0, function()
        if not IsValid(ent) then return end
        local owner = ent:GetOwner()
        if IsValid(owner) and owner:IsPlayer() then return end
        ent:Remove()
    end)
end)

-- ─────────────────────────────────────────────
-- Reapply to players who spawn mid-round
-- (e.g. late connects)
-- ─────────────────────────────────────────────
hook.Add("PlayerSpawn", "sc0b_SpecialRoundSpawn", function(ply)
    if not currentMode then return end
    if not IsValid(ply) or ply:IsSpec() then return end
    if GetRoundState() ~= ROUND_ACTIVE then return end

    timer.Simple(0.1, function()
        if IsValid(ply) and currentMode and GetRoundState() == ROUND_ACTIVE then
            ApplyMode(ply, currentMode)
        end
    end)
end)
