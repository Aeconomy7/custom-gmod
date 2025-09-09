-- Client-side file

net.Receive("sc0b_joinsound", function()
    print("Player connected!")
    surface.PlaySound("bl_sounds/playerConnect.wav")
    -- local ply = net.ReadEntity()
    -- if not IsValid(ply) then return end

    

    -- Optional: chat message for flavor
    -- chat.AddText(Color(0, 200, 255), "[JoinSound] ", color_white,
    --     ply:Nick() .. " joined with style!")
end)