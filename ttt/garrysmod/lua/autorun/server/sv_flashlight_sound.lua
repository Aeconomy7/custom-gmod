if not SERVER then return end

local SND_ON  = "bl_sounds/lightOn.wav"
local SND_OFF = "bl_sounds/lightOff.wav"

util.PrecacheSound(SND_ON)
util.PrecacheSound(SND_OFF)

-- TTT2 blocks the engine flashlight and sets EF_DIMLIGHT manually in GM:PlayerSwitchFlashlight.
-- Our hook fires first (hook.Add runs before GM functions); we play the sound server-side so
-- all clients hear it positionally, then let TTT2's GM hook handle EF_DIMLIGHT as normal.
hook.Add("PlayerSwitchFlashlight", "sc0b_FlashlightSound", function(ply, on)
    if not IsValid(ply) then return end
    ply:EmitSound(on and SND_ON or SND_OFF, 70, 100)
end)
