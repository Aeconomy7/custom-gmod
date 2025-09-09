-- Server-side file

util.AddNetworkString("sc0b_joinsound")

gameevent.Listen( "player_connect" )
hook.Add("player_connect", "sc0b_play_connect_sound", function( data )
	-- Broadcast to all clients
    net.Start("sc0b_joinsound")
        -- net.WriteEntity(ply)
    net.Broadcast()
end)
    -- Don’t play for bots if you don’t want
    -- if ply:IsBot() then return end

    -- Broadcast to all clients
    -- net.Start("sc0b_joinsound")
    --     net.WriteEntity(ply)
    -- net.Broadcast()
-- end)