for _, v in pairs(data.raw.inserter) do
    if v.energy_source.type == "burner" then
        v.allow_burner_leech = true
    end
end
