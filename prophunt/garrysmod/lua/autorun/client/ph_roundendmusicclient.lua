-- ph_roundendmusicclient.lua
-- Receives round-end music from the server and plays it locally.
if not CLIENT then return end

-- Override PHX2's round-end win jingle receiver so it never plays.
-- PHX2 sends PH_TeamWinning_Snd; registering a no-op here replaces their handler.
net.Receive("PH_TeamWinning_Snd", function() end)

local activeStation = nil

local function stopMusic()
    if IsValid(activeStation) then
        activeStation:Stop()
        activeStation = nil
    end
end

-- Stop previous song when a new round begins
hook.Add("PH_RoundStart",   "PH_StopRoundMusic", stopMusic)
hook.Add("PH_OnRoundStart", "PH_StopRoundMusic", stopMusic)

local ROLE_COLORS = {
    innocents = Color(50, 200, 50),  -- props win
    traitors  = Color(240, 80, 80),  -- hunters win
}

local WINNER_LABEL = {
    innocents = "Props win",
    traitors  = "Hunters win",
}

net.Receive("ph_end_round_music", function()
    local path     = net.ReadString()
    local songName = net.ReadString()
    local band     = net.ReadString()
    local roleKey  = net.ReadString()

    stopMusic()

    local function onLoaded(snd, errCode, errName)
        if errCode ~= 0 then
            MsgN("[PH Music] Playback error for '" .. path .. "': " .. tostring(errName))
            return
        end
        activeStation = snd
        snd:SetVolume(1)
        snd:Play()
    end

    if path:sub(1, 4) == "http" then
        sound.PlayURL(path, "noplay", onLoaded)
    else
        sound.PlayFile(path, "noplay", onLoaded)
    end

    -- Chat notification
    local col    = ROLE_COLORS[roleKey]  or Color(255, 255, 255)
    local label  = WINNER_LABEL[roleKey] or "Round over"
    if songName ~= "" then
        chat.AddText(
            Color(180, 180, 180), "[End Round] ",
            col, label .. "! ",
            Color(255, 215, 0), "\u{266B} " .. songName,
            Color(180, 180, 180), band ~= "" and (" by " .. band) or ""
        )
    end
end)
