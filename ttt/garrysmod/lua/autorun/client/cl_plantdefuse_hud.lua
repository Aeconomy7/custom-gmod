if SERVER then return end

local isBlind = false

local function SetBlind(state)
    isBlind = state
end

-- Draw the black fill in HUDPaintBackground so it sits BELOW HUDPaint (the TTT2
-- health/ammo/player-list HUD), which then sits below VGUI popups (pause menu, console).
hook.Add("HUDPaintBackground", "sc0b_PlantDefuseBlind_Fill", function()
    if not isBlind then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or ply:IsSpec() then
        isBlind = false
        return
    end
    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawRect(0, 0, ScrW(), ScrH())
end)

-- Draw the message text in HUDPaint so it appears on top of the TTT2 HUD.
hook.Add("HUDPaint", "sc0b_PlantDefuseBlind_Text", function()
    if not isBlind then return end
    draw.SimpleTextOutlined(
        "Planters are planting - stay put.",
        "DermaLarge",
        ScrW() / 2, ScrH() / 2,
        Color(255, 255, 255, 200),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
        1, Color(0, 0, 0, 200)
    )
end)

net.Receive("sc0b_PlantDefuseBlind", function()
    SetBlind(net.ReadBool())
end)

hook.Add("LocalPlayerDeath", "sc0b_PlantDefuseUnblindOnDeath", function() isBlind = false end)
hook.Add("TTTEndRound",      "sc0b_PlantDefuseUnblindOnEnd",   function() isBlind = false end)

-- ─────────────────────────────────────────────
-- Post-explosion: show where the bomb was
-- ─────────────────────────────────────────────
local bombMarkers = {}

net.Receive("sc0b_PlantDefuseBombExplode", function()
    table.insert(bombMarkers, { pos = net.ReadVector(), t = CurTime(), kind = "explode" })
end)

-- All bombs defused: show a marker for each defused bomb's location
net.Receive("sc0b_PlantDefuseAllDefused", function()
    local count = net.ReadUInt(8)
    for _ = 1, count do
        table.insert(bombMarkers, { pos = net.ReadVector(), t = CurTime(), kind = "defuse" })
    end
end)

-- Clear at round START so markers stay visible through the end-of-round screen
hook.Add("TTTBeginRound", "sc0b_PlantDefuseBombMarkersReset", function()
    bombMarkers = {}
end)

local MARKER_DURATION = 30

local MARKER_STYLE = {
    explode = { label = "BOMB DETONATED HERE", color = Color(255, 80, 30) },
    defuse  = { label = "BOMB DEFUSED HERE",   color = Color(30, 120, 220) },
}

hook.Add("HUDPaint", "sc0b_PlantDefuseBombMarker", function()
    if #bombMarkers == 0 then return end

    local now = CurTime()
    for _, m in ipairs(bombMarkers) do
        local elapsed = now - m.t
        if elapsed >= MARKER_DURATION then continue end

        local style = MARKER_STYLE[m.kind] or MARKER_STYLE.explode
        local alpha  = math.Clamp(255 * (1 - elapsed / MARKER_DURATION), 0, 255)
        local screen = m.pos:ToScreen()

        -- Always show a label at the screen edge if off-screen, full label if visible
        local x = math.Clamp(screen.x, 20, ScrW() - 20)
        local y = math.Clamp(screen.y, 20, ScrH() - 20)

        local col = style.color
        col.a = alpha
        draw.SimpleTextOutlined(
            style.label,
            "DermaLarge",
            x, y - 14,
            col,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
            1, Color(0, 0, 0, alpha)
        )

        -- Crosshair at the projected position
        surface.SetDrawColor(col.r, col.g, col.b, alpha)
        local sz = 8
        surface.DrawLine(x - sz, y + 6, x + sz, y + 6)
        surface.DrawLine(x,      y + 6 - sz, x, y + 6 + sz)
    end
end)

-- ttt_c4_pd:Explode fires TTTC4Explode on client too; return false to suppress any residual effects.
hook.Add("TTTC4Explode", "sc0b_PlantAndDefuseNoExplodeClient", function(bomb)
    if not IsValid(bomb) or bomb:GetClass() ~= "ttt_c4_pd" then return end
    return false
end)

-- Team ally ESP: planters see each other, defusers see each other
hook.Add("HUDPaint", "sc0b_PlantDefuseTeamESP", function()
    if not SC0B_ActiveRoundMode or SC0B_ActiveRoundMode.id ~= "plant_and_defuse" then return end

    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:Alive() then return end

    local myTeam = lp:GetTeam()
    local col
    if TEAM_PLANTER and myTeam == TEAM_PLANTER then
        col = Color(220, 80, 30, 220)
    elseif TEAM_DEFUSER and myTeam == TEAM_DEFUSER then
        col = Color(30, 120, 220, 220)
    end
    if not col then return end

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or ply == lp or not ply:Alive() then continue end
        if ply:GetTeam() ~= myTeam then continue end

        local screenPos = (ply:GetShootPos() + Vector(0, 0, 18)):ToScreen()
        if not screenPos.visible then continue end

        draw.SimpleText(
            ply:Nick() .. " [ALLY]",
            "DermaDefaultBold",
            screenPos.x, screenPos.y,
            col,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    end
end)
