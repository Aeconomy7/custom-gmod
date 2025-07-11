surface.CreateFont("Impact36", {
    font = "Impact",
    size = 36,
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

hook.Add("HUDPaint", "DrawVelocityHUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local vel = ply:GetVelocity()
    local speed = math.sqrt(vel.x ^ 2 + vel.y ^ 2)
    local speedStr = string.format("%.0f u/s", speed)

    local font = "Impact36"
    surface.SetFont(font)

    local prefix = "Speed: "
    local maxSpeedStr = "9999 u/s"
    local prefixW, textH = surface.GetTextSize(prefix)
    local valueW = surface.GetTextSize(maxSpeedStr)
    local totalW = prefixW + valueW

    local screenW, screenH = ScrW(), ScrH()
    local boxX = screenW * 0.25 - totalW / 2
    local boxY = screenH - textH - 50
    local textY = boxY + textH / 2
    local valueX = boxX + prefixW

    local speedColor = GetRainbowColor(speed)

    -- darker background
    draw.RoundedBox(6, boxX - 10, boxY - 5, totalW + 20, textH + 10, Color(10, 10, 10, 220))

    -- white prefix
    draw.SimpleText(prefix, font, boxX, textY, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- white outline (stroke)
    local offsets = {
        {-1,  0}, {1,  0}, {0, -1}, {0, 1},  -- cardinal
        {-1, -1}, {1, -1}, {-1, 1}, {1, 1}   -- diagonals
    }
    for _, offset in ipairs(offsets) do
        draw.SimpleText(speedStr, font, valueX + offset[1], textY + offset[2], color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- colored speed text on top
    draw.SimpleText(speedStr, font, valueX, textY, speedColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end)