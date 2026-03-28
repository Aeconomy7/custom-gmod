if not CLIENT then return end

-- Local caches keyed by steamid64 (safer than using player object as table key)
local GS_LevelCache = {}
local GS_TitleCache = {}
local GS_TitleStatType = {}
local GS_TitleRole = {}
local GS_TitleTeam = {}

-- Rank icon support (thief_rank0.png–thief_rank55.png; prefix = selected class)
local GS_RankMaterials = {}
local GS_RANK_MAX = 55
local GS_RANK_CLASS = "thief"  -- future: warrior / archer / magician / thief / pirate

local function GetRankMaterial(level)
    local idx = math.Clamp(math.floor(level) - 1, 0, GS_RANK_MAX)
    local key = GS_RANK_CLASS .. "_rank" .. idx
    if not GS_RankMaterials[key] then
        GS_RankMaterials[key] = Material("ranks/" .. key .. ".png", "noclamp smooth")
    end
    return GS_RankMaterials[key]
end

-- Rank colors: ROYGBIV starting with white, one tier per 10 levels
local GS_RankColors = {
    Color(255, 255, 255),  -- 1  White   (1–10)
    Color(255,  40,  40),  -- 2  Red    (11–20)
    Color(255, 140,   0),  -- 3  Orange (21–30)
    Color(255, 230,   0),  -- 4  Yellow (31–40)
    Color(  0, 210,   0),  -- 5  Green  (41–50)
    Color(  0, 140, 255),  -- 6  Blue   (51–60)
    Color( 80,   0, 200),  -- 7  Indigo (61–70)
    Color(180,  50, 255),  -- 8  Violet (71+)
}

local function GetRankColor(level)
    local tier = math.floor((level - 1) / 10) % #GS_RankColors + 1
    return GS_RankColors[tier]
end

local GS_TitleColors = {
    ["none"]          = Color(204, 204, 204),
    ["headshots"]     = Color(255, 77, 77),
    ["kills"]         = Color(255, 175, 0),
    ["roles"]         = Color(72, 75, 219),
    ["special"]       = Color(0, 230, 168),
    ["rounds"]        = Color(255, 0, 255),
    ["survival"]      = Color(102, 255, 102),
    ["damage"]        = Color(255, 111, 145),
    ["rounds_played"] = Color(2, 166, 207),
    ["map_wins"]      = Color(183,	84,	241),

    -- Innocents
    ["innocent"]      = Color(5, 214, 12),
    ["priest"]        = Color(191, 255, 128),
    ["survivalist"]   = Color(34, 139, 34),
    ["lycanthrope"]   = Color(0, 100, 0),
    ["spy"]           = Color(255, 140, 0),
    ["paranoid"]      = Color(96, 200, 96),
    ["wrath"]         = Color(152, 255, 152),

    -- Detectives
    ["detective"]     = Color(49, 115, 255),
    ["sheriff"]       = Color(30, 100, 182),
    ["deputy"]        = Color(70, 130, 180),

    -- Traitors
    ["traitor"]       = Color(229, 57, 53),
    ["mesmerist"]     = Color(255, 77, 106),
    ["thrall"]        = Color(255, 102, 128),
    ["defective"]     = Color(128, 0, 128),

    -- Neutrals
    ["serialkiller"]  = Color(0, 184, 168),
    ["necromancer"]   = Color(143, 96, 190),
    ["marker"]        = Color(164, 136, 218),
    ["jester"]        = Color(255, 20, 147),
    ["pirate_captain"] = Color(205, 133, 63),
    ["zombie"]        = Color(87, 64, 124),

    -- Teams
    ["innocents"]       = Color(5, 214, 12),
    ["traitors"]        = Color(229, 57, 53),
    ["neutrals"]        = Color(66, 119, 150),
    ["serialkillers"]   = Color(0, 184, 168),
    ["necromancers"]    = Color(143, 96, 190),
    ["markers"]         = Color(164, 136, 218),
    ["jesters"]         = Color(255, 20, 147),
    ["pirates"]         = Color(205, 133, 63)
}

-- ──────────────────────────────────────────────────────────
-- Request from server when the scoreboard is shown/opened
-- ──────────────────────────────────────────────────────────
hook.Add("TTTScoreboardShow", "GS_RequestDataOnOpen", function()
    net.Start("GS_RequestScoreboardData")
    net.SendToServer()
end)

net.Receive("GS_SendLevelTitle", function()
    local sid64 = net.ReadString()
    local level = net.ReadUInt(16)
    local title = net.ReadString()
    local stat_type = net.ReadString()
    local role_type = net.ReadString()
    local team_type = net.ReadString()

    GS_LevelCache[sid64] = level
    GS_TitleCache[sid64] = title
    GS_TitleStatType[sid64] = stat_type
    GS_TitleRole[sid64] = role_type
    GS_TitleTeam[sid64] = team_type
end)

-- ──────────────────────────────────────────────────────────
-- Columns: Title first (appears right of RankLvl), RankLvl last (appears leftmost = closest to name)
-- ──────────────────────────────────────────────────────────
hook.Add("TTTScoreboardColumns", "GS_AddLevelTitleColumns", function(pnl)

    -- TITLE COLUMN (static width, 4x default)
    local titleWidth = 200

    pnl:AddColumn("Title", function(ply, label)
        if not IsValid(ply) then return "" end
        local title = GS_TitleCache[ply:SteamID64()] or ""
        local stat_type = GS_TitleStatType[ply:SteamID64()] or "none"

        local col = GS_TitleColors[stat_type] or Color(255, 255, 255)

        -- Handle role/team overrides for rounds
        if stat_type == "rounds" then
            local role_type = GS_TitleRole[ply:SteamID64()] or "none"
            local team_type = GS_TitleTeam[ply:SteamID64()] or "none"

            if team_type ~= "none" then
                col = GS_TitleColors[team_type] or col
            elseif role_type ~= "none" then
                col = GS_TitleColors[role_type] or col
            end
        end

        label:SetTextColor(col)
        label:SetTextInset(12, 0)
        return title
    end, titleWidth)

end)

-- ──────────────────────────────────────────────────────────
-- Rank-color the player name in the scoreboard
-- ──────────────────────────────────────────────────────────
hook.Add("TTTScoreboardColorForPlayer", "GS_RankNameColor", function(ply)
    if not IsValid(ply) then return end
    local sid64 = ply:SteamID64()
    local level = GS_LevelCache[sid64]
    if not level then return end  -- let TTT2 handle if we have no data yet
    return GetRankColor(level)
end)

-- ──────────────────────────────────────────────────────────
-- Rank level badge in chat  (chat.AddText is text-only; no PNG embed possible)
-- ──────────────────────────────────────────────────────────
hook.Add("OnPlayerChat", "GS_RankInChat", function(ply, text, teamOnly, isDead)
    if not IsValid(ply) then return end

    local level = GS_LevelCache[ply:SteamID64()] or 1
    local rankColor = GetRankColor(level)

    local prefix = ""
    if isDead    then prefix = prefix .. "*DEAD* " end
    if teamOnly  then prefix = prefix .. "*TEAM* " end

    chat.AddText(
        Color(180, 180, 180), prefix,
        rankColor,            "[" .. level .. "] ",
        Color(255, 255, 255), ply:Nick(),
        Color(180, 180, 180), ": ",
        Color(240, 240, 240), text
    )
    return true  -- suppress default rendering
end)

-- ──────────────────────────────────────────────────────────
-- Change yellow title bar to blue by overriding TTTScoreboard panel Paint
-- ──────────────────────────────────────────────────────────
hook.Add("InitPostEntity", "GS_BlueScoreboardBar", function()
    -- ── Scoreboard main panel: blue bar + custom logo ──────────────────
    local sb = vgui.GetControlTable("TTTScoreboard")
    if not sb then return end

    local GS_BAR_COLOR = Color(0, 80, 180, 255)
    local GS_BG_COLOR  = Color(30, 30, 30, 235)
    local GS_Y_LOGO    = 89
    local GS_LOGO_MAT  = Material("logo", "smooth")

    sb.Paint = function(self)
        draw.RoundedBox(8, 0, GS_Y_LOGO, self:GetWide(), self:GetTall() - GS_Y_LOGO, GS_BG_COLOR)
        draw.RoundedBox(8, 0, GS_Y_LOGO + 25, self:GetWide(), 32, GS_BAR_COLOR)
        if GS_LOGO_MAT and not GS_LOGO_MAT:IsError() then
            surface.SetMaterial(GS_LOGO_MAT)
        else
            surface.SetTexture(TTTScoreboard.Logo)
        end
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(5, 0, 192, 96)
    end

    -- ── Player row: inject rank icon + level LEFT of player name ───────
    local GS_RANK_W = 52  -- icon (~20px) + gap + level digits (~25px) + gap

    local row = vgui.GetControlTable("TTTScorePlayerRow")
    if not row then return end

    local origInit     = row.Init
    local origLayout   = row.PerformLayout

    row.Init = function(self)
        origInit(self)
        local gs = vgui.Create("DPanel", self)
        gs:SetMouseInputEnabled(false)
        gs.Paint = function(s, w, h)
            if not IsValid(self.Player) then return end
            local lvl = GS_LevelCache[self.Player:SteamID64()] or 1
            local iconSize = h - 4
            local mat = GetRankMaterial(lvl)
            if mat and not mat:IsError() then
                surface.SetMaterial(mat)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(0, 2, iconSize, iconSize)
            end
            surface.SetFont("treb_small")
            local lvlStr = tostring(lvl)
            local _, th = surface.GetTextSize(lvlStr)
            surface.SetTextColor(255, 255, 255, 255)
            surface.SetTextPos(iconSize + 3, (h - th) / 2)
            surface.DrawText(lvlStr)
        end
        self.gs_rank = gs
    end

    row.PerformLayout = function(self)
        origLayout(self)
        if not self.gs_rank then return end
        -- Shift name labels and role icon rightward to make room
        local function shiftX(p) local x, y = p:GetPos(); p:SetPos(x + GS_RANK_W, y) end
        shiftX(self.nick)
        shiftX(self.nick2)
        shiftX(self.nick3)
        shiftX(self.team)
        shiftX(self.team2)
        -- Place rank panel between avatar and the (now shifted) role icon
        self.gs_rank:SetPos(SB_ROW_HEIGHT + 2, 0)
        self.gs_rank:SetSize(GS_RANK_W, SB_ROW_HEIGHT)
        -- Re-run LayoutColumns so admin/vip/dev icons reposition against the shifted nick
        self:LayoutColumns()
    end
end)
