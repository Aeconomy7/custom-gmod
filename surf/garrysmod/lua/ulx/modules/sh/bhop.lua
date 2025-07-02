if CLIENT then
	hook.Add("CreateMove", "bunnyhop", function(cmd)
		if LocalPlayer():GetNWInt("bhop") == 1 and IsValid(LocalPlayer()) and cmd:KeyDown(IN_JUMP) and LocalPlayer():GetMoveType() != MOVETYPE_NOCLIP and LocalPlayer():WaterLevel() < 2 then
			local buttonsetter = cmd:GetButtons()
			if !LocalPlayer():IsOnGround() then
				buttonsetter = bit.band(buttonsetter, bit.bnot(IN_JUMP))
			end
			cmd:SetButtons(buttonsetter)
		end
	end)
end

function ulx.bhop( calling_ply, target_plys, should_revoke )
	if not target_plys[ 1 ]:IsValid() then
		if not should_revoke then
			Msg( "Why you wanna jump, you are literally a terminal.\n" )
		else
			Msg( "Unable to remove your bunny hop, keep jumping.\n" )
		end
		return
	end

	local affected_plys = {}
	for i=1, #target_plys do
		local v = target_plys[ i ]

		if ulx.getExclusive( v, calling_ply ) then
			ULib.tsayError( calling_ply, ulx.getExclusive( v, calling_ply ), true )
		else
			if not should_revoke then
				v:SetNWInt("bhop", 1)
			else
				v:SetNWInt("bhop", 0)
			end
			table.insert( affected_plys, v )
		end
	end

	if not should_revoke then
		ulx.fancyLogAdmin( calling_ply, "#A granted auto-bhop upon #T", affected_plys )
	else
		ulx.fancyLogAdmin( calling_ply, "#A revoked auto-bhop from #T", affected_plys )
	end
end
local bhop = ulx.command("Fun", "ulx bhop", ulx.bhop, "!bhop")
bhop:addParam{ type=ULib.cmds.PlayersArg, ULib.cmds.optional }
bhop:addParam{ type=ULib.cmds.BoolArg, invisible=true }
bhop:defaultAccess(ULib.ACCESS_ALL)
bhop:help( "Grants auto-bhop to target(s)." )
bhop:setOpposite( "ulx unbhop", {_, _, true}, "!unbhop" )
