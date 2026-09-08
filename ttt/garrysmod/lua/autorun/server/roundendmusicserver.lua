--[[
    Written by 4tla2
    Modified by Sc00by
    Using the Unlicense
    https://unlicense.org
]]

if SERVER then
    local SystemType = package.config:sub(1,1)
    CreateConVar("ttt_end_random_music_wintype", 1, FCVAR_SERVER_CAN_EXECUTE, "Enable if you want teamspecific win music at the end of the round", 0, 1)
    CreateConVar("ttt_end_random_music_silentscan", 1, FCVAR_SERVER_CAN_EXECUTE, "Enable if you don't want to the Addon to print all found files out after Roundend", 0, 1)
    CreateConVar("ttt_end_random_music_source", 1, FCVAR_REPLICATED, "Switches search place from data/ to sound/. Use only if you know, what you do", 0, 1)
    CreateConVar("ttt_end_random_music_timeout_not_innocent", 0, FCVAR_SERVER_CAN_EXECUTE, "Enable if you don't want that timeouts count to innocents winnings", 0, 1)
    util.AddNetworkString("ttt_end_random_music")

    if (SystemType == "/") then
        print("[End_Random_Music] OS check successful: Using Unixlike OS.")
    elseif (SystemType == "\\") then
        print("[End_Random_Music] OS check successful: Using Windows.")
    else
        print("[End_Random_Music] Error: Couldn't determine your OS.")
    end

    print("[End_Random_Music] Hello TTT2. Nice to meet you.")
    CreateConVar("ttt_end_random_music_branch", 1, FCVAR_REPLICATED, "Branch", 0, 1)
    branch = "ttt2"
    print("[End_Random_Music] Checking for other TTT2 Roles:")
    ttt2jester_true      = 1
    ttt2marker_true      = 1
    ttt2pirate_true      = 1
    ttt2necromancer_true = 1
    ttt2serialkiller_true = 1
    print("[End_Random_Music] Found Jester, Marker, Pirate, Necromancer, Serialkiller")

    -- All team-win music folders (role-keyed by the winning team string TTT2 passes to TTTEndRound)
    local ROLE_FOLDERS = {
        "innocents", "traitors", "timeout",
        "jesters", "markers", "pirates", "necromancers", "serialkillers",
        "redteams", "blueteams", "ffas",
        "other",
    }

    -- All special-round mode IDs (mirrors SPECIAL_MODES in sv_special_rounds.lua)
    local SPECIAL_ROUND_IDS = {
        "knife_round", "chaos", "crowbar_ffa", "oops_all_zombies",
        "low_grav", "slow_mo", "tiny", "speed", "bhop", "superman",
        "screw_jump", "exploding_props",
    }

    -- Print all loaded tracks on server start
    hook.Add("Initialize", "End_Random_Music_PrintSongs", function()
        local searchPath = GetConVar("ttt_end_random_music_source"):GetString() == "0" and "DATA" or "GAME"
        local fp        = searchPath == "DATA" and "music/" or "sound/music/"

        print("[End_Random_Music] Songs loaded per role:")
        for _, folder in ipairs(ROLE_FOLDERS) do
            local t = file.Find(fp .. "end_random_music/" .. folder .. "/*.mp3", searchPath)
            if t and #t > 0 then
                print(string.format("  %-14s (%d): %s", folder, #t, table.concat(t, ", ")))
            end
        end

        print("[End_Random_Music] Songs loaded per special round:")
        for _, modeId in ipairs(SPECIAL_ROUND_IDS) do
            local t = file.Find(fp .. "end_random_music/special_rounds/" .. modeId .. "/*.mp3", searchPath)
            if t and #t > 0 then
                print(string.format("  special/%s (%d): %s", modeId, #t, table.concat(t, ", ")))
            end
        end
    end)

    function roundend(wintype)
        local searchPath = GetConVar("ttt_end_random_music_source"):GetString() == "0" and "DATA" or "GAME"
        local filePath   = searchPath == "DATA" and "music/" or "sound/music/"

        print("[End_Random_Music] DEBUG: wintype is:", wintype, "type:", type(wintype))

        -- Determine role key (the winning team string, or "timeout")
        local roleKey = tostring(wintype)
        if wintype == WIN_TIMELIMIT then
            roleKey = "timeout"
        end

        if GetConVar("ttt_end_random_music_wintype"):GetString() == "0" then
            -- Unspecific mode: pool all role folders and pick randomly
            local pool = {}
            for _, folder in ipairs(ROLE_FOLDERS) do
                local t = file.Find(filePath .. "end_random_music/" .. folder .. "/*.mp3", searchPath)
                if t then
                    for _, f in ipairs(t) do
                        table.insert(pool, folder .. "/" .. f)
                    end
                end
            end

            if pool and #pool > 0 then
                math.randomseed(os.time())
                local chosen = pool[math.random(#pool)]
                net.Start("ttt_end_random_music")
                    net.WriteString(chosen)
                    net.WriteString(string.StripExtension(chosen))
                    net.WriteString("")
                    net.WriteString("")
                net.Broadcast()
            else
                print("[End_Random_Music] Error: No files to play")
            end

        elseif GetConVar("ttt_end_random_music_wintype"):GetString() == "1" then
            print("[End_Random_Music] Custom wintype (role-based music selection)")

            -- 1. Check for a special-round-specific track first
            local specialModeId = sc0b_GetLastRoundModeID and sc0b_GetLastRoundModeID() or nil
            local specialFiles  = nil
            local specialFolder = nil

            if specialModeId then
                local srPath = filePath .. "end_random_music/special_rounds/" .. specialModeId .. "/*.mp3"
                local found  = file.Find(srPath, searchPath)
                if found and #found > 0 then
                    specialFiles  = found
                    specialFolder = "special_rounds/" .. specialModeId
                    print("[End_Random_Music] Found " .. #found .. " special-round track(s) for: " .. specialModeId)
                end
            end

            -- 2. Fall back to the winning-team folder if no special-round music
            local musicTable, musicFolder
            if specialFiles then
                musicTable  = specialFiles
                musicFolder = specialFolder
            else
                musicTable  = file.Find(filePath .. "end_random_music/" .. roleKey .. "/*.mp3", searchPath)
                musicFolder = roleKey
                -- Last-resort fallback: other/
                if not musicTable or #musicTable == 0 then
                    musicTable  = file.Find(filePath .. "end_random_music/other/*.mp3", searchPath)
                    musicFolder = "other"
                end
            end

            if musicTable and #musicTable > 0 then
                math.randomseed(os.time())
                local musicTitle = math.random(#musicTable)
                local chosenFile = musicTable[musicTitle]
                local chosenMusic = string.lower("sound/music/end_random_music/" .. musicFolder .. "/" .. chosenFile)

                local baseName = string.StripExtension(chosenFile)
                local txtPath  = filePath .. "end_random_music/" .. musicFolder .. "/" .. baseName .. ".txt"
                local pngPath  = string.lower("materials/music/end_random_music/" .. musicFolder .. "/" .. baseName .. ".png")

                local songName, band = baseName, ""
                if file.Exists(txtPath, searchPath) then
                    local lines = string.Explode("\n", file.Read(txtPath, searchPath))
                    songName = lines[1] or songName
                    band     = lines[2] or ""
                end

                local hasImage = file.Exists(pngPath, searchPath)

                print("[End_Random_Music] DEBUG: Sending music info to clients:")
                print("  Folder: " .. musicFolder)
                print("  Chosen file: " .. chosenMusic)
                print("  Song name: " .. songName)
                print("  Band: " .. band)
                print("  PNG exists: " .. tostring(hasImage))

                net.Start("ttt_end_random_music")
                    net.WriteString(chosenMusic)
                    net.WriteString(songName)
                    net.WriteString(band)
                    net.WriteString(hasImage and pngPath or "")
                    net.WriteString(musicFolder)
                    print("[End_Random_Music] Broadcasting music info to clients!")
                net.Broadcast()
            else
                print("[End_Random_Music] Error: No files to play for role " .. roleKey)
            end
        else
            print("[End_Random_Music] Error: ConVar is out of acceptable Range. It should be 0 or 1.")
        end
    end

    hook.Add("TTTEndRound", "lul", roundend)

    concommand.Add("ttt_endroundmusic_reloadstart", function() end)
end
