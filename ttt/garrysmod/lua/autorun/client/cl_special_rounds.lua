if not CLIENT then return end

-- ─────────────────────────────────────────────
-- Fonts
-- ─────────────────────────────────────────────
surface.CreateFont("sc0b_SR_Title", {
    font      = "Impact",
    size      = 78,
    weight    = 400,
    antialias = true,
})

surface.CreateFont("sc0b_SR_Desc", {
    font      = "Courier New",
    size      = 21,
    weight    = 500,
    antialias = true,
})

surface.CreateFont("sc0b_SR_Label", {
    font      = "Impact",
    size      = 22,
    weight    = 400,
    antialias = true,
    italic    = true,
})

-- ─────────────────────────────────────────────
-- Mode icons (32x32 PNGs, tinted at draw time)
-- ─────────────────────────────────────────────
local MODE_ICONS = {}
local ICON_IDS = { "tank", "tiny", "speed", "bhop", "superman", "screw_jump", "chaos", "low_grav", "double_time", "slow_mo" }
for _, id in ipairs(ICON_IDS) do
    MODE_ICONS[id] = Material("sc0b_special_rounds/" .. id .. ".png", "noclamp smooth")
end

local ICON_DRAW_SIZE = 64  -- render at 2x for crispness

-- ─────────────────────────────────────────────
-- Per-mode display info
-- ─────────────────────────────────────────────
local MODE_INFO = {
    tank = {
        color  = Color(255, 80,  80),
        rarity = "COMMON",
        desc   = {
            "Everyone is BIG and TANKY.",
            "1.5x model scale - 500 HP",
        },
    },
    tiny = {
        color  = Color(80, 200, 255),
        rarity = "COMMON",
        desc   = {
            "Everyone is TINY and FRAGILE.",
            "0.5x model scale - 50 HP",
        },
    },
    speed = {
        color  = Color(102, 255, 180),
        rarity = "COMMON",
        desc   = {
            "Everyone moves at DOUBLE SPEED.",
            "2x walk and run speed",
        },
    },
    bhop = {
        color  = Color(80, 255, 160),
        rarity = "COMMON",
        desc   = {
            "Hold SPACE for perfect bunny hops.",
            "1 jump only, utilize strafing!",
        },
    },
    superman = {
        color  = Color(255, 224, 102),
        rarity = "UNCOMMON",
        desc   = {
            "Everyone receives ALL passive T shop buffs.",
            "Armor - No fall - No explosions - No fire - and more",
        },
    },
    screw_jump = {
        color  = Color(190, 120, 255),
        rarity = "UNCOMMON",
        desc   = {
            "Everyone has SEVEN jumps.",
            "Leap across the map - get creative.",
        },
    },
    chaos = {
        color  = Color(255, 90, 210),
        rarity = "RARE",
        desc   = {
            "Everyone has access to the TRAITOR SHOP.",
            "Infinite credits - Buy whatever you want",
        },
    },
    low_grav = {
        color  = Color(120, 200, 255),
        rarity = "COMMON",
        desc   = {
            "Gravity has been reduced to near zero.",
            "BLAST OFF!",
        },
    },
    double_time = {
        color  = Color(255, 200, 50),
        rarity = "UNCOMMON",
        desc   = {
            "The server is running at 150% speed.",
            "Everything moves and fires faster.",
        },
    },
    slow_mo = {
        color  = Color(160, 100, 255),
        rarity = "UNCOMMON",
        desc   = {
            "The server is running at 50% speed.",
            "Everything moves and fires slower.",
        },
    },
}

-- ─────────────────────────────────────────────
-- State
-- ─────────────────────────────────────────────
local ann = nil  -- active announcement

local DURATION = 7
local FADE_IN  = 0.4
local FADE_OUT = 0.8

-- ─────────────────────────────────────────────
-- Net receiver
-- ─────────────────────────────────────────────
net.Receive("sc0b_SpecialRoundType", function()
    local modeId   = net.ReadString()
    local modeName = net.ReadString()

    local info = MODE_INFO[modeId] or { color = Color(255, 255, 255), rarity = "", desc = {} }

    ann = {
        name      = modeName,
        color     = info.color,
        rarity    = info.rarity,
        desc      = info.desc,
        icon      = MODE_ICONS[modeId],
        startTime = CurTime(),
    }

    surface.PlaySound("buttons/button15.wav")
end)

-- ─────────────────────────────────────────────
-- HUD draw
-- ─────────────────────────────────────────────
hook.Add("HUDPaint", "sc0b_SpecialRoundAnnouncement", function()
    if not ann then return end

    local elapsed = CurTime() - ann.startTime

    if elapsed >= DURATION then
        ann = nil
        return
    end

    -- Alpha envelope
    local a
    if elapsed < FADE_IN then
        a = elapsed / FADE_IN
    elseif elapsed > DURATION - FADE_OUT then
        a = (DURATION - elapsed) / FADE_OUT
    else
        a = 1
    end
    a = math.Clamp(a, 0, 1)

    local sw = ScrW()
    local sh = ScrH()
    local cx = sw * 0.5
    local cy = sh * 0.26  -- upper screen, well above crosshair

    local c = ann.color

    -- Measure title
    surface.SetFont("sc0b_SR_Title")
    local tw, th = surface.GetTextSize(ann.name)

    -- Measure rarity label
    surface.SetFont("sc0b_SR_Label")
    local lw, lh = surface.GetTextSize("- " .. ann.rarity .. " SPECIAL ROUND -")

    -- Measure description lines
    surface.SetFont("sc0b_SR_Desc")
    local lineH = select(2, surface.GetTextSize("|")) + 6
    local maxDW = 0
    for _, line in ipairs(ann.desc) do
        local dw = surface.GetTextSize(line)
        if dw > maxDW then maxDW = dw end
    end

    -- Box dimensions (icon row adds ICON_DRAW_SIZE + gap)
    local pad      = 32
    local iconGap  = ann.icon and (ICON_DRAW_SIZE + 12) or 0
    local boxW     = math.max(tw, maxDW, lw) + pad * 2
    local boxH     = iconGap + lh + 10 + th + 14 + #ann.desc * lineH + pad * 1.5
    local boxX     = cx - boxW * 0.5
    local boxY     = cy - boxH * 0.5

    -- Background panel
    draw.RoundedBox(14, boxX, boxY, boxW, boxH, Color(8, 16, 28, math.floor(a * 225)))

    -- Top accent bar (mode color)
    local accentH = 4
    draw.RoundedBox(14, boxX, boxY, boxW, accentH, Color(c.r, c.g, c.b, math.floor(a * 255)))
    surface.SetDrawColor(c.r, c.g, c.b, math.floor(a * 255))
    surface.DrawRect(boxX, boxY + accentH * 0.5, boxW, accentH * 0.5)

    local yOff = boxY + pad * 0.75

    -- Icon
    if ann.icon and not ann.icon:IsError() then
        local ix = cx - ICON_DRAW_SIZE * 0.5
        surface.SetDrawColor(c.r, c.g, c.b, math.floor(a * 255))
        surface.SetMaterial(ann.icon)
        surface.DrawTexturedRect(ix, yOff, ICON_DRAW_SIZE, ICON_DRAW_SIZE)
        yOff = yOff + ICON_DRAW_SIZE + 12
    end

    -- Rarity label
    surface.SetFont("sc0b_SR_Label")
    local label = "- " .. ann.rarity .. " SPECIAL ROUND -"
    local lw2   = surface.GetTextSize(label)
    surface.SetTextColor(c.r, c.g, c.b, math.floor(a * 200))
    surface.SetTextPos(cx - lw2 * 0.5, yOff)
    surface.DrawText(label)
    yOff = yOff + lh + 8

    -- Title shadow
    surface.SetFont("sc0b_SR_Title")
    surface.SetTextColor(0, 0, 0, math.floor(a * 160))
    surface.SetTextPos(cx - tw * 0.5 + 3, yOff + 3)
    surface.DrawText(ann.name)

    -- Title
    surface.SetTextColor(c.r, c.g, c.b, math.floor(a * 255))
    surface.SetTextPos(cx - tw * 0.5, yOff)
    surface.DrawText(ann.name)
    yOff = yOff + th + 14

    -- Separator
    local sepW = boxW * 0.6
    surface.SetDrawColor(c.r, c.g, c.b, math.floor(a * 60))
    surface.DrawRect(cx - sepW * 0.5, yOff - 6, sepW, 1)

    -- Description lines
    surface.SetFont("sc0b_SR_Desc")
    for i, line in ipairs(ann.desc) do
        local dw = surface.GetTextSize(line)
        -- Shadow
        surface.SetTextColor(0, 0, 0, math.floor(a * 120))
        surface.SetTextPos(cx - dw * 0.5 + 2, yOff + 2)
        surface.DrawText(line)
        -- Text (brighter for first line, dimmer for second)
        local brightness = (i == 1) and 230 or 180
        surface.SetTextColor(brightness, brightness, brightness, math.floor(a * 255))
        surface.SetTextPos(cx - dw * 0.5, yOff)
        surface.DrawText(line)
        yOff = yOff + lineH
    end
end)
