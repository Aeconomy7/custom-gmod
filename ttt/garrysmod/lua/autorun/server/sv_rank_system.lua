-- sv_rank_system.lua
if not SERVER then return end

util.AddNetworkString("sc0b_LevelUpPopup")


-- Create SQLite table for XP
sql.Query([[
CREATE TABLE IF NOT EXISTS player_xp (
    steamid TEXT PRIMARY KEY,
    xp INTEGER DEFAULT 0,
    total_xp INTEGER DEFAULT 0,
    level INTEGER DEFAULT 1
)
]])

-- XP formula
local function XPToLevel(xp)
    local level = 1
    while xp >= 20 * level^2 do
        level = level + 1
    end
    return level
end

-- Return: xp, level, total_xp
local function GetPlayerXP(ply)
    local steamid = ply:SteamID64()
    local row = sql.QueryRow(string.format("SELECT xp, level, total_xp FROM player_xp WHERE steamid = '%s'", steamid))
    if row then
        return tonumber(row.xp), tonumber(row.level), tonumber(row.total_xp or 0)
    else
        sql.Query(string.format("INSERT INTO player_xp (steamid, xp, level, total_xp) VALUES ('%s', 0, 0, 1)", steamid))
        return 0, 1, 0
    end
end

local function AddXP(ply, amount)
    local currentXP, currentLevel, currentTotalXP = GetPlayerXP(ply)
    local newXP = currentXP + amount
    local newLevel = XPToLevel(newXP)
    local newTotalXP = currentTotalXP + amount

    sql.Query(string.format(
        "INSERT INTO player_xp (steamid, xp, level, total_xp) VALUES ('%s', %d, %d, %d) ON CONFLICT(steamid) DO UPDATE SET xp=%d, level=%d, total_xp=%d",
        ply:SteamID64(), newXP, newLevel, newTotalXP, newXP, newLevel, newTotalXP
    ))

    ply:SetNWInt("level", newLevel)
    ply:SetNWInt("xp", newXP)
    ply:SetNWInt("total_xp", newTotalXP)

    if newLevel > currentLevel then
        ply:EmitSound("maplestory_level_up.mp3", 100, 100)
        for _, v in ipairs(player.GetAll()) do
            v:ChatPrint("[LEVEL UP] " .. ply:Nick() .. " reached level " .. newLevel .. "!")
        end

        -- Popup for the player
        net.Start("sc0b_LevelUpPopup")
        net.WriteInt(newLevel, 16)
        net.Send(ply)
    end
end

-- Example: award XP at end of round
hook.Add("TTTEndRound", "sc0b_RankAwardXP", function(result)
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end

        local xpGain = 5 -- base XP
        -- Example bonuses
        if ply:IsTraitor() and ply:Alive() then xpGain = xpGain + 5 end
        if ply:IsDetective() and ply:Alive() then xpGain = xpGain + 5 end
        if ply:IsActiveTraitor() and result == "traitor" then xpGain = xpGain + 5 end
        if ply:IsActiveDetective() and result == "innocent" then xpGain = xpGain + 5 end

        AddXP(ply, xpGain)
    end
end)

-- Send XP/level to client when requested
util.AddNetworkString("sc0b_SendXP")
concommand.Add("sc0b_request_xp", function(ply)
    local xp, total_xp, level  = GetPlayerXP(ply)
    net.Start("sc0b_SendXP")
    net.WriteInt(xp, 32)
    net.WriteInt(total_xp, 32)
    net.WriteInt(level, 16)
    net.Send(ply)
end)
