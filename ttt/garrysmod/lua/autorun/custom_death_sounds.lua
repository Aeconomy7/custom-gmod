if not SERVER then return end

AddCSLuaFile()

local deathSounds = {}

local mp3Files = file.Find("sound/death_sounds/*.mp3", "GAME")
local wavFiles = file.Find("sound/death_sounds/*.wav", "GAME")

for _, fileName in ipairs(mp3Files) do
    table.insert(deathSounds, "death_sounds/" .. fileName)
end
for _, fileName in ipairs(wavFiles) do
    table.insert(deathSounds, "death_sounds/" .. fileName)
end

for _, soundPath in ipairs(deathSounds) do
    resource.AddFile("sound/" .. soundPath)
    util.PrecacheSound(soundPath)
end

print("[Custom Death Sounds] Loaded " .. #deathSounds .. " sound(s):")
for i, soundPath in ipairs(deathSounds) do
    print(string.format("  [%d] %s", i, soundPath))
end

-- Suppress TTT2's built-in death sound pool and replace with our custom sounds.
-- isSilent is true for headshots, slash-damage kills, and weapons with IsSilent = true.
hook.Add("TTT2PlayDeathScream", "CustomDeathSound", function(tbl, isSilent)
    if not isSilent and #deathSounds > 0 then
        local snd = deathSounds[math.random(#deathSounds)]
        sound.Play(snd, tbl.victim:GetShootPos(), 90, 100)
    end
    return false -- always suppress TTT2's default scream
end)
