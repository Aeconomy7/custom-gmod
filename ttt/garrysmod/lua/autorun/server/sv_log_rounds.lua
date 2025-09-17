-- sv_roundlogger.lua
-- Create a server convar (defaults to 1 = logging enabled)
CreateConVar("sc0b_roundlogging", "1", FCVAR_ARCHIVE, "Enable round logging")
CreateConVar("sc0b_roundlogging_debug", "1", FCVAR_ARCHIVE, "Enable debug prints for round logging")


util.AddNetworkString("sc0b_SendStats")


-- Helper to check if logging is enabled
local function IsLoggingEnabled()
    return GetConVar("sc0b_roundlogging"):GetBool()
end

if SERVER then
    -- Create tables if not exist
    sql.Query([[
        CREATE TABLE IF NOT EXISTS rounds (
            round_id INTEGER PRIMARY KEY AUTOINCREMENT,
            map_name TEXT,
            start_time INTEGER,
            end_time INTEGER,
            winning_team TEXT,
            test_round BOOLEAN DEFAULT 0
        )
    ]])

    sql.Query([[
        CREATE TABLE IF NOT EXISTS round_players (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            round_id INTEGER,
            steamid TEXT,
            role TEXT,
            team TEXT
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


    -- Start of round
    hook.Add("TTTBeginRound", "sc0b_LogRoundStart", function()
        if not IsLoggingEnabled() then return end

        currentRoundID = sql.QueryValue("SELECT last_insert_rowid()") or 0

        if GetConVar("sc0b_roundlogging_debug"):GetBool() then
            print("[ROUND LOGGER START ROUND]")
            print(string.format([[
                INSERT INTO rounds (map_name, start_time) VALUES ('%s', %d)
            ]], game.GetMap(), os.time()))

            -- currentRoundID = sql.QueryValue("SELECT last_insert_rowid()")
            print("[/ROUND LOGGER START ROUND]")
        end

        print("[ROUND LOGGER] Starting new round on map:", game.GetMap())
        local result = sql.Query(string.format([[
            INSERT INTO rounds (map_name, start_time) VALUES ('%s', %d)
        ]], game.GetMap(), os.time()))

        if result == false then
            print("[ROUND LOGGER] Insert failed:", sql.LastError())
        else
            currentRoundID = sql.QueryValue("SELECT last_insert_rowid()")
            SetGlobalInt("sc0b_currentRoundID", tonumber(currentRoundID) or 0)
            print("[ROUND LOGGER] Started round ID:", currentRoundID)
        end
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
            print(string.format([[
                UPDATE rounds
                SET end_time = %d, winning_team = '%s'
                WHERE round_id = %d
            ]], os.time(), result, currentRoundID))
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:SteamID64() then
                    local roleData = ply:GetSubRoleData()
                    local roleName = roleData and roleData.name or "unknown"
                    local roleTeam = roleData and roleData.defaultTeam or "unknown" -- gives ROLE_TEAM_*

                    print(string.format([[
                        INSERT INTO round_players (round_id, steamid, role, team)
                        VALUES (%d, '%s', '%s', '%s')
                    ]],
                    currentRoundID,
                    ply:SteamID64(),
                    roleName,
                    roleTeam))
                end
            end
            print("[/ROUND LOGGER END ROUND]")
        end

        print("[ROUND LOGGER] Ending round ID:", currentRoundID, "with result:", result)
        sql.Query(string.format([[
            UPDATE rounds
            SET end_time = %d, winning_team = '%s'
            WHERE round_id = %d
        ]], os.time(), result, tonumber(currentRoundID)))

        -- Record players + their roles
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:SteamID64() then
                local roleData = ply:GetSubRoleData()
                local roleName = roleData and roleData.name or "unknown"
                local roleTeam = roleData and roleData.defaultTeam or "unknown" -- gives ROLE_TEAM_*

                -- check for pirate captain special case
                if roleName == "pirate_captain" then
                    if IsValid(ply.pirate_master) then
                        roleTeam = ply.pirate_master:GetTeam() or "pirates"
                    end
                end

                print("[ROUND LOGGER] Logging player:", ply:Nick(), "as", roleName, "on team", roleTeam)
                sql.Query(string.format([[
                    INSERT INTO round_players (round_id, steamid, role, team)
                    VALUES (%d, '%s', '%s', '%s')
                ]],
                currentRoundID,
                ply:SteamID64(),
                roleName,
                roleTeam))
            end
        end
    end)


    hook.Add("TTT2PostPlayerDeath", "sc0b_LogKills", function(victim, inflictor, attacker)
        if not currentRoundID or not IsValid(victim) then return end

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

        

        local victimSteamID = "WORLD"
        local victimNick = "WORLD"
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
        local wasHeadshot = 0

        -- get weapon / dmg info
        if IsValid(inflictor) then
            if inflictor:IsWeapon() then
                -- Inflictor is the weapon
                weaponClass = inflictor:GetClass()
            elseif inflictor:IsPlayer() then
                -- Inflictor is a player, get their active weapon at time of kill
                local wep = inflictor:GetActiveWeapon()
                if IsValid(wep) then
                    weaponClass = wep:GetClass()
                else
                    weaponClass = "fists" -- fallback if player has no weapon
                end
            end
        else
            -- Try to infer cause of death from damage info
            local dmg = nil
            if victim.LastDamageInfo then
                dmg = victim:LastDamageInfo()
            end
            if GetConVar("sc0b_roundlogging_debug"):GetBool() then
                print("[ROUND LOGGER] Dmg info:", dmg)
            end
            if dmg then
                if (dmg:IsBulletDamage() or dmg:IsDamageType(DMG_CLUB)) then
                    if victim:LastHitGroup() == HITGROUP_HEAD then
                        wasHeadshot = 1
                    end
                end

                if dmg:IsFallDamage() then
                    weaponClass = "fall"
                elseif dmg:IsExplosionDamage() then
                    weaponClass = "explosion"
                elseif dmg:IsDamageType(DMG_DROWN) then
                    weaponClass = "drown"
                elseif dmg:IsDamageType(DMG_BURN) then
                    weaponClass = "fire"
                end
            else
                weaponClass = "world"
            end
        end

        -- local wasHeadshot = 0
        -- if victim:LastHitGroup() == HITGROUP_HEAD then
        --     wasHeadshot = 1
        -- end
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
end