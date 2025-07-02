if not CLIENT then return end

local fullSoundList = {}
local receivedSounds = false
local playingEmitter = nil

net.Receive("SoundBrowser_PlaySound", function()
    local snd = net.ReadString()
    local vol = net.ReadFloat()
    local pit = net.ReadFloat()
    surface.PlaySound(snd)
end)

net.Receive("SoundBrowser_SendList", function()
    local count = net.ReadUInt(16)
    for i = 1, count do
        local snd = net.ReadString()
        if snd and snd ~= "" then
            table.insert(fullSoundList, snd)
        end
    end

    -- Mark done only after a few packets? For now just sort every time
    table.sort(fullSoundList)
    receivedSounds = true
end)

hook.Add("InitPostEntity", "SoundBrowser_RequestList", function()
    net.Start("SoundBrowser_RequestList")
    net.SendToServer()
end)

local function FindSounds(dir, fileTable)
    fileTable = fileTable or {}
    local files, dirs = file.Find("sound/" .. dir .. "/*", "GAME")

    for _, f in ipairs(files) do
        if f:find("%.wav$") or f:find("%.mp3$") or f:find("%.ogg$") then
            table.insert(fileTable, dir .. "/" .. f)
        end
    end

    for _, d in ipairs(dirs) do
        FindSounds(dir .. "/" .. d, fileTable)
    end

    return fileTable
end

local function OpenSoundBrowser()
    local frame = vgui.Create("DFrame")
    frame:SetTitle("🎧 Sound Browser")
    frame:SetSize(700, 500)
    frame:Center()
    frame:MakePopup()
    frame:SetBackgroundBlur(false)

    -- cool dark theme
    frame.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(20, 25, 35, 245))
    end

    local volume = 1.0
    local pitch = 100
    local selectedSound = nil
    if not receivedSounds then
        notification.AddLegacy("Waiting for sound list from server...", NOTIFY_HINT, 5)
        return
    end

    local searchBox = vgui.Create("DTextEntry", frame)
    searchBox:Dock(TOP)
    searchBox:SetPlaceholderText("Filter sounds...")
    searchBox:SetTextColor(Color(220, 220, 255))
    searchBox:SetPaintBackground(true)
    searchBox.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 50, 70, 230))
        self:DrawTextEntryText(Color(240, 240, 255), Color(120, 120, 255), Color(255, 255, 255))
    end

    local soundList = vgui.Create("DListView", frame)
    soundList:Dock(FILL)
    soundList:SetMultiSelect(false)
    soundList:AddColumn("Sound File")

    local function RefreshList(filter)
        soundList:Clear()
        for _, snd in ipairs(fullSoundList) do
            if not filter or snd:lower():find(filter:lower(), 1, true) then
                soundList:AddLine(snd)
            end
        end
    end

    searchBox.OnChange = function(self)
        local text = self:GetValue()
        RefreshList(text)
    end

    RefreshList(nil)

    soundList.OnRowSelected = function(_, _, row)
        selectedSound = row:GetColumnText(1)
    end

    local controls = vgui.Create("DPanel", frame)
    controls:Dock(BOTTOM)
    controls:SetTall(110)
    controls:SetBackgroundColor(Color(15, 20, 30))

    -- Volume slider
    local volSlider = vgui.Create("DNumSlider", controls)
    volSlider:SetMin(0)
    volSlider:SetMax(1)
    volSlider:SetDecimals(2)
    volSlider:SetText("> Volume (0.0 - 1.0)")
    volSlider:SetValue(volume)
    volSlider:Dock(TOP)
    volSlider.Label:SetTextColor(Color(180, 200, 255))
    volSlider.Slider.Knob:SetColor(Color(100, 150, 255))
    -- volSlider.Slider:SetSlideColor(Color(50, 80, 120))
    volSlider.OnValueChanged = function(_, val)
        volume = val
    end

    -- Pitch slider
    local pitchSlider = vgui.Create("DNumSlider", controls)
    pitchSlider:SetMin(0)
    pitchSlider:SetMax(255)
    pitchSlider:SetDecimals(0)
    pitchSlider:SetText("> Pitch (0 - 255)")
    pitchSlider:SetValue(pitch)
    pitchSlider:Dock(TOP)
    pitchSlider.Label:SetTextColor(Color(180, 200, 255))
    pitchSlider.Slider.Knob:SetColor(Color(100, 150, 255))
    -- pitchSlider.Slider:SetSlideColor(Color(50, 80, 120))
    pitchSlider.OnValueChanged = function(_, val)
        pitch = val
    end

    local btnPanel = vgui.Create("DPanel", controls)
    btnPanel:Dock(BOTTOM)
    btnPanel:SetTall(35)
    btnPanel:SetBackgroundColor(Color(10, 15, 25))

    local playBtn = vgui.Create("DButton", btnPanel)
    playBtn:Dock(LEFT)
    playBtn:SetWide(120)
    playBtn:SetText("▶ Play")
    playBtn:SetFont("DermaLarge")
    playBtn:SetTextColor(Color(255, 255, 255))
    playBtn.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(30, 150, 100, 220))
    end
        
    playBtn.DoClick = function()
        if not selectedSound then return end

        net.Start("SoundBrowser_PlaySound")
            net.WriteString(selectedSound or "")
            net.WriteFloat(volume)
            net.WriteFloat(pitch)
            net.WriteBool(false) -- not stopping
        net.SendToServer()
    --     if not selectedSound then return end
    --     net.Start("SoundBrowser_PlaySound")
    --         net.WriteString(selectedSound)
    --         net.WriteFloat(volume)
    --         net.WriteFloat(pitch)
    --     net.SendToServer()
    end

    local stopBtn = vgui.Create("DButton", btnPanel)
    stopBtn:Dock(LEFT)
    stopBtn:SetWide(120)
    stopBtn:SetText("⏹ Stop")
    stopBtn:SetFont("DermaLarge")
    stopBtn:SetTextColor(Color(255, 255, 255))
    stopBtn.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(150, 50, 50, 220))
    end
    stopBtn:DockMargin(10, 0, 0, 0)
        
    stopBtn.DoClick = function()
        if not IsValid(LocalPlayer()) then return end
        net.Start("SoundBrowser_PlaySound")
            net.WriteString("") -- not needed
            net.WriteFloat(0)
            net.WriteFloat(0)
            net.WriteBool(true) -- STOP flag
        net.SendToServer()
    --     if not IsValid(LocalPlayer()) then return end
    --     sound.Play("common/null.wav", LocalPlayer():GetPos())
    end
end

concommand.Add("open_sound_browser", OpenSoundBrowser)