if not SERVER then return end

TrailOptions = {}

local trailFiles = file.Find("materials/trails/*.vmt", "GAME")

table.insert(TrailOptions, 1, {
    name = "None",
    material = "none"
})

for _, file in ipairs(trailFiles) do
    local trailName = string.StripExtension(file)
    table.insert(TrailOptions, {
        name = trailName,
        material = "trails/" .. trailName
    })
end

print("[TrailConfig] Loaded trails")
-- PrintTable(TrailOptions)