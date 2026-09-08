include("shared.lua")

if not CLIENT then return end

local T  = LANG.GetTranslation
local PT = LANG.GetParamTranslation

local disarm_beep   = Sound("buttons/blip2.wav")
local wire_cut_snd  = Sound("ttt/wirecut.wav")

local c4_wire_mat    = Material("vgui/ttt/c4_wire")
local c4_wirecut_mat = Material("vgui/ttt/c4_wire_cut")
local c4_bomb_mat    = Material("vgui/ttt/c4_bomb")

local wire_colors = {
    Color(200, 0,   0,   255),
    Color(255, 255, 0,   255),
    Color(90,  90,  250, 255),
    Color(255, 255, 255, 255),
    Color(20,  200, 20,  255),
    Color(255, 160, 50,  255),
}

surface.CreateFont("C4Timer_PD", {
    font   = "TabLarge",
    size   = 30,
    weight = 750,
})

local pd_disarm_success, pd_disarm_fail

net.Receive("TTT_C4PDDisarmResult", function()
    local bomb = net.ReadEntity()
    local ok   = net.ReadBool()
    if IsValid(bomb) then
        if ok and pd_disarm_success then
            pd_disarm_success()
        elseif pd_disarm_fail then
            pd_disarm_fail()
        end
    end
end)

local function ShowC4DisarmPD(bomb)
    local dframe = vgui.Create("DFrame")
    local w, h   = 420, 340
    dframe:SetSize(w, h)
    dframe:Center()
    dframe:SetTitle(T("c4_disarm"))
    dframe:SetVisible(true)
    dframe:ShowCloseButton(true)
    dframe:SetMouseInputEnabled(true)

    local m        = 5
    local title_h  = 20
    local left_w   = 270
    local left_h   = 270
    local right_w  = 135
    local right_h  = left_h
    local bw, bh   = 100, 25

    local dleft = vgui.Create("ColoredBox", dframe)
    dleft:SetColor(Color(50, 50, 50))
    dleft:SetSize(left_w, left_h)
    dleft:SetPos(m, m + title_h)

    local dright = vgui.Create("ColoredBox", dframe)
    dright:SetColor(Color(50, 50, 50))
    dright:SetSize(right_w, right_h)
    dright:SetPos(left_w + m * 2, m + title_h)

    local dtimer = vgui.Create("DLabel", dright)
    dtimer:SetText("99:99:99")
    dtimer:SetFont("C4Timer_PD")
    dtimer:SetTextColor(Color(200, 0, 0, 255))
    dtimer:SetExpensiveShadow(1, COLOR_BLACK)
    dtimer:SizeToContents()
    dtimer:SetWide(120)
    dtimer:SetPos(10, m)
    dtimer.Stop = false
    dtimer.Think = function(s)
        if not IsValid(bomb) or s.Stop then return end
        local t = bomb:GetExplodeTime()
        if t then
            local r = t - CurTime()
            if r > 0 then s:SetText(util.SimpleTime(r, "%02i:%02i:%02i")) end
        end
    end

    local dstatus = vgui.Create("DLabel", dright)
    dstatus:SetText(T("c4_status_armed"))
    dstatus:SetFont("HealthAmmo")
    dstatus:SetTextColor(Color(200, 0, 0, 255))
    dstatus:SetExpensiveShadow(1, COLOR_BLACK)
    dstatus:SizeToContents()
    dstatus:SetPos(m, m * 2 + 30)
    dstatus:CenterHorizontal()

    local desc_h = 45
    local ddesc  = vgui.Create("DLabel", dleft)
    ddesc:SetBright(true)
    ddesc:SetFont("DermaDefaultBold")
    ddesc:SetSize(256, desc_h)
    ddesc:SetWrap(true)
    ddesc:SetText(T("c4_disarm_other"))
    ddesc:SetPos(m, m)

    local bg = vgui.Create("ColoredBox", dleft)
    bg:StretchToParent(m, m + desc_h, m, m)
    bg:SetColor(Color(20, 20, 20, 255))

    -- Bomb image background
    local dbomb_img = vgui.Create("DImage", bg)
    dbomb_img:SetSize(256, 256)
    dbomb_img:SetPos(0, 0)
    dbomb_img:SetMaterial(c4_bomb_mat)

    -- Wire buttons using DImage (which has SetImageColor, unlike DImageButton)
    local wires   = {}
    local panel_disabled = false
    local wx, wy = -84, 70

    for i = 1, (C4_WIRE_COUNT or 6) do
        local wb = vgui.Create("DImage", bg)
        wb:SetPos(wx, wy)
        wb:SetMaterial(c4_wire_mat)
        wb:SizeToContents()
        wb:SetImageColor(wire_colors[i] or COLOR_WHITE)
        wb:SetMouseInputEnabled(true)
        wb:SetCursor("hand")
        wb.IsCut = false

        local wi = i
        function wb:OnMousePressed(mcode)
            if mcode ~= MOUSE_LEFT or self.IsCut or panel_disabled then return end
            panel_disabled = true
            self.IsCut = true
            self:SetMaterial(c4_wirecut_mat)
            self:SetImageColor(wire_colors[wi] or COLOR_WHITE)
            surface.PlaySound(wire_cut_snd)

            if IsValid(bomb) then
                RunConsoleCommand("ttt_c4_pd_disarm", tostring(bomb:EntIndex()), tostring(wi))
            end
        end

        wires[i] = wb
        wy = wy + 27
    end

    local dcancel = vgui.Create("DButton", dframe)
    dcancel:SetPos(w - bw - m, h - bh - m)
    dcancel:SetSize(bw, bh)
    dcancel:CenterHorizontal()
    dcancel:SetText(T("close"))
    dcancel.DoClick = function() dframe:Close() end

    dframe:MakePopup()

    pd_disarm_success = function()
        surface.PlaySound(disarm_beep)
        dtimer.Stop = true
        dtimer:SetTextColor(COLOR_GREEN)
        dstatus:SetTextColor(COLOR_GREEN)
        dstatus:SetText(T("c4_status_disarmed"))
        dstatus:SizeToContents()
        dstatus:CenterHorizontal()
    end

    pd_disarm_fail = function()
        dframe:Close()
    end
end

-- Target ID rendering (replaces ttt_c4's hook for this class)
hook.Add("TTTRenderEntityInfo", "HUDDrawTargetIDC4PD", function(tData)
    local client = LocalPlayer()
    local ent    = tData:GetEntity()

    if
        not client:IsTerror()
        or not IsValid(ent)
        or tData:GetEntityDistance() > 100
        or ent:GetClass() ~= "ttt_c4_pd"
    then return end

    local key_params = { usekey = Key("+use", "USE") }

    tData:EnableText()
    tData:EnableOutline()
    tData:SetOutlineColor(client:GetRoleColor())
    tData:SetTitle(LANG.TryTranslation(ent.PrintName))

    if ent:GetArmed() then
        tData:SetSubtitle(PT("target_c4_armed", key_params))
    else
        tData:SetSubtitle("Waiting to be armed...")
    end

    tData:SetKeyBinding("+use")
    tData:AddDescriptionLine(LANG.TryTranslation("c4_short_desc"))
end)

function ENT:ClientUse()
    if not IsValid(self) then return end
    if self:GetArmed() then
        ShowC4DisarmPD(self)
    end
    -- Unarmed: no action (bomb arms automatically at phase end)
end
