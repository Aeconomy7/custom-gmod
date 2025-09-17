-- sv_stats.lua
util.AddNetworkString("sc0b_SendStats")

-- Helper: gather stats
local function GetPlayerStats(steamid64)
    local stats = {}
    stats.total = tonumber(sql.QueryValue([[
            SELECT COUNT(*) 
            FROM rounds r
            JOIN round_players rp ON r.round_id = rp.round_id
            WHERE rp.steamid=']] .. steamid64 .. [[' AND r.test_round = 0
        ]])) or 0

    local roles = {"innocents", "traitors", "jesters", "markers", "serialkillers", "necromancers"}

    for _, role in ipairs(roles) do
        -- count how many times they played this role
        stats[role] = tonumber(sql.QueryValue([[
            SELECT COUNT(*) 
            FROM rounds r
            JOIN round_players rp ON r.round_id = rp.round_id
            WHERE rp.steamid=']] .. steamid64 .. [[' AND team=']] .. role .. [[' AND r.test_round = 0
        ]])) or 0

        -- count wins when their team == winning team
        stats[role .. "_wins"] = tonumber(sql.QueryValue([[
            SELECT COUNT(*) 
            FROM rounds r
            JOIN round_players rp ON r.round_id = rp.round_id
            WHERE rp.steamid=']] .. steamid64 .. [[' AND r.test_round = 0
            AND rp.team=']] .. role .. [[' AND rp.team = r.winning_team]])) or 0
    end

    -- overall wins (any role, team match)
    -- SELECT COUNT(*) FROM rounds r JOIN round_players rp ON r.round_id = rp.round_id WHERE rp.steamid = '76561198077350528' AND r.winning_team = rp.team;
    stats.wins_total = tonumber(sql.QueryValue([[
        SELECT COUNT(*) 
        FROM rounds r 
        JOIN round_players rp ON r.round_id = rp.round_id
        WHERE rp.steamid=']] .. steamid64 .. [[' AND r.test_round = 0
        AND rp.team = r.winning_team
    ]])) or 0

    -- stats.kills = tonumber(sql.QueryValue("SELECT COUNT(*) FROM round_kills WHERE killer_steamid='" .. steamid64 .. "'")) or 0
    -- stats.deaths = tonumber(sql.QueryValue("SELECT COUNT(*) FROM round_kills WHERE victim_steamid='" .. steamid64 .. "'")) or 0
    -- stats.killlog = sql.Query("SELECT time, killer_nick, killer_role, victim_nick, victim_role, weapon FROM round_kills WHERE killer_steamid='" .. steamid64 .. "' OR victim_steamid='" .. steamid64 .. "' ORDER BY time DESC LIMIT 20") or {}
    -- Count kills (excluding test rounds)
    stats.kills = tonumber(sql.QueryValue([[
        SELECT COUNT(*)
        FROM round_kills rk
        JOIN rounds r ON rk.round_id = r.round_id
        WHERE rk.killer_steamid = ']] .. steamid64 .. [['
        AND r.test_round = 0
        AND r.winning_team != ''
    ]]) ) or 0

    -- Count deaths (excluding test rounds)
    stats.deaths = tonumber(sql.QueryValue([[
        SELECT COUNT(*)
        FROM round_kills rk
        JOIN rounds r ON rk.round_id = r.round_id
        WHERE rk.victim_steamid = ']] .. steamid64 .. [['
        AND r.test_round = 0
        AND r.winning_team != ''
    ]]) ) or 0

    -- Kill log (last 20 entries, excluding test rounds)
    stats.killlog = sql.Query([[
        SELECT rk.time, rk.killer_nick, rk.killer_team, rk.killer_role, rk.victim_nick, rk.victim_team, rk.victim_role, rk.weapon
        FROM round_kills rk
        JOIN rounds r ON rk.round_id = r.round_id
        WHERE (rk.killer_steamid = ']] .. steamid64 .. [[' OR rk.victim_steamid = ']] .. steamid64 .. [[')
        AND r.test_round = 0
        AND r.winning_team != ''
        ORDER BY rk.time DESC
        LIMIT 20
    ]]) or {} 

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

-- to show round IT on HUD
hook.Add("HUDPaint", "sc0b_DrawRoundID", function()
    -- Only show if TTT2 round is active
    if not GAMEMODE or not GAMEMODE.round_state or GAMEMODE.round_state == ROUND_WAIT then return end

    local roundID = GetGlobalInt("sc0b_currentRoundID", 0)
    if roundID == 0 then return end

    -- Position: bottom left of the timer box (adjust as needed)
    local boxW, boxH = 180, 40
    local x, y = ScrW() / 2 - boxW / 2, 400 -- 60px from top, adjust for your HUD

    draw.SimpleTextOutlined(
        "Round ID: " .. roundID,
        "Trebuchet24",
        x + boxW / 2, y + boxH - 8,
        Color(255, 220, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM,
        2, Color(0,0,0,200)
    )
end)