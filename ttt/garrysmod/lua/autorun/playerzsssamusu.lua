player_manager.AddValidModel( "Zero Suit Samus U","models/Player_ZssSamusU.mdl" )
player_manager.AddValidHands( "Zero Suit Samus U", "models/ZSSU_arms.mdl", 0, "00000000" )


--Add NPC
local NPC =
{
	Name = "Zero Suit Samus U",
	Class = "npc_citizen",
	KeyValues = { citizentype = 4 },
	Model = "Models/NPC_ZssSamusU.mdl",
	Category = "Zero Suit Samus SSB Wii U"
}

list.Set( "NPC", "npc_zsssamusu", NPC )


