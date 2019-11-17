-- 2.0.1 remove check for electric inserters as they are incompatible with the vanilla method of leeching fuel
for _, v in pairs(data.raw.inserter) do
    if v.energy_source.type == "burner" then
        v.allow_burner_leech = true
    end
end
