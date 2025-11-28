if not SERVER then return end

-- Register network strings on the server only
util.AddNetworkString("GS_RequestScoreboardData") -- client -> server request
util.AddNetworkString("GS_SendLevelTitle")        -- server -> client response

local function GS_GetPlayerData(steamid64)
    local xpRow = sql.QueryRow("SELECT level FROM player_xp WHERE steamid = '" .. steamid64 .. "';")
    local level = xpRow and tonumber(xpRow.level) or 1

    local titleRow = sql.QueryRow([[
        SELECT A.name, A.stat_type
        FROM player_achievements PA
        JOIN all_achievements A ON PA.internal_id = A.internal_id
        WHERE PA.steamid = ']] .. steamid64 .. [[' AND PA.equipped = 1 LIMIT 1;
    ]])

    local title, stat_type = "", "none"
    if titleRow then
        title = titleRow.name or ""
        stat_type = titleRow.stat_type or "none"
    end

    return level, title, stat_type
end

local function TransmitPlayerDataToClient(targetClient, ply)
    if not IsValid(targetClient) or not IsValid(ply) then return end

    local sid64 = ply:SteamID64()
    local level, title, stat_type = GS_GetPlayerData(sid64)

    net.Start("GS_SendLevelTitle")
        net.WriteString(sid64)
        net.WriteUInt(level, 16)
        net.WriteString(title)
        net.WriteString(stat_type)
    net.Send(targetClient)
end

-- When client asks for scoreboard data, respond with all players' info
net.Receive("GS_RequestScoreboardData", function(len, requester)
    if not IsValid(requester) then return end

    for _, ply in ipairs(player.GetAll()) do
        TransmitPlayerDataToClient(requester, ply)
    end
end)

-- Optional: auto-send updates when a player spawns (keeps client cache fresher)
hook.Add("PlayerSpawn", "GS_AutoPushOnSpawn", function(ply)
    -- Broadcast updated info about this player to everyone (or you can limit it)
    for _, cl in ipairs(player.GetAll()) do
        -- send to each connected client
        TransmitPlayerDataToClient(cl, ply)
    end
end)

-- Hook to push player data at the start of each round
hook.Add("TTTBeginRound", "GS_SendRoundPlayerData", function()
    for _, ply in ipairs(player.GetAll()) do
        -- send to all clients
        local sid64 = ply:SteamID64()
        local level, title, stat_type = GS_GetPlayerData(sid64)

        net.Start("GS_SendLevelTitle")
            net.WriteString(sid64)
            net.WriteUInt(level, 16)
            net.WriteString(title)
            net.WriteString(stat_type)
        net.Broadcast()
    end
end)
