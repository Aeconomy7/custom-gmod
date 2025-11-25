
-- cl_rank_display.lua
if not CLIENT then return end

local levelUpPopups = {}

surface.CreateFont("Impact48", {
    font = "Impact",
    size = 48,
    weight = 600,
    antialias = true,
    extended = true
})

surface.CreateFont("Impact36", {
    font = "Impact",
    size = 36,
    weight = 600,
    antialias = true,
    extended = true
})

surface.CreateFont("Impact18", {
    font = "Impact",
    size = 18,
    weight = 600,
    antialias = true,
    extended = true
})

-- ==============================
-- Networking
-- ==============================

net.Receive("sc0b_SendXP", function()
    local xp = net.ReadInt(32)
    local total_xp = net.ReadInt(32)
    local level = net.ReadInt(16)

    LocalPlayer():SetNWInt("level", level)
    LocalPlayer():SetNWInt("total_xp", total_xp)
    LocalPlayer():SetNWInt("xp", xp)
end)

-- ==============================
-- Rank material
-- ==============================

local rankCache = {}

local function GetRankMaterial(level)
    local idx
    if level == 1 then
        idx = 0
    else
        idx = math.floor((level - 1) / 2) * 2
    end

    local path = "ranks/rank" .. idx .. ".png"
    if not rankCache[path] then
        rankCache[path] = Material(path, "smooth")
    end
    return rankCache[path]
end

-- ==============================
-- Level math
-- ==============================

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

-- ==============================
-- Level up popups
-- ==============================

net.Receive("sc0b_LevelUpPopup", function()
    local level = net.ReadInt(16)
    local expire = CurTime() + 7

    hook.Add("HUDPaint", "sc0b_LevelUpPopup", function()
        if CurTime() > expire then
            hook.Remove("HUDPaint", "sc0b_LevelUpPopup")
            return
        end
        local text1 = "Congratulations"
        local text2 = "You reached level " .. level .. "!"
        local font = "Impact48"
        surface.SetFont(font)
        local w1, h1 = surface.GetTextSize(text1)
        local w2, h2 = surface.GetTextSize(text2)
        local x = ScrW() / 2
        local y = ScrH() / 2 - 200
        draw.SimpleText(text1, font, x, y, Color(255, 220, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        draw.SimpleText(text2, font, x, y + h1 + 8, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end)
end)

net.Receive("sc0b_LevelUpPNG", function()
    local ply = net.ReadEntity()
    if not IsValid(ply) then return end
    levelUpPopups[ply] = CurTime() + 7
end)

hook.Add("PostPlayerDraw", "sc0b_DrawLevelUpPNG", function(ply)
    local expire = levelUpPopups[ply]
    if not expire or CurTime() > expire then return end

    local mat = Material("level_up.png", "smooth")
    local pos = ply:GetPos() + Vector(0,0,85)

    cam.Start3D2D(pos, Angle(0, LocalPlayer():EyeAngles().y - 90, 90), 0.2)
        surface.SetMaterial(mat)
        surface.SetDrawColor(255,255,255,255)
        surface.DrawTexturedRect(-64, -64, 128, 128)
    cam.End3D2D()
end)

-- ==============================
-- Scoreboard hook
-- ==============================

hook.Add("TTTScoreboardPlayerName", "sc0b_AddRankIcon", function(ply, label)
    local level = ply:GetNWInt("level", 1)
    return label .. " [" .. level .. "]"
end)

-- ==============================
-- Request XP
-- ==============================

hook.Add("InitPostEntity", "sc0b_RequestXP", function()
    RunConsoleCommand("sc0b_request_xp")
end)

-- ==============================
-- Round XP gain -> Chat
-- ==============================

net.Receive("sc0b_RoundXPGain", function()
    local xp = net.ReadInt(16)
    local count = net.ReadUInt(8)
    local reasons = {}
    for i = 1, count do
        reasons[i] = net.ReadString()
    end

    if xp <= 0 then return end

    chat.AddText(
        Color(255,19,240), "[",
        Color(0,255,255), "GREAT",
        Color(255,220,0), "SEA",
        Color(255,19,240), "] ",
        Color(255,255,255), "You earned ",
        Color(0,255,255), xp .. " XP",
        Color(255,255,255), " this round!"
    )
    for _, reason in ipairs(reasons) do
        local amount = reason:match("([+-]?%d+)")
        local prefix = " - "
        if amount then
            amount = tonumber(amount)
            if amount > 0 then
                chat.AddText(
                    Color(255,255,255), prefix .. reason:gsub("([+-]?%d+)", ""),
                    Color(0,255,0), "+" .. amount
                )
            elseif amount < 0 then
                chat.AddText(
                    Color(255,255,255), prefix .. reason:gsub("([+-]?%d+)", ""),
                    Color(255,80,80), amount
                )
            else
                chat.AddText(Color(255,255,255), prefix .. reason)
            end
        else
            chat.AddText(Color(255,255,255), prefix .. reason)
        end
    end

end)