if not SERVER then return end

-- One-time mass-grant for "A Year at Sea" (year_at_sea).
-- Grants to any player who played at least one non-test round between
-- 2025-09-15 and 2026-09-15 (Unix: 1757894400 to 1789516800).
-- Safe to leave in permanently - the grant function is idempotent.

local ACH_ID = "year_at_sea"
local RANGE_START = 1757894400 -- 2025-09-15 UTC
local RANGE_END   = 1789516800 -- 2026-09-16 UTC (exclusive)

-- Tracks per-session state for each SteamID64.
-- ps2Ready: PS2 inventory is cached for this player.
-- spawned:  Player has physically spawned (not as spectator).
-- checked:  Grant attempt already made this session.
local state = {}

local function TryGrant(ply)
    if not IsValid(ply) or ply:IsBot() then return end

    local sid = ply:SteamID64()
    if not sid or sid == "" then return end

    local s = state[sid]
    if not s then return end
    if s.checked then return end
    if not (s.ps2Ready and s.spawned) then return end

    s.checked = true

    local row = sql.QueryRow([[
        SELECT 1 FROM round_players rp
        JOIN rounds r ON r.round_id = rp.round_id
        WHERE r.test_round = 0
          AND r.start_time >= ]] .. RANGE_START .. [[
          AND r.start_time <  ]] .. RANGE_END .. [[
          AND rp.steamid = ']] .. sid .. [['
        LIMIT 1
    ]])

    if not row then return end -- no qualifying round in the window

    -- Check before granting so we can update earned_round only for new grants
    local alreadyHad = sql.QueryRow("SELECT 1 FROM player_achievements WHERE steamid = '" .. sid .. "' AND internal_id = '" .. ACH_ID .. "'")

    sc0b_GrantAchievementByInternalID(ply, ACH_ID)

    if not alreadyHad then
        -- Set earned_round to 2084 (last round of the first year) after all rewards are applied
        sql.Query("UPDATE player_achievements SET earned_round = 2084 WHERE steamid = '" .. sid .. "' AND internal_id = '" .. ACH_ID .. "'"  )
    end
end

-- PS2 inventory cached - player can now receive PS2 item grants.
hook.Add("PS2_PlayerFullyLoaded", "sc0b_GrantYearAtSea_PS2Ready", function(ply)
    if not IsValid(ply) then return end
    local sid = ply:SteamID64()
    if not sid or sid == "" then return end
    state[sid] = state[sid] or {}
    state[sid].ps2Ready = true
    TryGrant(ply)
end)

-- Physical spawn - player is alive and their HUD/chat are live.
hook.Add("PlayerSpawn", "sc0b_GrantYearAtSea_Spawn", function(ply)
    if not IsValid(ply) then return end
    if ply:IsSpec() then return end
    local sid = ply:SteamID64()
    if not sid or sid == "" then return end
    state[sid] = state[sid] or {}
    state[sid].spawned = true
    TryGrant(ply)
end)

-- Clean up on disconnect so a reconnect gets a fresh check.
hook.Add("PlayerDisconnected", "sc0b_GrantYearAtSea_Cleanup", function(ply)
    local sid = IsValid(ply) and ply:SteamID64()
    if sid then state[sid] = nil end
end)
