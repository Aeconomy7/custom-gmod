--[[
    Written by 4tla2
    Modified by Sc00by
    Using the Unlicense
    https://unlicense.org
]]

if SERVER then
    -- AddCSLuaFile("autorun/client/cl_roundendmusicserver.lua")
    -- print("[RoundEndMusic DEBUG] cl_roundendmusicserver.lua loaded!")

    --Init basic stuff
    local SystemType = package.config:sub(1,1)
    CreateConVar("ttt_end_random_music_wintype", 1, FCVAR_SERVER_CAN_EXECUTE, "Enable if you want teamspecific win music at the end of the round", 0, 1)
    CreateConVar("ttt_end_random_music_silentscan", 1, FCVAR_SERVER_CAN_EXECUTE, "Enable if you don't want to the Addon to print all found files out after Roundend", 0, 1)
    CreateConVar("ttt_end_random_music_source", 1, FCVAR_REPLICATED, "Switches search place from data/ to sound/. Use only if you know, what you do", 0, 1)
    CreateConVar("ttt_end_random_music_timeout_not_innocent", 0, FCVAR_SERVER_CAN_EXECUTE, "Enable if you don't want that timeouts count to innocents winnings", 0, 1)
    util.AddNetworkString("ttt_end_random_music")

    --On Boot
    if (SystemType == "/") then --Check OS Type
        print ("[End_Random_Music] OS check successful: Using Unixlike OS.")
    elseif (SystemType == "\\") then
        print ("[End_Random_Music] OS check successful: Using Windows.")
    else
        print ("[End_Random_Music] Error: Couldn't determine your OS.")
    end
    if (true) then -- Override check for TTT2 since addons are not mounted normally
        print("[End_Random_Music] Hello TTT2. Nice to meet you.")
        CreateConVar("ttt_end_random_music_branch", 1, FCVAR_REPLICATED, "Branch", 0, 1)
        branch = "ttt2"
        print("[End_Random_Music] Checking for other TTT2 Roles:")
        -- if (string.find(table.ToString(engine.GetAddons(), "modliste", true), "1392362130", 1) != nil) then --Check for Jackal
        --     ttt2jackal_true = 1
        --     print ("[End_Random_Music] Found Jackal")
        -- end
        -- if (string.find(table.ToString(engine.GetAddons(), "modliste", true), "1371842074", 1) != nil) then --Check for Infected
        --     ttt2infected_true = 1
        --     print ("[End_Random_Music] Found Infected")
        -- end
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
        -- if (string.find(table.ToString(engine.GetAddons(), "modliste", true), "2487229784", 1) != nil) then --Check for Hidden
        --     ttt2hidden_true = 1
        --     print ("[End_Random_Music] Found Hidden")
        -- end
    else
        branch = "ttt"
        CreateConVar("ttt_end_random_music_branch", 0, FCVAR_REPLICATED, "Branch", 0, 1)
        if (string.find(table.ToString(engine.GetAddons(), "modliste", true), "2045444087", 1) != nil) then --Check for modified version of Custom Roles for TTT
            ttt_custom_roles_true = 1
            print ("[End_Random_Music] Found modified version of Custom Roles for TTT")
        elseif (string.find(table.ToString(engine.GetAddons(), "modliste", true), "1215502383", 1) != nil) then --Check for Custom Roles for TTT
            ttt_custom_roles_true = 1
            print ("[End_Random_Music] Found Custom Roles for TTT")
        end
    end

    //Foldercheck
    if (GetConVar("ttt_end_random_music_source"):GetString() == "0") then
        print ("[End_Random_Music] Folder check enabled (ConVar ttt_end_random_music_source = 0).")
        if (file.Exists("music/end_random_music/innocents" , "DATA") && file.Exists("music/end_random_music/traitors" , "DATA") && file.Exists("music/end_random_music/other" , "DATA")) then --Check for folder
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
            if (file.Exists("music/end_random_music/timeout" , "DATA")) then --Check for folder
                print ("[End_Random_Music] Timeout folder check successful.")
            else
                print ("[End_Random_Music] Timeout folder check failed. Creating missing folder.")
                file.CreateDir("music/end_random_music/timeout")
            end
        end
        if (branch == "ttt2") then
            if (ttt2jester_true == 1) then
                if (file.Exists("music/end_random_music/jesters", "DATA")) then
                    print ("[End_Random_Music] Found Jester folder.")
                else
                    print ("[End_Random_Music] Missing Jester folder. Creating...")
                    file.CreateDir("music/end_random_music/jesters")
                end
            end
            if (ttt2marker_true == 1) then
                if (file.Exists("music/end_random_music/markers", "DATA")) then
                    print ("[End_Random_Music] Found Marker folder.")
                else
                    print ("[End_Random_Music] Missing Marker folder. Creating...")
                    file.CreateDir("music/end_random_music/markers")
                end
            end
            if (ttt2pirate_true == 1) then
                if (file.Exists("music/end_random_music/pirates", "DATA")) then
                    print ("[End_Random_Music] Found Pirate folder.")
                else
                    print ("[End_Random_Music] Missing Pirate folder. Creating...")
                    file.CreateDir("music/end_random_music/pirates")
                end
            end
            if (ttt2necromancer_true == 1) then
                if (file.Exists("music/end_random_music/necromancers", "DATA")) then
                    print ("[End_Random_Music] Found Necromancer folder.")
                else
                    print ("[End_Random_Music] Missing Necromancer folder. Creating...")
                    file.CreateDir("music/end_random_music/necromancers")
                end
            end
            if (ttt2serialkiller_true == 1) then
                if (file.Exists("music/end_random_music/serialkillers", "DATA")) then
                    print ("[End_Random_Music] Found Serialkiller folder.")
                else
                    print ("[End_Random_Music] Missing Serialkiller folder. Creating...")
                    file.CreateDir("music/end_random_music/serialkillers")
                end
            end
            if (ttt2hidden_true == 1) then
                if (file.Exists("music/end_random_music/hidden", "DATA")) then
                    print ("[End_Random_Music] Found Hidden folder.")
                else
                    print ("[End_Random_Music] Missing Hidden folder. Creating...")
                    file.CreateDir("music/end_random_music/hidden")
                end
            end
        elseif (branch == ttt) then
            if (ttt_custom_roles_true == 1) then
                if (file.Exists("music/end_random_music/custom_jester", "DATA")) then
                    print ("[End_Random_Music] Found Jester folder.")
                else
                    print ("[End_Random_Music] Missing Jester folder. Creating...")
                    file.CreateDir("music/end_random_music/custom_jester")
                end
                if (file.Exists("music/end_random_music/custom_killer", "DATA")) then
                    print ("[End_Random_Music] Found Killer folder.")
                else
                    print ("[End_Random_Music] Missing Killer folder. Creating...")
                    file.CreateDir("music/end_random_music/custom_killer")
                end
                if (file.Exists("music/end_random_music/custom_monsters", "DATA")) then
                    print ("[End_Random_Music] Found Monsters folder.")
                else
                    print ("[End_Random_Music] Missing Monsters folder. Creating...")
                    file.CreateDir("music/end_random_music/custom_monsters")
                end
            end
        end
    elseif (GetConVar("ttt_end_random_music_source"):GetString() == "1") then
        print ("[End_Random_Music] No folder check performend (disabled by ConVar).")
    else
        print ("[End_Random_Music] Error with ConVar")
    end


    --The Magic
    function roundend(wintype)
        if (GetConVar("ttt_end_random_music_source"):GetString() == "0") then
            fileSearchPath = "DATA"
            filePath = "music/"
        elseif (GetConVar("ttt_end_random_music_source"):GetString() == "1") then
            fileSearchPath = "GAME"
            filePath = "sound/music/"
        else
            print ("[End_Random_Music] Error with ConVar")
        end

        print ("[End_Random_Music] DEBUG: wintype is:", wintype, "type:", type(wintype))

        --Search for files
        filesGlobal = {}
        filesInnocent = {}
        filesOther = {}
        filesTraitor = {}
        if (GetConVar("ttt_end_random_music_timeout_not_innocent"):GetString() == "1") then
            filesTimeout = {}
        end
        if (ttt2jester_true == 1) then
            filesTTT2Jester = {}
        end
        if (ttt2marker_true == 1) then
            filesTTT2Marker = {}
        end
        if (ttt2pirate_true == 1) then
            filesTTT2Pirate = {}
        end
        if (ttt2necromancer_true == 1) then
            filesTTT2Necromancer = {}
        end
        if (ttt2serialkiller_true == 1) then
            filesTTT2Serialkiller = {}
        end

        if (GetConVar("ttt_end_random_music_silentscan"):GetString() == "0") then
            print ("[End_Random_Music] Searching files:")
        end
        
        filesInnocent = file.Find(filePath .. "end_random_music/innocents/*.mp3", fileSearchPath)
        if (filesInnocent != nil) then
            for i = 1, table.getn(filesInnocent), 1 do
                table.insert(filesGlobal, "innocents/" .. filesInnocent[i])
            end
        end

        -- filesTraitor = file.Find(filePath .. "end_random_music/traitor/*.wav", fileSearchPath)
        filesTraitor = file.Find(filePath .. "end_random_music/traitors/*.mp3", fileSearchPath)
        if (filesTraitor != nil) then
            for i = 1, table.getn(filesTraitor), 1 do
                table.insert(filesGlobal, "traitors/" .. filesTraitor[i])
            end
        end

        filesTimeout = file.Find(filePath .. "end_random_music/timeout/*.mp3", fileSearchPath)
        if (filesTimeout != nil) then
            for i = 1, table.getn(filesTimeout), 1 do
                table.insert(filesGlobal, "timeout/" .. filesTimeout[i])
            end
        end
        filesOther = file.Find(filePath .. "end_random_music/other/*.mp3", fileSearchPath)
        if (filesOther != nil) then
            for i = 1, table.getn(filesOther), 1 do
                table.insert(filesGlobal, "other/" .. filesOther[i])
            end
        end
        if (file.Exists(filePath .. "end_random_music/jesters", fileSearchPath)) then
            filesTTT2Jester = file.Find(filePath .. "end_random_music/jesters/*.mp3", fileSearchPath)
            if (filesTTT2Jester != nil) then
                for i = 1, table.getn(filesTTT2Jester), 1 do
                    table.insert(filesGlobal, "jesters/" .. filesTTT2Jester[i])
                end
            end
        end
        if (file.Exists(filePath .. "end_random_music/markers", fileSearchPath)) then
            filesTTT2Marker = file.Find(filePath .. "end_random_music/markers/*.mp3", fileSearchPath)
            if (filesTTT2Marker != nil) then
                for i = 1, table.getn(filesTTT2Marker), 1 do
                    table.insert(filesGlobal, "markers/" .. filesTTT2Marker[i])
                end
            end
        end
        if (file.Exists(filePath .. "end_random_music/pirates", fileSearchPath)) then
            filesTTT2Pirate = file.Find(filePath .. "end_random_music/pirates/*.mp3", fileSearchPath)
            if (filesTTT2Pirate != nil) then
                for i = 1, table.getn(filesTTT2Pirate), 1 do
                    table.insert(filesGlobal, "pirates/" .. filesTTT2Pirate[i])
                end
            end
        end
        if (file.Exists(filePath .. "end_random_music/necromancers", fileSearchPath)) then
            filesTTT2Necromancer = file.Find(filePath .. "end_random_music/necromancers/*.mp3", fileSearchPath)
            if (filesTTT2Necromancer != nil) then
                for i = 1, table.getn(filesTTT2Necromancer), 1 do
                    table.insert(filesGlobal, "necromancers/" .. filesTTT2Necromancer[i])
                end
            end
        end
        if (file.Exists(filePath .. "end_random_music/serialkillers", fileSearchPath)) then
            filesTTT2Serialkiller = file.Find(filePath .. "end_random_music/serialkillers/*.mp3", fileSearchPath)
            if (filesTTT2Serialkiller != nil) then
                for i = 1, table.getn(filesTTT2Serialkiller), 1 do
                    table.insert(filesGlobal, "serialkillers/" .. filesTTT2Serialkiller[i])
                end
            end
        end

        -- report on music scan
        if (GetConVar("ttt_end_random_music_silentscan"):GetString() == "0") then
            if (filesGlobal != nil) then
                for i = 1, table.getn(filesGlobal), 1 do
                    print ("[End_Random_Music] Found " .. filesGlobal[i])
                end
            end
        end


        --Shuffel and send info to client
        if (filesGlobal != nil) then
            --Unspecific wintype
            if (GetConVar("ttt_end_random_music_wintype"):GetString() == "0") then
                if filesGlobal and #filesGlobal > 0 then
                    math.randomseed(os.time())
                    local musicTitle = math.random(#filesGlobal)
                    local chosenMusic = filesGlobal[musicTitle]

                    -- Default metadata
                    local baseName = string.StripExtension(chosenMusic)
                    local songName = baseName
                    local band = ""
                    local pngPath = ""

                    net.Start("ttt_end_random_music")
                        net.WriteString(chosenMusic)
                        net.WriteString(songName)
                        net.WriteString(band)
                        net.WriteString(pngPath)
                    net.Broadcast()
                else
                    print("[End_Random_Music] Error: No files to play")
                end

            --Custom Wintype
            elseif (GetConVar("ttt_end_random_music_wintype"):GetString() == "1") then
                print("[End_Random_Music] Custom wintype (role-based music selection)")

                local roleKey = tostring(wintype)

                local roleMusicTable = {
                    ["innocents"] = filesInnocent,
                    ["traitors"] = filesTraitor,
                    ["jesters"] = filesTTT2Jester,
                    ["markers"] = filesTTT2Marker,
                    ["pirates"] = filesTTT2Pirate,
                    ["necromancers"] = filesTTT2Necromancer,
                    ["serialkillers"] = filesTTT2Serialkiller,
                    ["hiddens"] = filesTTT2Hidden,
                    ["other"] = filesOther
                }

                -- print("[End_Random_Music] DEBUG: Role "  .. roleKey .. " table contents: " .. table.ToString(roleMusicTable, "roleMusicTable", true))

                local musicTable = roleMusicTable[roleKey] or filesOther

                if musicTable and #musicTable > 0 then
                    for n = 0, 10 do
                        math.randomseed(os.time())
                        musicTitle = math.random(#musicTable)
                    end
                    local chosenMusic = string.lower("sound/music/end_random_music/" .. roleKey .. "/" .. musicTable[musicTitle])
                    -- Calculate base name for .txt and .png
                    local baseName = string.StripExtension(musicTable[musicTitle])
                    local txtPath = filePath .. "end_random_music/" .. roleKey .. "/" .. baseName .. ".txt"
                    local pngPath = string.lower("materials/music/end_random_music/" .. roleKey .. "/" .. baseName .. ".png")
                    
                    local songName, band = baseName, ""
                    if file.Exists(txtPath, fileSearchPath) then
                        local lines = string.Explode("\n", file.Read(txtPath, fileSearchPath))
                        songName = lines[1] or songName
                        band = lines[2] or ""
                    end

                    local hasImage = file.Exists(pngPath, fileSearchPath)

                    -- Debug output
                    print("[End_Random_Music] DEBUG: Sending music info to clients:")
                    print("  Role: " .. roleKey)
                    print("  Chosen file: " .. chosenMusic)
                    print("  Song name: " .. songName)
                    print("  Band: " .. band)
                    print("  PNG exists: " .. tostring(hasImage))
                    print("  PNG path: " .. (hasImage and pngPath or "none"))

                    net.Start("ttt_end_random_music")
                        net.WriteString(chosenMusic)
                        net.WriteString(songName)
                        net.WriteString(band)
                        net.WriteString(hasImage and pngPath or "")
                        net.WriteString(roleKey)
                        print("[End_Random_Music] Broadcasting music info to clients!")
                    net.Broadcast()
                else
                    print("[End_Random_Music] Error: No files to play for role " .. roleKey)
                end
            --Error ConVar
            else
                print ("[End_Random_Music] Error: ConVar is out of acceptable Range. It should be 0 or 1.")
            end
        else
            print ("[End_Random_Music] Error: No files provided to load.")
        end
    end
    --Programm itself
    hook.Add("TTTEndRound","lul", roundend)


    --Debug: Will be removed in future releases
    --Reload Start
    concommand.Add("ttt_endroundmusic_reloadstart", function()

    end)
end
