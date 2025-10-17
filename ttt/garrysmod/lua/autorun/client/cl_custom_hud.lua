surface.CreateFont("Impact32", {
    font = "Impact",
    size = 32,
    weight = 600,
    antialias = true,
    extended = true
})

local speedColorStops = {
    [0]    = Color(255,   0,   0),   -- Red
    [214]  = Color(255, 140,   0),   -- Orange
    [428]  = Color(255, 255,   0),   -- Yellow
    [642]  = Color(0,   255,   0),   -- Green
    [857]  = Color(0,   200, 255),   -- Bright Cyan-Blue
    [1071] = Color(120,   0, 255),   -- Bright Indigo
    [1285] = Color(200,   0, 255),   -- Bright Violet
    [1500] = Color(255, 255, 255),   -- White
}

local function GetRainbowColor(speed)
    local lastSpeed, nextSpeed = 0, 4200
    for k, _ in SortedPairs(speedColorStops) do
        if speed >= k then
            lastSpeed = k
        elseif speed < k then
            nextSpeed = k
            break
        end
    end

    local frac = math.Clamp((speed - lastSpeed) / (nextSpeed - lastSpeed), 0, 1)
    local c1 = speedColorStops[lastSpeed] or color_white
    local c2 = speedColorStops[nextSpeed] or color_white

    return Color(
        Lerp(frac, c1.r, c2.r),
        Lerp(frac, c1.g, c2.g),
        Lerp(frac, c1.b, c2.b)
    )
end

hook.Add("HUDPaint", "DrawSc0bHud", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if not GAMEMODE or not GAMEMODE.round_state or GAMEMODE.round_state == ROUND_WAIT then return end

    local screenW, screenH = ScrW(), ScrH()
    local font = "Impact32"
    surface.SetFont(font)

    -- Prepare text for both lines
    local roundID  = GetGlobalInt("sc0b_currentRoundID", 0)
    local maxRounds = GetGlobalInt("sc0b_maxRounds", 6)
    local roundStr = (roundID > 0 and maxRounds > 0) and string.format("%d", roundID) or ""
    local roundPrefix = "Round: "

    local vel = ply:GetVelocity()
    local speed = math.sqrt(vel.x ^ 2 + vel.y ^ 2)
    local speedStr = string.format("%.0f u/s", speed)
    local speedPrefix = "Speed: "

    -- Get text heights
    local _, roundPrefixH = surface.GetTextSize(roundPrefix)
    local _, speedPrefixH = surface.GetTextSize(speedPrefix)

    -- Box dimensions
    local lineSpacing = 12 -- extra space between lines
    local padding = 12
    local boxW = 225 -- static width
    local boxH = roundPrefixH + speedPrefixH + lineSpacing + padding * 1.75

    local boxX = screenW * 0.30 - boxW / 2
    local boxY = screenH - boxH - 10

    -- background
    draw.RoundedBox(6, boxX, boxY, boxW, boxH, Color(10, 10, 10, 220))

    -- outline offsets
    local offsets = {
        {-1,  0}, {1,  0}, {0, -1}, {0, 1},
        {-1, -1}, {1, -1}, {-1, 1}, {1, 1}
    }

    local function DrawHudLine(y, prefix, valueStr, valueColor)
        local prefixX = boxX + 16
        local valueX  = prefixX + surface.GetTextSize(prefix)
        local textY   = boxY + padding + y

        -- prefix
        draw.SimpleText(prefix, font, prefixX, textY, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        -- outline for value
        for _, offset in ipairs(offsets) do
            draw.SimpleText(valueStr, font, valueX + offset[1], textY + offset[2], color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        -- value
        draw.SimpleText(valueStr, font, valueX, textY, valueColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    -- Role color for round
    local roundColor = color_white
    if ply.GetSubRoleData then
        local roleData = ply:GetSubRoleData()
        if roleData and roleData.color then
            roundColor = roleData.color
        end
    end

    -- Draw lines with extra spacing
    DrawHudLine(0, roundPrefix, roundStr, roundColor)
    DrawHudLine(roundPrefixH + lineSpacing, speedPrefix, speedStr, GetRainbowColor(speed))
end)