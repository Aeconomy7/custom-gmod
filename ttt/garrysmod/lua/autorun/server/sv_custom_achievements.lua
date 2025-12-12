-- sv_custom_achievements.lua
if not SERVER then return end


sql.Query([[
CREATE TABLE IF NOT EXISTS all_achievements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    internal_id TEXT UNIQUE,                -- e.g. "junior_sharpshooter"
    name TEXT,                              -- Pretty name, e.g. "Junior Sharpshooter"
    description TEXT,                       -- e.g. "Get 50 headshots"
    stat_type TEXT DEFAULT 'none',          -- e.g. "rounds", "roles", "headshots", "kills", "good_kills, "special" - default to special if not stat based (IE chat message check, etc)
    weapon_type TEXT DEFAULT 'none',        -- e.g. "weapon_zm_rifle" - only needed if applicable to the achievement (IE 10 AWP kills)
    role_type TEXT DEFAULT 'none',          -- e.g. "traitor", specifies a role 
    team_type TEXT DEFAULT 'none',          -- e.g. "traitors", specifies a team
    victim_role_type TEXT DEFAULT 'none',   -- e.g. "innocent", specifies a victim role for kills
    victim_team_type TEXT DEFAULT 'none',   -- e.g. "innocents", specifies a victim team for kills
    stat_amount INTEGER DEFAULT 0,          -- e.g. 50
    reward_xp INTEGER DEFAULT 0,
    reward_ps2_points INTEGER DEFAULT 0,
    reward_xp_multi REAL DEFAULT 0.0,
    reward_extra TEXT DEFAULT 'none',       -- e.g. "Custom Skin of Player's Choice", "Hacker Skin" - which you can get by typing in 'OSINTRULES' in-game chat
    hidden_achievement INTEGER DEFAULT 0    -- if achievement should show in the UI
)
]])

sql.Query([[
CREATE TABLE IF NOT EXISTS player_achievements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    steamid TEXT,
    internal_id TEXT,             -- references all_achievements.internal_id
    earned_round INTEGER,
    equipped INTEGER DEFAULT 0
)
]])

if SERVER then

    -- util.AddNetworkString("sc0b_AchievementEarned")

    -- Achievement cache in memory
    local Achievements = {}

    -- Load achievements from SQL on startup
    local function LoadAchievements()
        local rows = sql.Query("SELECT * FROM all_achievements")
        if rows and istable(rows) then
            for _, row in ipairs(rows) do
                Achievements[row.internal_id] = row
            end
        end
    end

    LoadAchievements()


    ----------------------------------------------------------------------
    -- GetPlayerKillCount
    -- steamid    : player's SteamID64 (string)
    -- weapon     : optional weapon filter (string or nil/"none")
    -- stat_type  : nil | "headshot" | "good_kill" | "winning_kill"
    -- killer_role_type  : optional killer role filter (string or nil/"none")
    -- killer_team_type  : optional killer team filter (string or nil/"none")
    -- victim_role_type  : optional victim role filter (string or nil/"none")
    -- victim_team_type  : optional victim team filter (string or nil/"none")
    ----------------------------------------------------------------------
    local function GetPlayerKillCount(steamid, weapon, stat_type, killer_role_type, killer_team_type, victim_role_type, victim_team_type)
        local base_where = [[
            FROM round_kills k
            JOIN rounds r ON r.round_id = k.round_id
            WHERE r.test_round = 0
            AND k.time BETWEEN r.start_time AND r.end_time
            AND k.killer_steamid != k.victim_steamid
        ]]

        local extra_conditions = {}
        local query

        -- always filter by killer_steamid for our player
        table.insert(extra_conditions, "k.killer_steamid = '" .. steamid .. "'")

        -- optional weapon filter
        if weapon and weapon ~= "none" then
            table.insert(extra_conditions, "k.weapon = '" .. weapon .. "'")
        end

        if killer_role_type and killer_role_type ~= "none" then table.insert(extra_conditions, "k.killer_role = '" .. killer_role_type .. "'") end
        if killer_team_type and killer_team_type ~= "none" then table.insert(extra_conditions, "k.killer_team = '" .. killer_team_type .. "'") end
        if victim_role_type and victim_role_type ~= "none" then table.insert(extra_conditions, "k.victim_role = '" .. victim_role_type .. "'") end
        if victim_team_type and victim_team_type ~= "none" then table.insert(extra_conditions, "k.victim_team = '" .. victim_team_type .. "'") end

        if stat_type == "headshots" then
            table.insert(extra_conditions, "k.headshot = 1")

        elseif stat_type == "good_kills" then
            table.insert(extra_conditions, [[
                k.killer_steamid != k.victim_steamid AND
                (
                    (k.killer_team != k.victim_team AND k.victim_team NOT IN ('jesters','pirates'))
                    OR (k.victim_team = 'pirates' AND k.killer_team IN ('serialkillers','necromancers','traitors'))
                )
            ]])
        end

        -- generic/all kills (no special CASE)
        query = "SELECT COUNT(*) AS kc " .. base_where
        if #extra_conditions > 0 then
            query = query .. " AND " .. table.concat(extra_conditions, " AND ")
        end

        -- print("[ACHIEVEMENTS] Query: " .. query)
        local q = sql.QueryRow(query)
        return q and tonumber(q.kc) or 0
    end


    ----------------------------------------------------------------------
    -- GetRoundWinCount
    -- steamid    : player's SteamID64 (string)
    -- role_type  : optional role filter (string or nil/"none")
    -- team_type  : optional role filter (string or nil/"none")
    ----------------------------------------------------------------------
    local function GetRoundWinCount(steamid, role_type, team_type)
        local base_where = [[
            FROM rounds r
            JOIN round_players rp ON rp.round_id = r.round_id
            WHERE r.test_round = 0
            AND r.end_time IS NOT NULL
            AND rp.team != 'nones'
        ]]

        local extra_conditions = {}

        -- always filter by killer_steamid for our player
        table.insert(extra_conditions, "rp.steamid = '" .. steamid .. "'")

        -- optional role filter
        if role_type and role_type ~= "none" then
            table.insert(extra_conditions, "rp.role = '" .. role_type .. "' AND r.winning_team = rp.team")
        end

        -- optional team filter
        if team_type and team_type ~= "none" then
            table.insert(extra_conditions, "rp.team = '" .. team_type .. "' AND r.winning_team = rp.team")
        end

        if not (role_type and role_type ~= "none") and not (team_type and team_type ~= "none") then
            table.insert(extra_conditions, "r.winning_team = rp.team")
        end

        -- Build query depending on stat_type
        local query

        query = "SELECT COUNT(*) AS wins " .. base_where
        if #extra_conditions > 0 then
            query = query .. " AND " .. table.concat(extra_conditions, " AND ")
        end

        -- print("[ACHIEVEMENTS] Query: " .. query)
        local q = sql.QueryRow(query)
        return q and tonumber(q.wins) or 0
    end


    function GetRoundsPlayed(steamid)
        local q = sql.QueryValue([[
            SELECT COUNT(DISTINCT rp.round_id)
            FROM round_players rp
            JOIN rounds r ON r.round_id = rp.round_id
            WHERE rp.steamid = ]] .. sql.SQLStr(steamid) .. [[
            AND rp.team NOT IN ('none', 'nones')
            AND r.test_round = 0;
        ]])

        return tonumber(q) or 0
    end


    ----------------------------------------------------------------------
    -- Check if a player already has an achievement
    ----------------------------------------------------------------------
    local function PlayerHasAchievement(steamid, internal_id)
        local q = sql.QueryRow([[
            SELECT id FROM player_achievements 
            WHERE steamid = ']] .. steamid .. [['
            AND internal_id = ']] .. internal_id .. [['
        ]])

        return q ~= nil
    end

    ----------------------------------------------------------------------
    -- Grant achievement
    ----------------------------------------------------------------------
    local function GrantAchievement(ply, ach)
        if not IsValid(ply) then return end

        local row = sql.QueryRow("SELECT round_id FROM rounds ORDER BY round_id DESC LIMIT 1")
        local currentRoundID = row and tonumber(row.round_id) or 0

        sql.Query([[
            INSERT OR IGNORE INTO player_achievements (steamid, internal_id, earned_round)
            VALUES (']] .. ply:SteamID64() .. [[', ']] .. ach.internal_id .. [[', ]] .. currentRoundID .. [[)
        ]])

        -- Reward XP
        if ach.reward_xp and tonumber(ach.reward_xp) > 0 then
            AddXP(ply, ach.reward_xp)
        end

        -- Update EXP multiplier
        local xp_multi = tonumber(ach.reward_xp_multi)
        if xp_multi and xp_multi > 0 then
            sql.Query("UPDATE player_xp SET exp_multi = exp_multi + " .. xp_multi .. " WHERE steamid = '" .. ply:SteamID64() .. "'")
        end

        -- Add Pointshop points
        if ach.reward_ps2_points and tonumber(ach.reward_ps2_points) > 0 then
            ply:PS2_AddStandardPoints(tonumber(ach.reward_ps2_points), "Completed achievement '" .. ach.name .. "'!")
        end

        -- Unlock reward_extra (e.g. Hacker playermodel)
        if ach.reward_extra and ach.reward_extra ~= "none" then
            if ach.reward_extra == "Custom Skin" then
                print("[GREATSEA][ACHIEVEMENTS] Custom skin earned")
            else
                local item_class = Pointshop2.GetItemClassByPrintName(ach.reward_extra)
                if not item_class then
                    error("[GREATSEA][ACHIEVEMENTS] ERROR invalid item : " .. ach.reward_extra)
                else
                    ply:PS2_EasyAddItem(item_class.className)
                end
            end
        end

        for _, v in ipairs(player.GetAll()) do
            v:PrintMessage(HUD_PRINTTALK, "[GREATSEA][ACHIEVEMENTS] " .. ply:Nick() .. " earned the achievement '" .. ach.name .. "'!")
        end
    end

    -- GLOBAL / PUBLIC achievement granting helper
    function sc0b_GrantAchievementByInternalID(ply, internal_id)
        if not IsValid(ply) then return end
        if not Achievements or not Achievements[internal_id] then return end

        local ach = Achievements[internal_id]

        -- Prevent duplicates
        if PlayerHasAchievement(ply:SteamID64(), ach.internal_id) then return end

        print("[ACHIEVEMENTS] Granting " .. ply:Nick() .. " the achievement '" .. ach.name .. "'")

        GrantAchievement(ply, ach)
    end

    ----------------------------------------------------------------------
    -- Check all achievements for a player
    ----------------------------------------------------------------------
    local function CheckPlayerAchievements(ply)
        if not IsValid(ply) then return end
        local sid = ply:SteamID64()

        for _, ach in pairs(Achievements) do
            local required = tonumber(ach.stat_amount) or 0

            -- HEADSHOT ACHIEVEMENTS
            if ach.stat_type == "headshots" or ach.stat_type == "kills" or ach.stat_type == "good_kills" then
                local count = GetPlayerKillCount(sid, ach.weapon_type, ach.stat_type, ach.role_type, ach.team_type, ach.victim_role_type, ach.victim_team_type)

                print("[ACHIEVEMENTS][" .. ply:Nick() .. "][" .. ach.internal_id .. "] " .. count .. "/" .. required .. "  (weapon: " .. ach.weapon_type .. " | stat_type: " .. ach.stat_type .. " | killer_role_type: " .. ach.role_type .. " | killer_team_type: " .. ach.team_type .. " | victim_role_type: " .. ach.victim_role_type .. " | victim_team_type: " .. ach.victim_team_type .. ")")

                if count >= required and not PlayerHasAchievement(sid, ach.internal_id) then
                    GrantAchievement(ply, ach)
                end

            elseif ach.stat_type == "rounds" then
                local count = GetRoundWinCount(sid, ach.role_type, ach.team_type)

                print("[ACHIEVEMENTS][" .. ply:Nick() .. "][" .. ach.internal_id .. "] " .. count .. "/" .. required .. "  (role_type: " .. ach.role_type .. " | team_type: " .. ach.team_type .. ")")

                if count >= required and not PlayerHasAchievement(sid, ach.internal_id) then
                    GrantAchievement(ply, ach)
                end

            elseif ach.stat_type == "rounds_played" then
                local count = GetRoundsPlayed(sid)

                print("[ACHIEVEMENTS][" .. ply:Nick() .. "][" .. ach.internal_id .. "] " .. count .. "/" .. required)

                if count >= required and not PlayerHasAchievement(sid, ach.internal_id) then
                    GrantAchievement(ply, ach)
                end

            -- FUTURE STAT TYPES
            elseif ach.stat_type == "special" then
                print("[ACHIEVEMENTS] Handling special achievement!")
            end
        end
    end

    ----------------------------------------------------------------------
    -- Hook into end of TTT2 round
    ----------------------------------------------------------------------
    hook.Add("TTTEndRound", "sc0b_CheckAchievements", function(result)
        timer.Simple(1.0, function() -- increment if buggy
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:SteamID64() then
                    CheckPlayerAchievements(ply)
                end
            end
        end)
    end)


    ----------------------------------------------------------------------
    -- Handle some special achievements that are not stat based
    ----------------------------------------------------------------------
    hook.Add("PlayerSay", "secret_sc00by_1", function(ply, text, teamChat)
        if not IsValid(ply) then return "" end
        if not text or text == "" then return "" end

        -- print("[ACHIEVEMENTS] PlayerSay detected: " .. ply:Nick() .. " said: " .. text) 

        local lowerText = string.lower(text)
        local REQUIRED_WORDS = {"sick", "headshot", "m8"} -- fixed typo

        for _, word in ipairs(REQUIRED_WORDS) do
            if not string.find(lowerText, word, 1, true) then
                return text
            end
        end

        sc0b_GrantAchievementByInternalID(ply, "secret_sc00by_1")

        return text
    end)

    -- hook.Add("PlayerSay", "secret_jfkdown_1", function(ply, text, teamChat)
    --     if not IsValid(ply) then return end
    --     if not text or text == "" then return end

    --     local lowerText = string.lower(text)
    --     local REQUIRED_WORDS = {"reach", "in", "pocket"}

    --     for _, word in ipairs(REQUIRED_WORDS) do
    --         if not string.find(lowerText, word, 1, true) then
    --             return text
    --         end
    --     end

    --     sc0b_GrantAchievementByInternalID(ply, "secret_jfkdown_1")

    --     return text
    -- end)

    ----------------------------------------------------------------------
    -- Title GUI and setting
    ----------------------------------------------------------------------
    util.AddNetworkString("sc0b_RequestTitles")
    util.AddNetworkString("sc0b_SendTitles")
    util.AddNetworkString("sc0b_EquipTitle")

    -- Send all earned achievements to a player
    net.Receive("sc0b_RequestTitles", function(len, ply)
        local sid = ply:SteamID64()

        local rows = sql.Query([[
            SELECT pa.id AS player_ach_id,
                   pa.equipped,
                   a.id AS ach_id,
                   a.name,
                   a.internal_id,
                   a.description
            FROM player_achievements pa
            JOIN all_achievements a ON a.internal_id = pa.internal_id
            WHERE pa.steamid = ']] .. sid .. [['
        ]])

        print(rows)

        net.Start("sc0b_SendTitles")
        net.WriteTable(rows or {})
        net.Send(ply)
    end)

    -- Equip an achievement title
    net.Receive("sc0b_EquipTitle", function(len, ply)
        local ach_internal_id = net.ReadString()
        local sid = ply:SteamID64()

        if not ach_internal_id or ach_internal_id == "" then return end

        print("[ACHIEVEMENTS] Updating " .. sid .. "'s title to '" .. ach_internal_id .. "'")

        -- Unequip all titles
        sql.Query("UPDATE player_achievements SET equipped = 0 WHERE steamid = '" .. sid .. "'")

        -- Equip the chosen one
        sql.Query("UPDATE player_achievements SET equipped = 1 WHERE steamid = '" .. sid .. "' AND internal_id = '" .. ach_internal_id .. "'")

        ply:ChatPrint("[GREATSEA] Updated equipped title!")
    end)

end
