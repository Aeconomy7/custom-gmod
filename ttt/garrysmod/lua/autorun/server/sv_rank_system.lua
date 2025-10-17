-- sv_rank_system.lua
if not SERVER then return end

util.AddNetworkString("sc0b_SendXP")
util.AddNetworkString("sc0b_LevelUpPopup")
util.AddNetworkString("sc0b_LevelUpPNG")
util.AddNetworkString("sc0b_RoundXPGain")
-- Create SQLite table for XP
sql.Query([[
CREATE TABLE IF NOT EXISTS player_xp (
    steamid TEXT PRIMARY KEY,
    xp INTEGER DEFAULT 0,
    total_xp INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1
)
]])

-- XP needed for next level
local function XPRequiredForLevel(level)
    return 20 * level^2
end

local function GetLevelFromTotalXP(total_xp)
    local level = 1
    while total_xp >= XPRequiredForLevel(level) do
        total_xp = total_xp - XPRequiredForLevel(level)
        level = level + 1
    end
    return level, total_xp -- return level and XP into that level
end

-- Return: xp, level, total_xp
local function GetPlayerXP(ply)
    local steamid = ply:SteamID64()
    local row = sql.QueryRow(string.format("SELECT xp, total_xp, level FROM player_xp WHERE steamid = '%s'", steamid))
    if row then
        return tonumber(row.xp), tonumber(row.total_xp or 0), tonumber(row.level or 1)
    else
        sql.Query(string.format("INSERT INTO player_xp (steamid, xp, total_xp, level) VALUES ('%s', 0, 0, 1)", steamid))
        return 0, 0, 1
    end
end

local function AddXP(ply, amount)
    local currentXP, currentTotalXP, currentLevel = GetPlayerXP(ply)

    local newTotalXP = currentTotalXP + amount
    local newLevel, newXP = GetLevelFromTotalXP(newTotalXP)

    sql.Query(string.format(
        "INSERT INTO player_xp (steamid, xp, total_xp, level) VALUES ('%s', %d, %d, %d) " ..
        "ON CONFLICT(steamid) DO UPDATE SET xp=%d, level=%d, total_xp=%d",
        ply:SteamID64(), newXP, newTotalXP, newLevel, newXP, newLevel, newTotalXP
    ))

    ply:SetNWInt("level", newLevel)
    ply:SetNWInt("xp", newXP)
    ply:SetNWInt("total_xp", newTotalXP)

    if newLevel > currentLevel then
        ply:EmitSound("maplestory_level_up.mp3", 100, 100)
        for _, v in ipairs(player.GetAll()) do
            v:PrintMessage(HUD_PRINTTALK, "[GREATSEA] " .. ply:Nick() .. " reached level " .. newLevel .. "!")
        end

        -- Glowing effect for 2 seconds
        ply:SetRenderFX(kRenderFxGlowShell)
        ply:SetColor(Color(0, 255, 255))
        timer.Simple(7, function()
            if IsValid(ply) then
                ply:SetRenderFX(kRenderFxNone)
                ply:SetColor(Color(255,255,255)) -- Reset to normal
            end
        end)

        -- Popup for the player
        net.Start("sc0b_LevelUpPopup")
        net.WriteInt(newLevel, 16)
        net.Send(ply)

        net.Start("sc0b_LevelUpPNG")
        net.WriteEntity(ply)
        net.Send(player.GetAll())
    end
end

hook.Add("TTTEndRound", "sc0b_RankAwardXP", function(result)
    -- Get the current round ID and winning team
    local round_id = GetGlobalInt("sc0b_currentRoundID", 0)
    if round_id == 0 then return end

    -- Get the winning team from the DB
    local roundRow = sql.QueryRow("SELECT winning_team FROM rounds WHERE round_id = " .. round_id)
    local winning_team = roundRow and roundRow.winning_team or ""

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end

        local steamid = ply:SteamID64()
        local xpGain = 0
        local reasons = {}

        -- 1. Award 10 XP for each good kill
        local kills = sql.Query([[
            SELECT victim_role, killer_role
            FROM round_kills
            WHERE round_id = ]] .. round_id .. [[
            AND killer_steamid = ']] .. steamid .. [['
        ]]) or {}

        local goodKills = 0
        for _, kill in ipairs(kills) do
            -- Define "good" kill logic:
            -- Innocent/Detective kills Traitor, or Traitor kills Innocent/Detective
            if (kill.killer_role == "traitor" and (kill.victim_role == "innocent" or kill.victim_role == "detective")) or
               ((kill.killer_role == "innocent" or kill.killer_role == "detective") and kill.victim_role == "traitor") then
                goodKills = goodKills + 1
            end
        end
        if goodKills > 0 then
            local killXP = goodKills * 10
            xpGain = xpGain + killXP
            table.insert(reasons, "Good Kills: " .. killXP)
        end

        -- 2. Award 25 XP for being on the winning team
        local roleData = ply.GetSubRoleData and ply:GetSubRoleData()
        local playerTeam = roleData and roleData.defaultTeam or ""
        if playerTeam ~= "" and playerTeam == winning_team then
            xpGain = xpGain + 25
            table.insert(reasons, "Winning Team: 25")
        end

        -- 3. Award 10 XP for being alive at the end
        if ply:Alive() then
            xpGain = xpGain + 10
            table.insert(reasons, "Survived: 10")
        end

        -- Send breakdown to client
        net.Start("sc0b_RoundXPGain")
        net.WriteInt(xpGain, 16)
        net.WriteUInt(#reasons, 8)
        for _, reason in ipairs(reasons) do
            net.WriteString(reason)
        end
        net.Send(ply)

        AddXP(ply, xpGain)
    end
end)


concommand.Add("sc0b_request_xp", function(ply)
    local xp, total_xp, level  = GetPlayerXP(ply)
    net.Start("sc0b_SendXP")
    net.WriteInt(xp, 32)
    net.WriteInt(total_xp, 32)
    net.WriteInt(level, 16)
    net.Send(ply)
end)
