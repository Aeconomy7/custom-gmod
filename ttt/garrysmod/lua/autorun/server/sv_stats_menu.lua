-- sv_stats.lua
util.AddNetworkString("sc0b_SendStats")

-- Helper: gather stats
local function GetPlayerStats(steamid64)
    local stats = {}
    stats.total = tonumber(sql.QueryValue("SELECT COUNT(*) FROM round_players WHERE steamid='" .. steamid64 .. "'")) or 0

    local roles = {"innocents", "traitors", "jesters", "markers", "serialkillers", "necromancers"}

    for _, role in ipairs(roles) do
        -- count how many times they played this role
        stats[role] = tonumber(sql.QueryValue([[
            SELECT COUNT(*) FROM round_players
            WHERE steamid=']] .. steamid64 .. [[' AND team=']] .. role .. [['
        ]])) or 0

        -- count wins when their team == winning team
        stats[role .. "_wins"] = tonumber(sql.QueryValue([[
            SELECT COUNT(*) 
            FROM round_players rp
            JOIN rounds r ON rp.round_id = r.round_id
            WHERE rp.steamid=']] .. steamid64 .. [['
            AND rp.team=']] .. role )) or 0
    end

    -- overall wins (any role, team match)
    -- SELECT COUNT(*) FROM rounds r JOIN round_players rp ON r.round_id = rp.round_id WHERE rp.steamid = '76561198077350528' AND r.winning_team = rp.team;
    stats.wins_total = tonumber(sql.QueryValue([[
        SELECT COUNT(*) 
        FROM rounds r 
        JOIN round_players rp ON r.round_id = rp.round_id
        WHERE rp.steamid=']] .. steamid64 .. [['
        AND rp.team = r.winning_team
    ]])) or 0

    stats.kills = tonumber(sql.QueryValue("SELECT COUNT(*) FROM round_kills WHERE killer_steamid='" .. steamid64 .. "'")) or 0
    stats.deaths = tonumber(sql.QueryValue("SELECT COUNT(*) FROM round_kills WHERE victim_steamid='" .. steamid64 .. "'")) or 0
    stats.killlog = sql.Query("SELECT * FROM round_kills WHERE killer_steamid='" .. steamid64 .. "' OR victim_steamid='" .. steamid64 .. "' ORDER BY time DESC LIMIT 20") or {}
 or 0

    return stats
end

-- Trigger from chat
hook.Add("PlayerSay", "sc0b_StatsCommand", function(ply, text)
    print("[STATS MENU] Sending stats to " .. ply:Nick())
    if string.lower(text) == "!mystats" then
        net.Start("sc0b_SendStats")
        net.WriteTable(GetPlayerStats(ply:SteamID64()))
        net.Send(ply)
        return ""
    end
end)

-- Trigger from console
concommand.Add("sc0b_mystats", function(ply)
    print("[STATS MENU] Sending stats to " .. ply:Nick())
    net.Start("sc0b_SendStats")
    net.WriteTable(GetPlayerStats(ply:SteamID64()))
    net.Send(ply)
end)