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
            killer_role TEXT,
            killer_team TEXT,
            victim_steamid TEXT,
            victim_role TEXT,
            victim_team TEXT,
            weapon TEXT
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

        local result = sql.Query(string.format([[
            INSERT INTO rounds (map_name, start_time) VALUES ('%s', %d)
        ]], game.GetMap(), os.time()))

        if result == false then
            print("[ROUND LOGGER] Insert failed:", sql.LastError())
        else
            currentRoundID = sql.QueryValue("SELECT last_insert_rowid()")
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
        -- Only log if we have a valid round
        if not currentRoundID or not IsValid(victim) then return end

        local killerSteamID = "WORLD"
        local killerRole = "unknown"
        local weaponClass = "unknown"

        local killerRoleData = attacker:GetSubRoleData()
        local killerRoleName = killerRoleData and killerRoleData.name or "unknown"
        local killerRoleTeam = killerRoleData and killerRoleData.defaultTeam or "unknown" -- gives ROLE_TEAM_*

        -- Determine killer and weapon
        if IsValid(attacker) and attacker:IsPlayer() then
            killerSteamID = attacker:SteamID64()
            killerRole = killerRoleName
            killerTeam = killerRoleTeam
        end

        local weaponClass = "unknown"

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
        end

        local victimRoleData = victim:GetSubRoleData()
        local victimRoleName = victimRoleData and victimRoleData.name or "unknown"
        local victimRoleTeam = victimRoleData and victimRoleData.defaultTeam or "unknown" -- gives ROLE_TEAM_*

        local victimSteamID = victim:SteamID64()
        local victimRole = victimRoleName
        local victimTeam = victimRoleTeam

        if GetConVar("sc0b_roundlogging_debug"):GetBool() then
            print("[ROUND LOGGER KILL]")
            print(string.format([[
            INSERT INTO round_kills (round_id, time, killer_steamid, killer_role, killer_team, victim_steamid, victim_role, victim_team, weapon)
            VALUES (%d, %d, '%s', '%s', '%s', '%s', '%s', '%s', '%s')
        ]],
        currentRoundID,
        os.time(),
        killerSteamID,
        killerRole,
        killerTeam,
        victimSteamID,
        victimRole,
        victimTeam,
        weaponClass
        ))
            print("[/ROUND LOGGER KILL]")
        end

        -- Insert into database
        local query = string.format([[
            INSERT INTO round_kills (round_id, time, killer_steamid, killer_role, killer_team, victim_steamid, victim_role, victim_team, weapon)
            VALUES (%d, %d, '%s', '%s', '%s', '%s', '%s', '%s', '%s')
        ]],
        currentRoundID,
        os.time(),
        killerSteamID,
        killerRole,
        killerTeam,
        victimSteamID,
        victimRole,
        victimTeam,
        weaponClass
        )

        local result = sql.Query(query)
        if result == false then
            print("[ROUND LOGGER] Kill insert failed:", sql.LastError())
        end
    end)
end