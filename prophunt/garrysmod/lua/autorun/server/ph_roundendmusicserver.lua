-- ph_roundendmusicserver.lua
-- Plays random round-end music based on who won.
-- Props win  → innocents/ folder (same files as TTT)
-- Hunters win → traitors/ folder
if not SERVER then return end

local BASE = "music/end_random_music/"

local function scanFolder(sub)
    local out = {}
    local files = file.Find("sound/" .. BASE .. sub .. "/*", "GAME")
    for _, f in ipairs(files or {}) do
        local ext = f:lower():sub(-4)
        if ext == ".mp3" or ext == ".wav" or ext == ".ogg" then
            local rel = BASE .. sub .. "/" .. f
            table.insert(out, rel)
            resource.AddFile("sound/" .. rel)
        end
    end
    return out
end

local songs = {}

hook.Add("InitPostEntity", "PH_ScanRoundMusic", function()
    songs.innocents = scanFolder("innocents")
    songs.traitors  = scanFolder("traitors")
    print(string.format("[PH Music] Props-win songs: %d  Hunters-win songs: %d",
        #songs.innocents, #songs.traitors))
end)

util.AddNetworkString("ph_end_round_music")

local function readSidecar(relPath)
    local songName, band = "", ""
    local txtPath = "sound/" .. relPath:sub(1, -5) .. ".txt"
    if file.Exists(txtPath, "GAME") then
        local raw = file.Read(txtPath, "GAME") or ""
        local lines = string.Explode("\n", raw)
        songName = string.Trim(lines[1] or "")
        band     = string.Trim(lines[2] or "")
    end
    return songName, band
end

-- Silence PHX2's built-in win jingle so our music plays instead.
-- PHX:PlayWinningSound broadcasts PH_TeamWinning_Snd; replacing it with a
-- no-op prevents the short win stinger from competing with our track.
hook.Add("InitPostEntity", "PH_DisablePHXWinSound", function()
    if PHX then
        PHX.PlayWinningSound = function() end
    end
end)

hook.Add("PH_RoundEndResult", "PH_PlayEndRoundMusic", function(result)
    local roleKey
    if     result == TEAM_PROPS   then roleKey = "innocents"
    elseif result == TEAM_HUNTERS then roleKey = "traitors"
    else return end

    local pool = songs[roleKey]
    if not pool or #pool == 0 then
        print("[PH Music] No songs found for roleKey=" .. roleKey)
        return
    end

    local chosen           = pool[math.random(#pool)]
    local songName, band   = readSidecar(chosen)

    net.Start("ph_end_round_music")
        net.WriteString(chosen)
        net.WriteString(songName)
        net.WriteString(band)
        net.WriteString(roleKey)
    net.Broadcast()
end)
