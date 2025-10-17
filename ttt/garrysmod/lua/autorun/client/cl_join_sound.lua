-- Client-side file

net.Receive("sc0b_joinsound", function()
    print("Player connected!")
    surface.PlaySound("bl_sounds/playerConnect.wav")
end)