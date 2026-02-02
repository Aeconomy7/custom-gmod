if not CLIENT then return end

-- Local caches keyed by steamid64 (safer than using player object as table key)
local GS_LevelCache = {}
local GS_TitleCache = {}
local GS_TitleStatType = {}
local GS_TitleRole = {}
local GS_TitleTeam = {}

local GS_LevelColors = {
    Color(255, 0, 0),      -- 1 Red
    Color(255, 128, 0),    -- 2 Orange
    Color(255, 255, 0),    -- 3 Yellow
    Color(0, 255, 0),      -- 4 Green
    Color(0, 128, 255),    -- 5 Blue
    Color(75, 0, 130),     -- 6 Indigo
    Color(148, 0, 211),    -- 7 Violet
    Color(255, 255, 255),  -- 8 White
    Color(0, 0, 0),        -- 9 Black
    Color(255, 0, 255),    -- 10 Magenta
    Color(0, 255, 255),    -- 11 Cyan
    Color(255, 0, 128),    -- 12 Rose
}

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

-- Request from server when the scoreboard is shown/opened
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

-- Helper to get steamid64 from ply safely (return "" if invalid)
local function GetSID64(ply)
    if not IsValid(ply) then return "" end

    if ply.SteamID64 then
        return ply:SteamID64()
    end
    return ""
end

hook.Add("TTTScoreboardColumns", "GS_AddLevelTitleColumns", function(pnl)
    
    -- LEVEL COLUMN (normal)
    pnl:AddColumn("Lvl", function(ply, label)
        if not IsValid(ply) then return "" end
        local lvl = GS_LevelCache[ply:SteamID64()] or 1
        local bucket = math.min(math.floor(lvl / 10) + 1, #GS_LevelColors)
        label:SetTextColor(GS_LevelColors[bucket])
        return tostring(lvl)
    end)

    -- TITLE COLUMN (static width, 4x default)
    local defaultWidth = 50
    local titleWidth = defaultWidth * 4

    pnl:AddColumn("Title", function(ply, label)
        if not IsValid(ply) then return "" end
        local title = GS_TitleCache[ply:SteamID64()] or ""
        local stat_type = GS_TitleStatType[ply:SteamID64()] or "none"

        local col = GS_TitleColors[stat_type] or Color(255, 255, 255)

        -- Handle role/team overrides for rounds
        if stat_type == "rounds" then
            local role_type = GS_TitleCache[ply:SteamID64()] or ""
            local team_type = GS_TitleCache[ply:SteamID64()] or ""

            if team_type ~= "none" then
                col = GS_TitleColors[team_type] or col
            elseif role_type ~= "none" then
                col = GS_TitleColors[role_type] or col
            end
        end

        label:SetTextColor(col)
        return title
    end, titleWidth)
end)
