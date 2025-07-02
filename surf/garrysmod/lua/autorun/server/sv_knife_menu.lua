include("autorun/server/sv_knife_config.lua")

util.AddNetworkString("OpenKnifeMenu")
util.AddNetworkString("SelectKnifeSkin")

hook.Add("PlayerSay", "KnifeChatCommand", function(ply, text)
    if string.lower(text) == "!knife" then
        if not KnifeSkins then
            ply:ChatPrint("Knife menu not ready. Try again shortly.")
            return ""
        end

        net.Start("OpenKnifeMenu")
        net.WriteTable(KnifeSkins)
        net.Send(ply)
        return ""
    end
end)

net.Receive("SelectKnifeSkin", function(len, ply)
    local chosenClass = net.ReadString()

    -- Validate weapon class exists in config
    local found = false
    for _, skin in ipairs(KnifeSkins) do
        if skin.class == chosenClass then
            found = true
            break
        end
    end

    if found then
        ply:SetPData("selected_knife", chosenClass)
        ply:ChatPrint("You selected " .. chosenClass .. "! Great choice B)")
        ply:StripWeapons()
        ply:Give(chosenClass)
        ply:SelectWeapon(chosenClass)
    end
end)

hook.Add("PlayerSpawn", "EquipKnifeOnSpawn", function(ply)
    local class = ply:GetPData("selected_knife")
    if class then
        timer.Simple(1, function()
            if IsValid(ply) then
                ply:Give(class)
                ply:SelectWeapon(class)
            end
        end)
    end
end)