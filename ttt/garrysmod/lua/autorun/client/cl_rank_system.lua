-- cl_rank_display.lua
if not CLIENT then return end

net.Receive("sc0b_SendXP", function()
    local xp = net.ReadInt(32)
    local level = net.ReadInt(16)

    LocalPlayer():SetNWInt("level", level)
    LocalPlayer():SetNWInt("xp", xp)
end)

-- Helper: rank icon based on level
local function GetRankIcon(level)
    if level >= 20 then return "🌟" end
    if level >= 10 then return "✨" end
    return "•"
end

-- Hook into TTT2 scoreboard player name
hook.Add("TTTScoreboardPlayerName", "sc0b_AddRankIcon", function(ply, label)
    local level = ply:GetNWInt("level", 1)
    return label .. " " .. GetRankIcon(level)
end)

-- Request XP on spawn
hook.Add("InitPostEntity", "sc0b_RequestXP", function()
    RunConsoleCommand("sc0b_request_xp")
end)
