-- sv_roundlogger.lua
-- Create a server convar (defaults to 1 = logging enabled)
CreateConVar("sc0b_roundlogging", "1", FCVAR_ARCHIVE, "Enable round logging")
CreateConVar("sc0b_roundlogging_debug", "1", FCVAR_ARCHIVE, "Enable debug prints for round logging")


util.AddNetworkString("sc0b_SendStats")

local function GetLoggedRoleAndTeam(ply)
    if not IsValid(ply) then return "unknown", "unknown" end

    local roleData = ply:GetSubRoleData()
    local roleName = roleData and roleData.name or "unknown"
    local roleTeam = roleData and roleData.defaultTeam or "unknown"

    return roleName, roleTeam
end

-- Helper to check if logging is enabled
local function IsLoggingEnabled()
    return GetConVar("sc0b_roundlogging"):GetBool()
end

if SERVER then
    print("[ROUND LOGGER] Status:", IsLoggingEnabled() and "ENABLED" or "DISABLED")

    -- Create tables if not exist
    sql.Query([[
        CREATE TABLE IF NOT EXISTS rounds (
            round_id INTEGER PRIMARY KEY AUTOINCREMENT,
            map_name TEXT,
            start_time INTEGER,
            end_time INTEGER,
            winning_team TEXT,
            test_round BOOLEAN DEFAULT 0,
            world_damage_fall INTEGER DEFAULT 0,
            world_damage_prop INTEGER DEFAULT 0,
            world_damage_explosion INTEGER DEFAULT 0,
            world_damage_fire INTEGER DEFAULT 0,
            world_damage_drown INTEGER DEFAULT 0,
            world_damage_vehicle INTEGER DEFAULT 0,
            world_damage_world INTEGER DEFAULT 0
        )
    ]])

    sql.Query([[
        CREATE TABLE IF NOT EXISTS round_players (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            round_id INTEGER,
            steamid TEXT,
            role TEXT,
            team TEXT,
            starting_role TEXT,
            damage_dealt INTEGER DEFAULT 0
        )
    ]])

    sql.Query([[
        CREATE TABLE IF NOT EXISTS round_kills (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            round_id INTEGER,
            time INTEGER,
            killer_steamid TEXT,
            killer_nick TEXT,
            killer_role TEXT,
            killer_team TEXT,
            victim_steamid TEXT,
            victim_nick TEXT,
            victim_role TEXT,
            victim_team TEXT,
            weapon TEXT,
            headshot INTEGER DEFAULT 0
        )
    ]])


    local currentRoundID = nil
    local worldDamage = { fall = 0, prop = 0, explosion = 0, fire = 0, drown = 0, vehicle = 0, world = 0 }

    -- Start of round
    hook.Add("TTTBeginRound", "sc0b_LogRoundStart", function()
        if not IsLoggingEnabled() then return end

        print("[ROUND LOGGER START ROUND]")
        print("[ROUND LOGGER] Starting new round on map:", game.GetMap())

        print("[ROUND LOGGER] Zeroing out player damage...")
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                ply.sc0b_damage_dealt = 0
            end
        end

        print("[ROUND LOGGER] Zeroing out world damage...")
        worldDamage = { fall = 0, prop = 0, explosion = 0, fire = 0, drown = 0, vehicle = 0, world = 0 }

        -- Insert the round row
        local insertRes = sql.Query(string.format([[
            INSERT INTO rounds (map_name, start_time)
            VALUES ('%s', %d)
        ]], game.GetMap(), os.time()))

        if insertRes == false then
            print("[ROUND LOGGER] Insert failed:", sql.LastError())
            return
        end

        currentRoundID = sql.QueryValue("SELECT last_insert_rowid()")
        currentRoundID = tonumber(currentRoundID) or 0
        SetGlobalInt("sc0b_currentRoundID", currentRoundID)

        print("[ROUND LOGGER] Started round ID:", currentRoundID)

        -- Insert starting players (not spectators)
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:SteamID64() and not ply:IsSpec() then
                
                -- Reuse your helper (better conversion/team logic)
                local startRole, startTeam = GetLoggedRoleAndTeam(ply)

                -- Filter non-participants
                if startRole ~= "unknown" and startTeam ~= "unknown" then
                    if GetConVar("sc0b_roundlogging_debug"):GetBool() then
                        print(string.format(
                            "[ROUND LOGGER] Start Player: %s -> role=%s team=%s",
                            ply:Nick(), startRole, startTeam
                        ))
                    end

                    local query = string.format([[
                        INSERT INTO round_players (round_id, steamid, role, team, starting_role)
                        VALUES (%d, '%s', '%s', '%s', '%s')
                    ]], currentRoundID, ply:SteamID64(), startRole, startTeam, startRole)
                    print("[ROUND LOGGER] Query: " .. query)
                    sql.Query(query)
                end
            end
        end

        print("[/ROUND LOGGER START ROUND]")
    end)

    -- End of round
    hook.Add("TTTEndRound", "sc0b_LogRoundEnd", function(result)
        if not IsLoggingEnabled() or not currentRoundID then return end

        local result = result == TEAM_INNOCENT and "innocents"
                        or result == TEAM_TRAITOR and "traitors"
                        or result

        if result == 4 then result = "innocents" end
        

        if GetConVar("sc0b_roundlogging_debug"):GetBool() then
            print("[ROUND LOGGER END ROUND]")
            print(string.format("Round ended. Result: %s", result))
            
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:SteamID64() then
                    -- local roleData = ply:GetSubRoleData()
                    -- local roleName = roleData and roleData.name or "unknown"
                    -- local roleTeam = roleData and roleData.defaultTeam or "unknown" -- gives ROLE_TEAM_*

                    local roleName, roleTeam = GetLoggedRoleAndTeam(ply)
                    local damage = math.Round(ply.sc0b_damage_dealt or 0, 1)

                    local query = string.format([[
                        UPDATE round_players
                        SET role = '%s', team = '%s', damage_dealt = %d
                        WHERE round_id = %d AND steamid = '%s'
                    ]],
                    roleName, roleTeam, damage, currentRoundID, ply:SteamID64())
                    print("[ROUND LOGGER] Query: " .. query)
                    sql.Query(query)
                end
            end
        end

        print("[ROUND LOGGER] Ending round ID:", currentRoundID, "with result:", result)
        local query = string.format([[
            UPDATE rounds
            SET 
                end_time = %d, 
                winning_team = '%s', 
                world_damage_fall = %d, 
                world_damage_prop = %d, 
                world_damage_explosion = %d, 
                world_damage_fire = %d,
                world_damage_drown = %d,
                world_damage_vehicle = %d,
                world_damage_world = %d
            WHERE round_id = %d
        ]], os.time(), result, worldDamage.fall, worldDamage.prop, worldDamage.explosion, worldDamage.fire, worldDamage.drown, worldDamage.vehicle, worldDamage.world, tonumber(currentRoundID))
        print("[ROUND LOGGER] Query: " .. query)
        sql.Query(query)

        print("[/ROUND LOGGER END ROUND]")
    end)


    hook.Add("TTT2PostPlayerDeath", "sc0b_LogKills", function(victim, inflictor, attacker)
        if not currentRoundID or not IsValid(victim) then return end

        if not IsLoggingEnabled() then return end

        -- get killer info
        local killerSteamID = "world"
        local killerNick = "world"
        local killerRole = "unknown"
        local killerTeam = "unknown"
        if IsValid(attacker) and attacker:IsPlayer() and attacker.GetSubRoleData then
            killerSteamID = attacker:SteamID64()
            killerNick = attacker:Nick()
            local killerRoleData = attacker:GetSubRoleData()
            killerRole = killerRoleData and killerRoleData.name or "unknown"
            if killerRole == "pirate_captain" then
                if IsValid(attacker.pirate_master) then
                    killerTeam = attacker.pirate_master:GetTeam() or "pirates"
                else
                    killerTeam = "pirates"
                end
            else
                killerTeam = killerRoleData and killerRoleData.defaultTeam or "unknown"
            end
        end

        local victimSteamID = "world"
        local victimNick = "world"
        local victimRoleName = "unknown"
        local victimRoleTeam = "unknown"
        if IsValid(victim) and victim:IsPlayer() and victim.GetSubRoleData then
            victimSteamID = victim:SteamID64()
            victimNick = victim:Nick()
            local victimRoleData = victim:GetSubRoleData()
            victimRole = victimRoleData and victimRoleData.name or "unknown"
            if victimRole == "pirate_captain" then
                if IsValid(victim.pirate_master) then
                    victimTeam = victim.pirate_master:GetTeam() or "pirates"
                else
                    victimTeam = "pirates"
                end
            else
                victimTeam = victimRoleData and victimRoleData.defaultTeam or "unknown"
            end
        end

        local weaponClass = "world"

        if IsValid(inflictor) then
            if inflictor:IsWeapon() then
                weaponClass = inflictor:GetClass()
            elseif inflictor:IsPlayer() then
                local wep = inflictor:GetActiveWeapon()
                if IsValid(wep) then
                    weaponClass = wep:GetClass()
                else
                    weaponClass = "fists"
                end
            end
        else
            local dmg = victim.LastDamageInfo and victim:LastDamageInfo() or nil
            if GetConVar("sc0b_roundlogging_debug"):GetBool() then
                print("[ROUND LOGGER] Damage info:", dmg)
            end

            if dmg then
                if dmg:IsFallDamage() then
                    weaponClass = "fall"
                elseif dmg:IsExplosionDamage() then
                    weaponClass = "explosion"
                elseif dmg:IsDamageType(DMG_DROWN) then
                    weaponClass = "drown"
                elseif dmg:IsDamageType(DMG_BURN) or dmg:IsDamageType(DMG_SLOWBURN) then
                    weaponClass = "fire"
                elseif dmg:IsDamageType(DMG_CRUSH) then
                    weaponClass = "prop"
                elseif dmg:IsDamageType(DMG_VEHICLE) then
                    weaponClass = "vehicle"
                end
            end
        end

        local wasHeadshot = 0
        if victim:LastHitGroup() == HITGROUP_HEAD then
            wasHeadshot = 1
        end

        print("[ROUND LOGGER] Headshot:", wasHeadshot)

        if GetConVar("sc0b_roundlogging_debug"):GetBool() then
            print("[ROUND LOGGER KILL]")
            print(string.format([[
            INSERT INTO round_kills (round_id, time, killer_steamid, killer_nick, killer_role, killer_team, victim_steamid, victim_nick, victim_role, victim_team, weapon, headshot)
            VALUES (%d, %d, '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', %d)
            ]],
            currentRoundID,
            os.time(),
            killerSteamID,
            killerNick,
            killerRole,
            killerTeam,
            victimSteamID,
            victimNick,
            victimRole,
            victimTeam,
            weaponClass,
            wasHeadshot
            ))
            print("[/ROUND LOGGER KILL]")
        end

        -- Insert into database
        print("[ROUND LOGGER] Logging kill:", killerNick, "->", victimNick, "with", weaponClass)
        local query = string.format([[
            INSERT INTO round_kills (round_id, time, killer_steamid, killer_nick, killer_role, killer_team, victim_steamid, victim_nick, victim_role, victim_team, weapon, headshot)
            VALUES (%d, %d, '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', %d)
            ]],
            currentRoundID,
            os.time(),
            killerSteamID,
            killerNick,
            killerRole,
            killerTeam,
            victimSteamID,
            victimNick,
            victimRole,
            victimTeam,
            weaponClass,
            wasHeadshot
        )

        local result = sql.Query(query)
        if result == false then
            print("[ROUND LOGGER] Kill insert failed:", sql.LastError())
        end
    end)

    hook.Add("EntityTakeDamage", "sc0b_TrackDamageDealt", function(ent, dmginfo)
        if not IsLoggingEnabled() then return end
        if not currentRoundID then return end

        local attacker  = dmginfo:GetAttacker()
        local inflictor = dmginfo:GetInflictor()
        local dmg       = math.floor(math.min(dmginfo:GetDamage(), IsValid(ent) and ent:Health() or dmginfo:GetDamage()) + 0.5)

        if dmg <= 0 then return end

        -- ----------------------
        -- Player vs Player damage
        -- ----------------------
        if IsValid(ent) and ent:IsPlayer() and IsValid(attacker) and attacker:IsPlayer() and attacker ~= ent then
            attacker.sc0b_damage_dealt = (attacker.sc0b_damage_dealt or 0) + dmg

            if GetConVar("sc0b_roundlogging_debug"):GetBool() then
                print(string.format(
                    "[ROUND LOGGER] Damage: %s -> %s : +%d (total %d)",
                    attacker:Nick(),
                    ent:Nick(),
                    dmg,
                    attacker.sc0b_damage_dealt
                ))
            end

            return
        end

        -- ----------------------
        -- World / Environment damage
        -- ----------------------
        if IsValid(ent) and ent:IsPlayer() then
            -- Initialize worldDamage table if not exists
            worldDamage = worldDamage or {fall = 0, prop = 0, explosion = 0, fire = 0, drown = 0, vehicle = 0, world = 0}

            local cause

            if dmginfo:IsFallDamage() then
                cause = "fall"
            elseif dmginfo:IsExplosionDamage() then
                cause = "explosion"
            elseif dmginfo:IsDamageType(DMG_BURN) or dmginfo:IsDamageType(DMG_SLOWBURN) then
                cause = "fire"
            elseif dmginfo:IsDamageType(DMG_DROWN) then
                cause = "drown"
            elseif dmginfo:IsDamageType(DMG_VEHICLE) then
                cause = "vehicle"
            elseif IsValid(inflictor) and inflictor:GetClass():find("prop_") then
                cause = "prop"
            else
                cause = "world" -- fallback for any other environmental damage
            end

            if cause then
                worldDamage[cause] = (worldDamage[cause] or 0) + dmg

                if GetConVar("sc0b_roundlogging_debug"):GetBool() then
                    print(string.format(
                        "[ROUND LOGGER] World Damage: %s -> %s : +%d (total %s=%d)",
                        cause,
                        ent:Nick(),
                        dmg,
                        cause,
                        worldDamage[cause]
                    ))
                end
            end
        end
    end)
end