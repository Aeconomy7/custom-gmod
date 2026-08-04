-- cl_flashlight_sound.lua
-- TTT2 blocks the engine flashlight toggle (returns false in PlayerSwitchFlashlight)
-- and manually sets EF_DIMLIGHT instead, so the engine's built-in sound never fires.
-- We watch EF_DIMLIGHT on LocalPlayer() and play our own sounds.
if not CLIENT then return end

local SND_ON  = "bl_sounds/lightOn.wav"
local SND_OFF = "bl_sounds/lightOff.wav"

local wasOn = false

hook.Add("Think", "BL_FlashlightSound", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local isOn = ply:IsEffectActive(EF_DIMLIGHT)
    if isOn == wasOn then return end
    wasOn = isOn

    surface.PlaySound(isOn and SND_ON or SND_OFF)
end)
