-- cl_rank_display.lua
if not CLIENT then return end

surface.CreateFont("Impact18", {
    font = "Impact",
    size = 18,
    weight = 600,
    antialias = true,
    extended = true
})

net.Receive("sc0b_SendXP", function()
    local xp = net.ReadInt(32)
    local total_xp = net.ReadInt(32)
    local level = net.ReadInt(16)

    LocalPlayer():SetNWInt("level", level)
    LocalPlayer():SetNWInt("total_xp", total_xp)
    LocalPlayer():SetNWInt("xp", xp)
end)

-- Helper: rank icon based on level
local function GetRankIcon(level)
    if level >= 20 then return "🌟" end
    if level >= 10 then return "✨" end
    return "•"
end

--  client-side calculation
local function GetLevelXPBounds(level)
    local minXP = 20 * (level - 1)^2
    local maxXP = 20 * level^2
    return minXP, maxXP
end

local function GetLevelProgress(xp, level)
    local minXP, maxXP = GetLevelXPBounds(level)
    local progress = (xp - minXP) / (maxXP - minXP)
    return math.Clamp(progress, 0, 1)
end

net.Receive("sc0b_LevelUpPopup", function()
    local level = net.ReadInt(16)
    local expire = CurTime() + 3

    hook.Add("HUDPaint", "sc0b_LevelUpPopup", function()
        if CurTime() > expire then
            hook.Remove("HUDPaint", "sc0b_LevelUpPopup")
            return
        end
        local text1 = "Congratulations"
        local text2 = "You reached level " .. level .. "!"
        local font = "Impact18"
        surface.SetFont(font)
        local w1, h1 = surface.GetTextSize(text1)
        local w2, h2 = surface.GetTextSize(text2)
        local x = ScrW() / 2
        local y = ScrH() / 2 - 80
        draw.SimpleText(text1, font, x, y, Color(255, 220, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        draw.SimpleText(text2, font, x, y + h1 + 8, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end)
end)

-- Hook into TTT2 scoreboard player name
hook.Add("TTTScoreboardPlayerName", "sc0b_AddRankIcon", function(ply, label)
    local level = ply:GetNWInt("level", 1)
    return label .. " " .. GetRankIcon(level)
end)

-- Request XP on spawn
hook.Add("InitPostEntity", "sc0b_RequestXP", function()
    RunConsoleCommand("sc0b_request_xp")
end)
