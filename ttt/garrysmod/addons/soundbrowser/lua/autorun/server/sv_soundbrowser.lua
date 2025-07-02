if SERVER then
    util.AddNetworkString("SoundBrowser_PlaySound")
    util.AddNetworkString("SoundBrowser_RequestList")
    util.AddNetworkString("SoundBrowser_SendList")
end

local function FindSoundsOnServer(dir, fileTable)
    fileTable = fileTable or {}
    local files, dirs = file.Find("sound/" .. dir .. "/*", "GAME")

    for _, f in ipairs(files) do
        if f:find("%.wav$") or f:find("%.mp3$") or f:find("%.ogg$") then
            local fullPath = dir .. "/" .. f
            if #fullPath > 0 and not fullPath:find("//") then
                table.insert(fileTable, fullPath)
            end
        end
    end

    for _, d in ipairs(dirs) do
        FindSoundsOnServer(dir .. "/" .. d, fileTable)
    end

    return fileTable
end

net.Receive("SoundBrowser_RequestList", function(_, ply)
    local sounds = FindSoundsOnServer("")
    table.sort(sounds)

    -- Send in multiple chunks if needed
    local maxPerPacket = 300  -- tune as needed
    local index = 1

    while index <= #sounds do
        local endIndex = math.min(index + maxPerPacket - 1, #sounds)
        local count = endIndex - index + 1

        net.Start("SoundBrowser_SendList")
            net.WriteUInt(count, 16)
            for i = index, endIndex do
                net.WriteString(sounds[i])
            end
        net.Send(ply)

        index = endIndex + 1
    end
end)

net.Receive("SoundBrowser_PlaySound", function(_, ply)
    local path = net.ReadString()
    local vol = net.ReadFloat()
    local pit = net.ReadFloat()
    local shouldStop = net.ReadBool()

    if shouldStop then
        if IsValid(ply.LastSoundEnt) then
            ply.LastSoundEnt:Fire("StopSound", "", 0)
            ply.LastSoundEnt:Remove()
            ply.LastSoundEnt = nil
        end
        return
    end

    if not isstring(path) or #path == 0 or #path > 200 then return end
    if vol < 0 or vol > 1 then vol = 1 end
    if pit < 0 or pit > 255 then pit = 100 end

    -- Kill old sound entity if exists
    if IsValid(ply.LastSoundEnt) then
        ply.LastSoundEnt:Remove()
        ply.LastSoundEnt = nil
    end

    -- Create ambient_generic sound entity
    local ent = ents.Create("ambient_generic")
    if not IsValid(ent) then return end
    ent:SetPos(ply:GetPos())
    ent:SetKeyValue("message", path)
    ent:SetKeyValue("health", "10")
    ent:SetKeyValue("pitch", tostring(pit))
    ent:SetKeyValue("spawnflags", "49") -- Play Everywhere + Start Silent + Is NOT Looping
    ent:SetKeyValue("volume", tostring(vol))
    ent:Spawn()
    ent:Activate()
    ent:Fire("PlaySound", "", 0)

    ply.LastSoundEnt = ent
end)

-- net.Receive("SoundBrowser_PlaySound", function(_, ply)
--     local path = net.ReadString()
--     local vol = net.ReadFloat()
--     local pit = net.ReadFloat()

--     if not isstring(path) or #path == 0 or #path > 200 then return end
--     if vol < 0 or vol > 1 then vol = 1 end
--     if pit < 0 or pit > 255 then pit = 100 end

--     sound.Play(path, ply:GetPos(), 75, pit, vol)
-- end)