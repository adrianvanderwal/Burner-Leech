-- Pyro-Fire#5784
function isvalid(v)
    return v and v.valid
end

function init_globals()
    -- [re]build the list of burner/inserter entities
    global.burner_inserters = {}
    global.number_of_burner_inserters = 0
    for _, surface in pairs(game.surfaces) do
        for _, inserter in ipairs(surface.find_entities_filtered({type = "inserter"})) do
            if inserter.burner then
                table.insert(global.burner_inserters, {entity = inserter, position = inserter.position, force = inserter.force, surface = inserter.surface, process = true})
                global.number_of_burner_inserters = global.number_of_burner_inserters + 1
            end
        end
    end
    global.inserter_index = nil
    -- [re]build the list of fuel items
    global.fuel_list = {}
    for _, proto in pairs(game.item_prototypes) do
        if proto.fuel_value > 0 then
            table.insert(global.fuel_list, {[proto.name] = proto.stack_size})
        end
    end
    -- set other global settings
    global.number_of_inserter_to_process = 100
    global.cleaning_burner_inserters = false
end

local function position_to_tile_position(position)
    local x, y
    local ceil_x = math.ceil(position.x)
    local ceil_y = math.ceil(position.y)
    x = position.x >= 0 and math.floor(position.x) + 0.5 or (ceil_x == position.x and ceil_x + 0.5 or ceil_x - 0.5)
    y = position.y >= 0 and math.floor(position.y) + 0.5 or (ceil_y == position.y and ceil_y + 0.5 or ceil_y - 0.5)
    return {x, y}
end

local function add_inserter(entity)
    if (entity.type == "inserter" and entity.burner) then
        table.insert(global.burner_inserters, {entity = entity, position = entity.position, force = entity.force, surface = entity.surface})
    end
end
local function remove_inserter(entity)
    if (entity.type == "inserter" and entity.burner) then
        for k, v in pairs(global.burner_inserters) do
            if v.entity == entity then
                table.remove(global.burner_inserters, k)
                global.inserter_index = nil
                break
            end
        end
    end
end

local function on_built(event)
    add_inserter(event.created_entity)
end

local function on_cloned(event)
    add_inserter(event.destination)
end

local function on_script_raised(event)
    add_inserter(event.entity)
end

local function on_mined(event)
    remove_inserter(event.entity)
end

-- entity placement events
script.on_event(defines.events.on_built_entity, on_built)
script.on_event(defines.events.on_robot_built_entity, on_built)
script.on_event(defines.events.on_entity_cloned, on_cloned)
script.on_event(defines.events.script_raised_built, on_script_raised)
script.on_event(defines.events.script_raised_revive, on_script_raised)

-- entity removal events
script.on_event(defines.events.on_player_mined_entity, on_mined)
script.on_event(defines.events.on_robot_mined, on_mined)
script.on_event(defines.events.script_raised_destroy, on_mined)

-- on_tick
function on_tick()
    -- set local table
    local burner_inserters = global.burner_inserters or {}
    -- count rows
    local count_burner_inserters = #burner_inserters
    if global.inserter_index ~= nil then
        if global.inserter_index > count_burner_inserters then
            -- reset global
            global.inserter_index = nil
        end
    end
    -- check there's actually something in the table to process
    if count_burner_inserters == 0 then
        -- nothing to do
        return
    end
    -- set number of entities to process
    local number_of_inserters_to_process = global.number_of_inserter_to_process or 60

    -- @pyro-fire for methodology
    -- for 1 to the set number of inserters to process per tick, or the table count (whichever is smaller)
    for i = 1, math.min(count_burner_inserters, number_of_inserters_to_process) do
        -- get next value from table
        local current_index, data = next(burner_inserters, global.inserter_index or nil)
        -- check it's not been removed
        if data ~= nil then
            -- set local variable
            local inserter = data.entity
            -- check validity
            if isvalid(inserter) then
                -- sanity check that it is in fact an inserter, with a burner energy source
                if (inserter.type == "inserter" and inserter.burner) then
                    -- perform the leech!
                    leech(inserter)
                else
                    -- somehow a non-burner inserter is in the list - remove it
                    global.burner_inserters[global.inserter_index] = nil
                    return
                end
            else
                -- inserter was removed, became invalid, moved surfaces
                -- check to see if there is a different burner inserter at that position - use that, else remove the reference
                local position = data.position
                local surface = data.surface
                -- check if surface still exists, with warptorio mod surfaces get removed after a warp
                if surface.valid then
                    e = surface.find_entities_filtered({position = data.position, force = data.force, surface = surface, type = "inserter", limit = 1})
                    if (next(e) == nil) or (not e.burner) then
                        -- no burner inserters found at that location, remove reference
                        if global.burner_inserters[global.inserter_index] then
                            global.burner_inserters[global.inserter_index] = nil
                        end
                    else
                        -- replace the reference
                        global.burner_inserters[global.inserter_index].entity = e[1]
                        leech(e[1])
                    end
                else
                    -- surface invalid, remove reference
                    global.burner_inserters[global.inserter_index] = nil
                end
            end
        end
        -- update global index
        global.inserter_index = current_index
    end
end

--- leech(burner)
-- checks to see if the burner inserter can/should leech fuel from the entity at it's pickup position
-- To Do: Cache previous pickup target and destination in global table
function leech(inserter)
    -- set local vars
    local surface, force, position = inserter.surface, inserter.force, inserter.position

    -- only need to check if the entity in the drop_location has a burner energy source
    -- if not, skip processing
    local drop_target = nil
    -- find and set drop_target
    dt = surface.find_entities_filtered({position = position_to_tile_position(inserter.drop_position), force = inserter.force, surface = inserter.surface, limit = 1})
    drop_target = dt[1]
    -- check validity
    -- check drop_target for burner energy source
    if drop_target == nil or drop_target.burner == nil then
        return
    end

    log((global.inserter_index or "nil") .. ": " .. inserter.name .. " @ " .. inserter.position.x .. ", " .. inserter.position.y)

    -- find and set pickup_target
    if inserter.pickup_target == nil then
        pt = surface.find_entities_filtered({position = position_to_tile_position(inserter.pickup_position), force = inserter.force, surface = inserter.surface, limit = 1})
        if pt[1] ~= nil then
            if pt[1].get_fuel_inventory() ~= nil then
                take_from_pickup_target_inventory = true
                pickup_target = pt[1]
            end
        end
    else
        pickup_target = inserter.pickup_target
    end
    -- nothing to pickup from
    if pickup_target == nil or not pickup_target.valid then
        return
    end

    -- to do:
    -- get fuel stack sizes (limit input based on stack size)
    -- get target fuel type - limit input of fuel based on target fuel

    if drop_target.get_fuel_inventory() ~= nil then
        if drop_target.get_fuel_inventory().get_item_count() < 5 then
            send_to_target = true
        else
            return
        end
    end

    if inserter.held_stack.valid_for_read == false then
        for _, fuel in pairs(global.fuel_list) do
            if pickup_target.get_item_count(fuel) > 0 then
                inserter.held_stack.set_stack({name = fuel, count = 1})
                pickup_target.remove_item({name = fuel, count = 1})
                return true
            end
        end
    end
end

script.on_nth_tick(1, on_tick)

script.on_init(init_globals)

script.on_configuration_changed(init_globals)
