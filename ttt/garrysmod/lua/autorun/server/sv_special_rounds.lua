if not SERVER then return end

CreateConVar("special_round_pct", "5", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Base percent chance of a special round; increases by this amount each normal round and resets when a special round fires", 0, 100)

util.AddNetworkString("sc0b_SpecialRoundType")

-- ─────────────────────────────────────────────
-- Rarity weights
-- ─────────────────────────────────────────────
local RARITY_WEIGHTS = {
    common   = 6,
    uncommon = 2,
    rare     = 1,
}

-- ─────────────────────────────────────────────
-- Mode definitions
-- ─────────────────────────────────────────────
local SPECIAL_MODES = {
    {
        id     = "tank",
        name   = "Tank Mode",
        rarity = "common",
        scale  = 1.5,
        health = 500,
    },
    {
        id     = "tiny",
        name   = "Tiny Mode",
        rarity = "common",
        scale  = 0.5,
        health = 50,
    },
    {
        id         = "speed",
        name       = "Speed Mode",
        rarity     = "common",
        speed_mult = 1.5,
    },
    {
        id     = "bhop",
        name   = "Bunny Hop Mode",
        rarity = "common",
    },
    {
        id     = "superman",
        name   = "Superman Mode",
        rarity = "uncommon",
    },
    {
        id     = "screw_jump",
        name   = "Screw Jump Mode",
        rarity = "uncommon",
    },
    {
        id     = "chaos",
        name   = "Chaos Mode",
        rarity = "rare",
    },
    {
        id     = "low_grav",
        name   = "Low Gravity",
        rarity = "common",
    },
    {
        id     = "double_time",
        name   = "Double Time",
        rarity = "uncommon",
    },
    {
        id     = "slow_mo",
        name   = "Slow Motion",
        rarity = "uncommon",
    },
}

-- ─────────────────────────────────────────────
-- Weighted random selection
-- ─────────────────────────────────────────────
local function PickRandomMode()
    local pool = {}
    for _, m in ipairs(SPECIAL_MODES) do
        local w = RARITY_WEIGHTS[m.rarity] or 1
        for _ = 1, w do
            pool[#pool + 1] = m
        end
    end
    return pool[math.random(#pool)]
end

-- ─────────────────────────────────────────────
-- State
-- ─────────────────────────────────────────────
local currentMode    = nil   -- active only during ROUND_ACTIVE
local pendingMode    = nil   -- chosen during prep, promoted to currentMode at TTTBeginRound
local forcedMode     = nil   -- set by admin command; consumed on next TTTBeginRound
local currentPct     = nil   -- lazily initialized; tracks rolling chance this session
local roundCount     = 0     -- total rounds started this session
local lastWasSpecial = false -- whether the previous round was a special round

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────
local VIEW_OFFSET_STAND  = Vector(0, 0, 64)
local VIEW_OFFSET_DUCKED = Vector(0, 0, 28)

local function ApplyMode(ply, mode)
    if not IsValid(ply) then return end

    -- Scale / health
    if mode.scale then
        ply:SetModelScale(mode.scale, 0)
        ply:SetViewOffset(VIEW_OFFSET_STAND  * mode.scale)
        ply:SetViewOffsetDucked(VIEW_OFFSET_DUCKED * mode.scale)
    end
    if mode.health then
        ply:SetMaxHealth(mode.health)
        ply:SetHealth(mode.health)
    end

    -- Speed
    if mode.speed_mult then
        ply.sr_orig_walk = ply:GetWalkSpeed()
        ply.sr_orig_run  = ply:GetRunSpeed()
        ply:SetWalkSpeed(ply.sr_orig_walk * mode.speed_mult)
        ply:SetRunSpeed(ply.sr_orig_run  * mode.speed_mult)
    end

    -- Screw jump
    if mode.id == "screw_jump" then
        local jumps = GetConVar("multijump_screw_jumps"):GetInt()
        ply:SetMaxJumpLevel(jumps)
    end

    -- Bhop: single jump only (auto-bhop via StartCommand hook)
    if mode.id == "bhop" then
        ply:SetMaxJumpLevel(0)
    end

    -- Chaos: give everyone enough credits so shop items are not greyed out
    if mode.id == "chaos" then
        ply:SetCredits(9999)
    end

    -- Superman: give all passive buff items via TTT2's item system
    if mode.id == "superman" then
        for _, item in pairs(items.GetList()) do
            if item.EquipMenuData and item.EquipMenuData.type == "item_passive" then
                ply:GiveEquipmentItem(item.id)
            end
        end
    end

end

local function ClearMode(ply)
    if not IsValid(ply) then return end

    -- Scale / health
    ply:SetModelScale(1.0, 0)
    ply:SetMaxHealth(100)
    ply:SetHealth(math.min(ply:Health(), 100))
    ply:SetViewOffset(VIEW_OFFSET_STAND)
    ply:SetViewOffsetDucked(VIEW_OFFSET_DUCKED)

    -- Speed
    if ply.sr_orig_walk then
        ply:SetWalkSpeed(ply.sr_orig_walk)
        ply.sr_orig_walk = nil
    end
    if ply.sr_orig_run then
        ply:SetRunSpeed(ply.sr_orig_run)
        ply.sr_orig_run = nil
    end

    -- Jump level - restore to server default
    local default_jumps = GetConVar("multijump_default_jumps")
    if default_jumps then
        ply:SetMaxJumpLevel(default_jumps:GetInt())
    end

    -- Superman: strip all passive buff items
    for _, item in pairs(items.GetList()) do
        if item.EquipMenuData and item.EquipMenuData.type == "item_passive" then
            if ply:HasEquipmentItem(item.id) then
                ply:RemoveEquipmentItem(item.id)
            end
        end
    end
end

-- ─────────────────────────────────────────────
-- Bhop: strip IN_JUMP while airborne so the engine
--       treats landing with space held as a fresh press.
--       Emit a jump sound audible to nearby players.
-- ─────────────────────────────────────────────
local bhopWasOnGround = {}

hook.Add("StartCommand", "sc0b_BhopMode", function(ply, cmd)
    if not currentMode or currentMode.id ~= "bhop" then return end
    if not IsValid(ply) or ply:IsSpec() then return end

    local sid      = ply:SteamID64()
    local onGround = ply:IsOnGround()

    -- Auto-bhop: strip jump input while airborne
    if not onGround and cmd:KeyDown(IN_JUMP) then
        cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(IN_JUMP)))
    end

    -- Emit jump sound the tick the player leaves the ground
    if bhopWasOnGround[sid] and not onGround then
        ply:EmitSound("player/footsteps/jump1.wav", 75, math.random(95, 105), 0.7)
    end

    bhopWasOnGround[sid] = onGround
end)

-- ─────────────────────────────────────────────
-- Chaos: restrict to innocents + traitors only,
--        open T shop to everyone with infinite credits
-- ─────────────────────────────────────────────

-- Before roles are assigned, force a ~50/50 innocent/traitor split
hook.Add("TTT2ModifyFinalRoles", "sc0b_ChaosRoleFilter", function(finalRoles)
    if not pendingMode or pendingMode.id ~= "chaos" then return end

    local allPlayers = {}
    for ply in pairs(finalRoles) do
        if IsValid(ply) then
            allPlayers[#allPlayers + 1] = ply
        end
    end

    local total = #allPlayers
    local traitorCount = math.max(1, math.floor(total / 2))

    -- Fisher-Yates shuffle
    for i = total, 2, -1 do
        local j = math.random(i)
        allPlayers[i], allPlayers[j] = allPlayers[j], allPlayers[i]
    end

    for i, ply in ipairs(allPlayers) do
        finalRoles[ply] = (i <= traitorCount) and ROLE_TRAITOR or ROLE_INNOCENT
    end
end)

-- Allow everyone to buy from shop during Chaos mode, for free
hook.Add("TTT2CanOrderEquipment", "sc0b_ChaosShop", function(ply, equipmentName, isItem, credits)
    if currentMode and currentMode.id == "chaos" then
        return true, true  -- allow purchase + ignore credit cost
    end
end)

-- ─────────────────────────────────────────────
-- Admin-only messaging
-- ─────────────────────────────────────────────
local function notifyAdmins(msg)
    print(msg)
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsSuperAdmin() then
            ply:PrintMessage(HUD_PRINTTALK, "[ADMIN ONLY] " .. msg)
        end
    end
end

concommand.Add("sc0b_force_special", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        adminMsg(ply, "[SPECIAL ROUNDS] Superadmin required.")
        return
    end

    local arg = args[1] or ""

    if arg == "" or arg == "list" then
        local parts = {}
        for _, m in ipairs(SPECIAL_MODES) do
            table.insert(parts, m.id .. " (" .. m.name .. ", " .. m.rarity .. ")")
        end
        notifyAdmins("[SPECIAL ROUNDS] Modes: " .. table.concat(parts, ", "))
        if forcedMode then
            notifyAdmins("[SPECIAL ROUNDS] Currently queued: " .. forcedMode.name)
        end
        return
    end

    if arg == "clear" or arg == "none" then
        forcedMode = nil
        notifyAdmins("[SPECIAL ROUNDS] Forced mode cleared.")
        return
    end

    local found
    for _, m in ipairs(SPECIAL_MODES) do
        if m.id == arg then found = m; break end
    end

    if not found then
        notifyAdmins("[SPECIAL ROUNDS] Unknown mode '" .. arg .. "'. Use sc0b_force_special list.")
        return
    end

    forcedMode = found
    notifyAdmins("[SPECIAL ROUNDS] Next round forced to " .. found.name .. " by " .. (IsValid(ply) and ply:Nick() or "console"))
end)

-- ─────────────────────────────────────────────
-- Prep phase: roll and tease
-- ─────────────────────────────────────────────
local PREP_HINTS = {
    "Something special is brewing...",
    "The air feels different this round.",
    "Something is rumbling beneath the surface.",
    "An unusual energy fills the room.",
    "This round feels... different.",
    "Something wicked this way comes.",
    "The laws of nature seem unstable.",
    "Forces beyond comprehension stir.",
}

hook.Add("TTTPrepareRound", "sc0b_SpecialRoundPrep", function()
    currentMode = nil
    pendingMode = nil
    roundCount  = roundCount + 1

    -- Safety: restore global effects in case last round's cleanup was missed
    if GetConVar("sv_gravity"):GetInt() ~= 285 then
        game.ConsoleCommand("sv_gravity 285\n")
    end
    game.SetTimeScale(1)

    local base = GetConVar("special_round_pct"):GetInt()
    if currentPct == nil then currentPct = base end

    if forcedMode then
        pendingMode    = forcedMode
        forcedMode     = nil
        currentPct     = base
        lastWasSpecial = true
        notifyAdmins("[SPECIAL ROUNDS] Forced: " .. pendingMode.name .. " - chance reset to " .. base .. "%")
    else
        if base > 0 and math.random(100) <= currentPct then
            pendingMode = PickRandomMode()
            notifyAdmins("[SPECIAL ROUNDS] Rolled at " .. currentPct .. "%: " .. pendingMode.name .. " - resetting to " .. base .. "%")
            currentPct     = base
            lastWasSpecial = true
        else
            if lastWasSpecial then
                notifyAdmins("[SPECIAL ROUNDS] Last round was special - chance reset to " .. currentPct .. "%")
            elseif roundCount % 2 == 0 then
                notifyAdmins("[SPECIAL ROUNDS] Current special round chance: " .. currentPct .. "%")
            end
            currentPct     = math.min(currentPct + base, 100)
            lastWasSpecial = false
            return
        end
    end

    -- Vague prep-phase hint in chat
    local hint = PREP_HINTS[math.random(#PREP_HINTS)]
    for _, ply in ipairs(player.GetAll()) do
        ply:PrintMessage(HUD_PRINTTALK, "[GREATSEA] " .. hint)
    end
end)

-- ─────────────────────────────────────────────
-- Round start: apply mode and announce
-- ─────────────────────────────────────────────
hook.Add("TTTBeginRound", "sc0b_SpecialRoundBegin", function()
    -- Promote pending → current now that the round is actually active
    currentMode = pendingMode
    pendingMode = nil

    if not currentMode then return end

    -- Global effects (not per-player)
    if currentMode.id == "low_grav" then
        currentMode._origGrav = GetConVar("sv_gravity"):GetInt()
        game.ConsoleCommand("sv_gravity 75\n")
    elseif currentMode.id == "double_time" then
        game.SetTimeScale(1.5)
    elseif currentMode.id == "slow_mo" then
        game.SetTimeScale(0.5)
    end

    -- Apply per-player effects
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and not ply:IsSpec() then
            ApplyMode(ply, currentMode)
        end
    end

    -- Chaos: open T shop panel for innocents by routing their fallback to traitor
    if currentMode.id == "chaos" then
        RunConsoleCommand("ttt_inno_shop_fallback", "traitor")
    end

    -- Chat announcement
    for _, ply in ipairs(player.GetAll()) do
        ply:PrintMessage(HUD_PRINTTALK, "[GREATSEA] Special Round: " .. currentMode.name .. "!")
    end

    -- Client HUD notification
    net.Start("sc0b_SpecialRoundType")
        net.WriteString(currentMode.id)
        net.WriteString(currentMode.name)
    net.Broadcast()

    -- Update the rounds row - deferred so sv_log_rounds.lua's INSERT runs first
    timer.Simple(0, function()
        local round_id = GetGlobalInt("sc0b_currentRoundID", 0)
        if round_id == 0 then return end
        sql.Query(string.format(
            "UPDATE rounds SET round_type = '%s' WHERE round_id = %d",
            currentMode.id, round_id
        ))
        notifyAdmins("[SPECIAL ROUNDS] Round " .. round_id .. " set to: " .. currentMode.id)
    end)
end)

-- ─────────────────────────────────────────────
-- Round end - restore all players
-- ─────────────────────────────────────────────
hook.Add("TTTEndRound", "sc0b_SpecialRoundEnd", function()
    if currentMode then
        -- Restore global effects
        if currentMode.id == "low_grav" then
            game.ConsoleCommand("sv_gravity " .. (currentMode._origGrav or 285) .. "\n")
        elseif currentMode.id == "double_time" or currentMode.id == "slow_mo" then
            game.SetTimeScale(1)
        end

        -- Restore innocent shop to disabled
        if currentMode.id == "chaos" then
            RunConsoleCommand("ttt_inno_shop_fallback", "DISABLED")
        end
    end

    currentMode = nil
    pendingMode = nil

    for _, ply in ipairs(player.GetAll()) do
        ClearMode(ply)
    end
end)

-- ─────────────────────────────────────────────
-- Reapply to players who spawn mid-round
-- (e.g. late connects)
-- ─────────────────────────────────────────────
hook.Add("PlayerSpawn", "sc0b_SpecialRoundSpawn", function(ply)
    if not currentMode then return end
    if not IsValid(ply) or ply:IsSpec() then return end
    if GetRoundState() ~= ROUND_ACTIVE then return end

    timer.Simple(0.1, function()
        if IsValid(ply) and currentMode and GetRoundState() == ROUND_ACTIVE then
            ApplyMode(ply, currentMode)
        end
    end)
end)
