--[[
    Written by 4tla2 modified by Sc00by
    Using the Unlicense
    https://unlicense.org
]]
surface.CreateFont("Impact24", {
    font = "Impact",
    size = 24,
    weight = 600,
    antialias = true,
    extended = true
})

local roleColors = {
    ["innocents"]     = Color(0, 170, 45),      -- Bright green
    ["traitors"]      = Color(220, 40, 40),     -- Readable red
    ["necromancers"]  = Color(160, 60, 255),    -- Purple
    ["jesters"]       = Color(255, 80, 180),    -- Pink
    ["markers"]       = Color(200, 120, 255),   -- Lighter purple
    ["pirates"]       = Color(255, 200, 40),    -- Gold/yellow
    ["serialkillers"] = Color(0, 105, 148),   -- White
    ["other"]         = Color(180, 180, 180)    -- Neutral gray
}

if CLIENT then
    CreateConVar("ttt_end_random_music_enabled", 1, FCVAR_ARCHIVE, "Enable/disable end round music for yourself", 0, 1)
    CreateConVar("ttt_end_random_music_source", 1, FCVAR_REPLICATED, "Switches search place from data/ to sound/", 0, 1)
    CreateConVar("ttt_end_random_music_branch", 1, FCVAR_REPLICATED, "Branch", 0, 1)
    CreateConVar("ttt_end_random_music_timeout_not_innocent", 0, FCVAR_REPLICATED, "If a roundend via timeout should count as its own wintype", 0, 1)
    //if (SystemType == "/") then --Check OS Type
    //    print ("[End_Random_Music] OS check successful: Using Unixlike OS.")
    //elseif (SystemType == "\\") then
    //    print ("[End_Random_Music] OS check successful: Using Windows.")
    //else
    //    print ("[End_Random_Music] Error: Couldn't determine your OS.")
    //end
    if (GetConVar("ttt_end_random_music_branch"):GetString() == "1") then
        branch = ttt2
    elseif (GetConVar("ttt_end_random_music_branch"):GetString() == "0") then
        branch = ttt
    end

    if (true) then --Check for Jester
            ttt2jester_true = 1
            print ("[End_Random_Music] Found Jester")
    end
    if (true) then --Check for Marker
        ttt2marker_true = 1
        print ("[End_Random_Music] Found Marker")
    end
    if (true) then --Check for Pirate
        ttt2pirate_true = 1
        print ("[End_Random_Music] Found Pirate")
    end
    if (true) then --Check for Necromancer
        ttt2necromancer_true = 1
        print ("[End_Random_Music] Found Necromancer")
    end
    if (true) then --Check for Serialkiller
        ttt2serialkiller_true = 1
        print ("[End_Random_Music] Found Serialkiller")
    end


    if (file.Exists("music/end_random_music/innocents" , "GAME") && file.Exists("music/end_random_music/traitors" , "GAME") && file.Exists("music/end_random_music/other" , "GAME")) then --Check for folder
        print ("[End_Random_Music] Basic folder check successful.")
        print ("[End_Random_Music] Checking for extra folders.")
    else
        print ("[End_Random_Music] Basic folder check failed. Creating missing folders.");
        file.CreateDir("music/end_random_music/innocents");
        file.CreateDir("music/end_random_music/traitors");
        file.CreateDir("music/end_random_music/other");
        print ("[End_Random_Music] Checking for extra folders.")
    end
    if (GetConVar("ttt_end_random_music_timeout_not_innocent"):GetString() == "1") then
        if (file.Exists("music/end_random_music/timeout" , "GAME")) then
            print ("[End_Random_Music] Timeout folder check successful.")
        else
            print ("[End_Random_Music] Timeout folder check failed. Creating missing folder.");
            file.CreateDir("music/end_random_music/timeout");
        end
    end
    if (branch == "ttt2") then
        if (ttt2jester_true == 1) then
            if (file.Exists("music/end_random_music/jesters", "GAME")) then
                print ("[End_Random_Music] Found Jester folder.")
            else
                print ("[End_Random_Music] Missing Jester folder. Creating...")
                file.CreateDir("music/end_random_music/jesters")
            end
        end
        if (ttt2marker_true == 1) then
            if (file.Exists("music/end_random_music/markers", "GAME")) then
                print ("[End_Random_Music] Found Marker folder.")
            else
                print ("[End_Random_Music] Missing Marker folder. Creating...")
                file.CreateDir("music/end_random_music/markers")
            end
        end
        if (ttt2pirate_true == 1) then
            if (file.Exists("music/end_random_music/pirates", "GAME")) then
                print ("[End_Random_Music] Found Pirate folder.")
            else
                print ("[End_Random_Music] Missing Pirate folder. Creating...")
                file.CreateDir("music/end_random_music/pirates")
            end
        end
        if (ttt2necromancer_true == 1) then
            if (file.Exists("music/end_random_music/necromancers", "GAME")) then
                print ("[End_Random_Music] Found Necromancer folder.")
            else
                print ("[End_Random_Music] Missing Necromancer folder. Creating...")
                file.CreateDir("music/end_random_music/necromancers")
            end
        end
        if (ttt2serialkiller_true == 1) then
            if (file.Exists("music/end_random_music/serialkillers", "GAME")) then
                print ("[End_Random_Music] Found Serialkiller folder.")
            else
                print ("[End_Random_Music] Missing Serialkiller folder. Creating...")
                file.CreateDir("music/end_random_music/serialkillers")
            end
        end
    end

local musicInfo = nil
local musicInfoExpire = 0

net.Receive("ttt_end_random_music", function()
    local chosenMusic = net.ReadString()
    local songName = net.ReadString()
    local band = net.ReadString()
    local pngPath = net.ReadString()
    local roleKey = net.ReadString()
    
    if roleKey == "" then
        roleKey = "other"
    end

    if pngPath == "" then
        pngPath = "sound/music/end_random_music/unknown_song.png"
    end

    print("[RoundEndMusic DEBUG] Received net message:")
    print("  chosenMusic: " .. tostring(chosenMusic))
    print("  songName: " .. tostring(songName))
    print("  band: " .. tostring(band))
    print("  pngPath: " .. tostring(pngPath))

    musicInfo = {
        songName = songName,
        band = band,
        pngPath = pngPath,
        roleKey = roleKey
    }

    -- play the damn music
    if GetConVar("ttt_end_random_music_enabled"):GetBool() == false then
        print("[End_Random_Music] Disabled by client convar, not playing music.")
    else
        print ("[End_Random_Music] trying to play:" .. chosenMusic);
        sound.PlayFile( chosenMusic, "noplay", function( station, errCode, errStr )
        if ( IsValid( station ) ) then
            station:Play()
            else
                print( "[End_Random_Music] Error playing sound!", errCode, errStr )
            end
        end )
    end

    musicInfoExpire = CurTime() + 25
end)

hook.Add("HUDPaint", "DrawRoundEndMusicHUD", function()
    if not musicInfo or CurTime() > musicInfoExpire then return end

    local font = "Impact24"
    surface.SetFont(font)

    local prefix = "Now Playing: "
    local songStr = musicInfo.songName or "Unknown Song"
    local bandStr = musicInfo.band or ""
    local prefixW, textH = surface.GetTextSize(prefix)
    local songW = surface.GetTextSize(songStr)
    local bandW = surface.GetTextSize(bandStr)
    local albumArtW, albumArtH = 76, 76
    local padding = 12

    local screenW, screenH = ScrW(), ScrH()
    local totalW = math.max(prefixW + songW, bandW) + albumArtW + padding
    local boxX = screenW * 0.25 - (totalW / 2)
    -- local boxX = (screenW - totalW) / 2
    local boxY = screenH * 0.01
    local textY = boxY + textH / 2

    -- darker background
    draw.RoundedBox(6, boxX - 10, boxY - 5, totalW + 20, math.max(albumArtH, textH * 2 + 30), Color(10, 10, 10, 220))

    -- album art if available
    local textStartX = boxX + albumArtW + padding
    if musicInfo.pngPath ~= "" then
        local mat = Material(musicInfo.pngPath)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(mat)
        surface.DrawTexturedRect(boxX, boxY - 5, albumArtW, albumArtH)
    end

    -- white prefix
    draw.SimpleText(prefix, font, textStartX, textY, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- white outline (stroke) for song name
    local valueX = textStartX + prefixW
    local offsets = {
        {-1,  0}, {1,  0}, {0, -1}, {0, 1},
        {-1, -1}, {1, -1}, {-1, 1}, {1, 1}
    }
    for _, offset in ipairs(offsets) do
        draw.SimpleText(songStr, font, valueX + offset[1], textY + offset[2], color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- colored song text on top
    local songColor = roleColors[musicInfo.roleKey or "other"] or color_white
    draw.SimpleText(songStr, font, valueX, textY, songColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- band text below
    draw.SimpleText(bandStr, font, textStartX, textY + textH, Color(190,190,190), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- show mute status below band
    local muted = not GetConVar("ttt_end_random_music_enabled"):GetBool()
    if muted then
        draw.SimpleText("MUTED", font, textStartX, textY + textH * 2, Color(255, 80, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end)

    
end