-- Geopolitical System for Minetest
-- Features:
-- - Players spawn into preset countries
-- - First player in country becomes president
-- - Subsequent players become soldiers or engineers
-- - Random perks assigned on spawn/respawn
-- - Country interactions (peace, trade, non-aggression, etc.)
-- - Organizations that transcend countries

local vector = vector
local math = math
local table = table
local minetest = minetest

-- Configuration
local GEOPOLITICAL = {
    COUNTRIES = {
        {name = "Redstonia", color = "red", spawn_pos = {x = 0, y = 10, z = 0}},
        {name = "Emeraldia", color = "green", spawn_pos = {x = 100, y = 10, z = 0}},
        {name = "Azurea", color = "blue", spawn_pos = {x = 0, y = 10, z = 100}},
        {name = "Yellowtopia", color = "yellow", spawn_pos = {x = -100, y = 10, z = 0}},
        {name = "Violetland", color = "violet", spawn_pos = {x = 0, y = 10, z = -100}},
    },
    PERKS = {
        "speed_boost", "jump_boost", "health_boost", "mining_fast", 
        "damage_resist", "night_vision", "water_breathing", "fall_resist"
    },
    ROLES = {
        "soldier", "engineer", "diplomat", "spy", "merchant"
    },
    DIPLOMACY_STATES = {
        "peace", "war", "trade", "non_aggression", "alliance"
    }
}

-- Global state
geopolitical = {
    players = {},
    countries = {},
    organizations = {},
    diplomacy = {}
}

-- Initialize countries
for _, country_def in ipairs(GEOPOLITICAL.COUNTRIES) do
    geopolitical.countries[country_def.name] = {
        name = country_def.name,
        color = country_def.color,
        spawn_pos = country_def.spawn_pos,
        president = nil,
        members = {},
        resources = {
            gold = 1000,
            iron = 5000,
            food = 10000
        },
        alliances = {},
        enemies = {}
    }
end

-- Initialize some organizations
geopolitical.organizations = {
    {
        name = "United Builders",
        description = "Organization dedicated to construction and architecture",
        members = {},
        cross_country = true
    },
    {
        name = "Miner's Guild",
        description = "Organization for miners and resource gatherers",
        members = {},
        cross_country = true
    },
    {
        name = "Free Traders",
        description = "Organization promoting free trade between nations",
        members = {},
        cross_country = true
    }
}

-- Helper functions
local function get_random_perk()
    return GEOPOLITICAL.PERKS[math.random(1, #GEOPOLITICAL.PERKS)]
end

local function get_random_role()
    return GEOPOLITICAL.ROLES[math.random(1, #GEOPOLITICAL.ROLES)]
end

local function assign_perks(player)
    local player_name = player:get_player_name()
    if not geopolitical.players[player_name] then return end
    
    -- Clear old perks
    for _, perk in ipairs(GEOPOLITICAL.PERKS) do
        player:set_physics_override({[perk] = 1.0})
    end
    
    -- Assign new perks
    local num_perks = math.random(1, 3) -- 1-3 perks
    local perks = {}
    for i = 1, num_perks do
        local perk = get_random_perk()
        if not perks[perk] then -- Ensure unique perks
            perks[perk] = true
            -- Apply perk
            if perk == "speed_boost" then
                player:set_physics_override({speed = 1.5})
            elseif perk == "jump_boost" then
                player:set_physics_override({jump = 1.5})
            elseif perk == "health_boost" then
                player:set_properties({hp_max = 30})
                player:set_hp(30)
            elseif perk == "mining_fast" then
                -- This would need to be handled with tools in reality
            elseif perk == "damage_resist" then
                -- Would need armor system integration
            elseif perk == "night_vision" then
                -- Would need client-side effect
            elseif perk == "water_breathing" then
                -- Would need breath system integration
            elseif perk == "fall_resist" then
                -- Would need fall damage modification
            end
        end
    end
    
    geopolitical.players[player_name].perks = perks
end

local function assign_country(player)
    local player_name = player:get_player_name()
    
    -- Find country with fewest players
    local min_count = math.huge
    local selected_country = nil
    
    for _, country in pairs(geopolitical.countries) do
        local member_count = #country.members
        if member_count < min_count then
            min_count = member_count
            selected_country = country
        end
    end
    
    if selected_country then
        -- Add player to country
        table.insert(selected_country.members, player_name)
        geopolitical.players[player_name] = {
            country = selected_country.name,
            role = (#selected_country.members == 1) and "president" or get_random_role(),
            perks = {}
        }
        
        -- If first member, make president
        if #selected_country.members == 1 then
            selected_country.president = player_name
            minetest.chat_send_player(player_name, 
                "Congratulations! You are the president of " .. selected_country.name .. "!")
        else
            minetest.chat_send_player(player_name, 
                "You have joined " .. selected_country.name .. " as a " .. 
                geopolitical.players[player_name].role)
        end
        
        -- Teleport to country spawn
        player:set_pos(selected_country.spawn_pos)
        
        -- Assign perks
        assign_perks(player)
    end
end

local function handle_respawn(player)
    local player_name = player:get_player_name()
    if geopolitical.players[player_name] then
        -- Get player's country
        local country_name = geopolitical.players[player_name].country
        local country = geopolitical.countries[country_name]
        
        -- Teleport back to country spawn
        player:set_pos(country.spawn_pos)
        
        -- Reassign perks (randomize on respawn)
        assign_perks(player)
        
        minetest.chat_send_player(player_name, "Welcome back to " .. country_name .. "!")
    end
end

local function show_country_info(player)
    local player_name = player:get_player_name()
    if not geopolitical.players[player_name] then return end
    
    local country_name = geopolitical.players[player_name].country
    local country = geopolitical.countries[country_name]
    
    local info = "--- " .. country_name .. " ---\n"
    info = info .. "President: " .. (country.president or "None") .. "\n"
    info = info .. "Members: " .. #country.members .. "\n"
    info = info .. "Resources:\n"
    info = info .. "  Gold: " .. country.resources.gold .. "\n"
    info = info .. "  Iron: " .. country.resources.iron .. "\n"
    info = info .. "  Food: " .. country.resources.food .. "\n"
    
    info = info .. "Alliances: "
    for _, ally in ipairs(country.alliances) do
        info = info .. ally .. " "
    end
    info = info .. "\n"
    
    info = info .. "Enemies: "
    for _, enemy in ipairs(country.enemies) do
        info = info .. enemy .. " "
    end
    info = info .. "\n"
    
    info = info .. "Your role: " .. geopolitical.players[player_name].role .. "\n"
    info = info .. "Your perks: "
    for perk, _ in pairs(geopolitical.players[player_name].perks) do
        info = info .. perk .. " "
    end
    
    minetest.show_formspec(player_name, "geopolitical:country_info", 
        "size[8,10]label[0.5,0.5;" .. minetest.formspec_escape(info) .. "]")
end

-- Diplomacy functions
local function propose_diplomacy(player, target_country, action)
    local player_name = player:get_player_name()
    if not geopolitical.players[player_name] then return end
    
    local source_country = geopolitical.players[player_name].country
    local source_country_data = geopolitical.countries[source_country]
    local target_country_data = geopolitical.countries[target_country]
    
    if not target_country_data then
        minetest.chat_send_player(player_name, "Country not found!")
        return
    end
    
    -- Only presidents can propose diplomacy
    if source_country_data.president ~= player_name then
        minetest.chat_send_player(player_name, "Only the president can propose diplomacy!")
        return
    end
    
    -- Check if target country has a president
    if not target_country_data.president then
        minetest.chat_send_player(player_name, target_country .. " has no president to negotiate with!")
        return
    end
    
    -- Create diplomatic proposal
    geopolitical.diplomacy[#geopolitical.diplomacy+1] = {
        source = source_country,
        target = target_country,
        action = action,
        status = "pending"
    }
    
    minetest.chat_send_player(player_name, "Diplomatic proposal sent to " .. target_country)
    minetest.chat_send_player(target_country_data.president, 
        source_country .. " has proposed a " .. action .. " agreement. Type /diplomacy to respond.")
end

local function accept_diplomacy(player, proposal_index)
    local player_name = player:get_player_name()
    if not geopolitical.players[player_name] then return end
    
    local proposal = geopolitical.diplomacy[proposal_index]
    if not proposal then return end
    
    local target_country = geopolitical.players[player_name].country
    if proposal.target ~= target_country then
        minetest.chat_send_player(player_name, "This proposal is not for your country!")
        return
    end
    
    local target_country_data = geopolitical.countries[target_country]
    if target_country_data.president ~= player_name then
        minetest.chat_send_player(player_name, "Only the president can accept diplomacy!")
        return
    end
    
    local source_country_data = geopolitical.countries[proposal.source]
    
    -- Implement the diplomatic action
    if proposal.action == "peace" then
        -- Remove from enemies if present
        for i, enemy in ipairs(source_country_data.enemies) do
            if enemy == target_country then
                table.remove(source_country_data.enemies, i)
                break
            end
        end
        for i, enemy in ipairs(target_country_data.enemies) do
            if enemy == proposal.source then
                table.remove(target_country_data.enemies, i)
                break
            end
        end
    elseif proposal.action == "alliance" then
        table.insert(source_country_data.alliances, target_country)
        table.insert(target_country_data.alliances, proposal.source)
    elseif proposal.action == "trade" then
        -- Implement trade agreement
    elseif proposal.action == "non_aggression" then
        -- Implement non-aggression pact
    end
    
    proposal.status = "accepted"
    minetest.chat_send_player(player_name, "You have accepted the " .. proposal.action .. " with " .. proposal.source)
    minetest.chat_send_player(source_country_data.president, 
        target_country .. " has accepted your " .. proposal.action .. " proposal!")
end

-- Chat commands
minetest.register_chatcommand("country", {
    description = "Show information about your country",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if player then
            show_country_info(player)
        end
    end
})

minetest.register_chatcommand("propose_alliance", {
    params = "<country>",
    description = "Propose an alliance with another country (president only)",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if player and param and param ~= "" then
            propose_diplomacy(player, param, "alliance")
        end
    end
})

minetest.register_chatcommand("propose_peace", {
    params = "<country>",
    description = "Propose peace with another country (president only)",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if player and param and param ~= "" then
            propose_diplomacy(player, param, "peace")
        end
    end
})

minetest.register_chatcommand("diplomacy", {
    description = "View and respond to diplomatic proposals (president only)",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return end
        
        local player_name = name
        if not geopolitical.players[player_name] then return end
        
        local country_name = geopolitical.players[player_name].country
        local country = geopolitical.countries[country_name]
        
        if country.president ~= player_name then
            minetest.chat_send_player(player_name, "Only the president can manage diplomacy!")
            return
        end
        
        local formspec = "size[8,10]label[0.5,0.5;Diplomatic Proposals]"
        local y = 1.5
        local proposals_shown = 0
        
        for i, proposal in ipairs(geopolitical.diplomacy) do
            if proposal.target == country_name and proposal.status == "pending" then
                formspec = formspec .. "label[0.5,"..y..";"..proposal.source.." proposes "..proposal.action.."]"
                formspec = formspec .. "button[5,"..(y-0.2)..";2,1;accept_"..i..";Accept]"
                formspec = formspec .. "button[7,"..(y-0.2)..";1,1;reject_"..i..";Reject]"
                y = y + 1
                proposals_shown = proposals_shown + 1
            end
        end
        
        if proposals_shown == 0 then
            formspec = formspec .. "label[0.5,1.5;No pending proposals]"
        end
        
        minetest.show_formspec(player_name, "geopolitical:diplomacy", formspec)
    end
})

-- Formspec handlers
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "geopolitical:diplomacy" then
        local player_name = player:get_player_name()
        
        for field, _ in pairs(fields) do
            if field:sub(1, 7) == "accept_" then
                local index = tonumber(field:sub(8))
                accept_diplomacy(player, index)
                return
            elseif field:sub(1, 7) == "reject_" then
                local index = tonumber(field:sub(8))
                geopolitical.diplomacy[index].status = "rejected"
                minetest.chat_send_player(player_name, "Proposal rejected")
                return
            end
        end
    end
end)

-- Event handlers
minetest.register_on_newplayer(function(player)
    assign_country(player)
end)

minetest.register_on_respawnplayer(function(player)
    handle_respawn(player)
    return true -- Override default respawn
end)

minetest.register_on_joinplayer(function(player)
    local player_name = player:get_player_name()
    if not geopolitical.players[player_name] then
        assign_country(player)
    else
        -- Player already in system, just teleport to their country
        local country_name = geopolitical.players[player_name].country
        local country = geopolitical.countries[country_name]
        player:set_pos(country.spawn_pos)
    end
end)

minetest.register_on_dieplayer(function(player)
    -- Clear any perks that might affect respawn
    player:set_physics_override({speed = 1.0, jump = 1.0})
    player:set_properties({hp_max = 20})
end)

-- Initialize existing players (in case of server restart)
minetest.after(0, function()
    for _, player in ipairs(minetest.get_connected_players()) do
        local player_name = player:get_player_name()
        if not geopolitical.players[player_name] then
            assign_country(player)
        end
    end
end)

minetest.log("action", "[Geopolitical] System initialized")
-- Repair System
-- Repair System Implementation

-- First, define our own nodes and sounds if default mod isn't available
local S = minetest.get_translator("geopolitical")

local repair_sounds = {}
if minetest.get_modpath("default") then
    repair_sounds = default.node_sound_metal_defaults()
else
    repair_sounds = {
        footstep = {name = "geopolitical_metal_footstep", gain = 0.5},
        dig = {name = "geopolitical_metal_dig", gain = 0.5},
        dug = {name = "geopolitical_metal_dug", gain = 1.0},
        place = {name = "geopolitical_metal_place", gain = 1.0}
    }
end

-- Register the repair kit node
minetest.register_node("geopolitical:repair_kit", {
    description = S("Building Repair Kit") .. "\n" .. S("Place in damaged building to repair"),
    tiles = {"geopolitical_repair_kit.png"},
    inventory_image = "geopolitical_repair_kit.png",
    groups = {cracky = 1, level = 2, repair_kit = 1},
    sounds = repair_sounds,
    
    on_place = function(itemstack, placer, pointed_thing)
        -- Basic placement checks
        if pointed_thing.type ~= "node" then return end
        if not placer or not placer:is_player() then return end
        
        local pos = pointed_thing.under
        local player_name = placer:get_player_name()
        local player_data = geopolitical.players[player_name]
        
        -- Player validation
        if not player_data then
            minetest.chat_send_player(player_name, S("Error: Player data not found!"))
            return
        end
        
        -- Find building at this position
        local building, building_def
        for hash, b in pairs(geopolitical.building_health or {}) do
            local bpos = minetest.get_position_from_hash(hash)
            
            -- Find building definition
            local bdef
            for _, def in ipairs(geopolitical.BUILDINGS or {}) do
                if def.id == b.type then
                    bdef = def
                    break
                end
            end
            if not bdef then goto continue end
            
            -- Calculate building bounds
            local half_x = math.floor(bdef.size.x / 2)
            local half_z = math.floor(bdef.size.z / 2)
            
            -- Check if position is within building bounds
            if pos.x >= bpos.x - half_x and pos.x <= bpos.x + half_x and
               pos.y >= bpos.y and pos.y <= bpos.y + bdef.size.y-1 and
               pos.z >= bpos.z - half_z and pos.z <= bpos.z + half_z then
                building = b
                building_def = bdef
                break
            end
            ::continue::
        end
        
        -- Building validation
        if not building or not building_def then
            minetest.chat_send_player(player_name, S("No building found at this location!"))
            return
        end
        
        -- Country permission check
        if building.country ~= player_data.country then
            minetest.chat_send_player(player_name, S("You can only repair your own country's buildings!"))
            return
        end
        
        -- Health check
        local health_percent = (building.current_health / building.max_health) * 100
        if health_percent >= 100 then
            minetest.chat_send_player(player_name, S("This building doesn't need repair!"))
            return
        end
        
        -- Get country resources
        local country = geopolitical.countries[player_data.country]
        if not country or not country.resources then
            minetest.chat_send_player(player_name, S("Error: Country data not found!"))
            return
        end
        
        -- Calculate and check repair cost
        local repair_cost = math.max(1, math.floor((100 - health_percent) / 10)) -- At least 1 iron
        if (country.resources.iron or 0) < repair_cost then
            minetest.chat_send_player(player_name, 
                S("Need @1 iron to repair this building (have @2)", repair_cost, country.resources.iron or 0))
            return
        end
        
        -- Perform repair
        local nodes_repaired = 0
        for _, node_pos in ipairs(building.nodes or {}) do
            local node = minetest.get_node(node_pos)
            if node.name ~= building_def.node then
                minetest.set_node(node_pos, {name = building_def.node})
                nodes_repaired = nodes_repaired + 1
            end
        end
        
        -- Update building and country data
        country.resources.iron = (country.resources.iron or 0) - repair_cost
        building.current_health = building.max_health
        
        -- Feedback
        minetest.chat_send_player(player_name, 
            S("Building repaired! Repaired @1 blocks for @2 iron. Now at 100% integrity.", 
            nodes_repaired, repair_cost))
        
        -- Consume one repair kit
        itemstack:take_item()
        return itemstack
    end
})

-- Craft recipe for repair kit (with fallbacks)
local steel_ingot = minetest.registered_items["default:steel_ingot"] and "default:steel_ingot" or "geopolitical:steel_ingot"
local gold_ingot = minetest.registered_items["default:gold_ingot"] and "default:gold_ingot" or "geopolitical:gold_ingot"

minetest.register_craft({
    output = "geopolitical:repair_kit",
    recipe = {
        {steel_ingot, steel_ingot, steel_ingot},
        {steel_ingot, gold_ingot, steel_ingot},
        {steel_ingot, steel_ingot, steel_ingot}
    }
})

-- Register fallback items if needed
if not minetest.registered_items["default:steel_ingot"] then
    minetest.register_craftitem("geopolitical:steel_ingot", {
        description = S("Steel Ingot"),
        inventory_image = "geopolitical_steel_ingot.png",
    })
end

if not minetest.registered_items["default:gold_ingot"] then
    minetest.register_craftitem("geopolitical:gold_ingot", {
        description = S("Gold Ingot"),
        inventory_image = "geopolitical_gold_ingot.png",
    })
end

-- Building info command
minetest.register_chatcommand("building_info", {
    params = "",
    description = S("Check the integrity of a building you're standing in"),
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, S("Player not found") end
        
        local pos = vector.round(player:get_pos())
        
        -- Find building
        local building, building_def
        for hash, b in pairs(geopolitical.building_health or {}) do
            local bpos = minetest.get_position_from_hash(hash)
            
            -- Find building definition
            local bdef
            for _, def in ipairs(geopolitical.BUILDINGS or {}) do
                if def.id == b.type then
                    bdef = def
                    break
                end
            end
            if not bdef then goto continue end
            
            -- Calculate bounds
            local half_x = math.floor(bdef.size.x / 2)
            local half_z = math.floor(bdef.size.z / 2)
            
            -- Check position
            if pos.x >= bpos.x - half_x and pos.x <= bpos.x + half_x and
               pos.y >= bpos.y and pos.y <= bpos.y + bdef.size.y-1 and
               pos.z >= bpos.z - half_z and pos.z <= bpos.z + half_z then
                building = b
                building_def = bdef
                break
            end
            ::continue::
        end
        
        if not building or not building_def then
            return false, S("You're not inside any building")
        end
        
        -- Calculate health and status
        local health_percent = (building.current_health / building.max_health) * 100
        local status_msg, status_color
        
        if health_percent >= 90 then
            status_msg = S("Excellent condition")
            status_color = "#00FF00" -- Green
        elseif health_percent >= 70 then
            status_msg = S("Good condition")
            status_color = "#00FFFF" -- Cyan
        elseif health_percent >= 50 then
            status_msg = S("Damaged")
            status_color = "#FFFF00" -- Yellow
        elseif health_percent >= 30 then
            status_msg = S("Heavily damaged")
            status_color = "#FFA500" -- Orange
        elseif health_percent >= 20 then
            status_msg = S("Critical condition")
            status_color = "#FF0000" -- Red
        else
            status_msg = S("Non-functional")
            status_color = "#800000" -- Dark Red
        end
        
        return true, string.format(
            "%s: %.1f%%\n%s: <color=%s>%s</color>\n%s: %d %s",
            S("Integrity"), health_percent,
            S("Status"), status_color, status_msg,
            S("Repair cost"), math.floor((100 - health_percent) / 10), S("iron")
        )
    end
})
minetest.register_node("geopolitical:repair_kit", {
    description = "Building Repair Kit\nPlace in damaged building to repair",
    tiles = {"default_tool_steelpick.png"},
    groups = {cracky = 1, level = 2},
    sounds = default.node_sound_metal_defaults(),
    
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type ~= "node" then return end
        
        local pos = pointed_thing.under
        local player_name = placer:get_player_name()
        local player_data = geopolitical.players[player_name]
        
        if not player_data then return end
        
        -- Find building at this position
        local building
        for hash, b in pairs(geopolitical.building_health) do
            local bpos = minetest.get_position_from_hash(hash)
            local half_x = math.floor(geopolitical.BUILDINGS[b.type].size.x / 2)
            local half_z = math.floor(geopolitical.BUILDINGS[b.type].size.z / 2)
            
            if pos.x >= bpos.x - half_x and pos.x <= bpos.x + half_x and
               pos.y >= bpos.y and pos.y <= bpos.y + geopolitical.BUILDINGS[b.type].size.y-1 and
               pos.z >= bpos.z - half_z and pos.z <= bpos.z + half_z then
                building = b
                break
            end
        end
        
        if not building then
            minetest.chat_send_player(player_name, "No building found at this location!")
            return
        end
        
        -- Check if player is from the same country
        if building.country ~= player_data.country then
            minetest.chat_send_player(player_name, "You can only repair your own country's buildings!")
            return
        end
        
        -- Check if building needs repair
        local health_percent = (building.current_health / building.max_health) * 100
        if health_percent >= 100 then
            minetest.chat_send_player(player_name, "This building doesn't need repair!")
            return
        end
        
        -- Get building definition
        local building_def
        for _, def in ipairs(geopolitical.BUILDINGS) do
            if def.id == building.type then
                building_def = def
                break
            end
        end
        
        if not building_def then return end
        
        -- Repair the building
        local repair_cost = math.floor((100 - health_percent) / 10) -- 1 iron per 10% missing
        local country = geopolitical.countries[player_data.country]
        
        if country.resources.iron < repair_cost then
            minetest.chat_send_player(player_name, 
                "Need "..repair_cost.." iron to repair this building (have "..country.resources.iron..")")
            return
        end
        
        -- Deduct resources
        country.resources.iron = country.resources.iron - repair_cost
        
        -- Restore all building blocks
        for _, node_pos in ipairs(building.nodes) do
            local node = minetest.get_node(node_pos)
            local expected_node = building_def.node
            
            -- Special cases for certain buildings
            if building.type == "port" then
                expected_node = "default:wood"
            elseif building.type == "missile_silo" then
                expected_node = "default:obsidian"
            elseif building.type == "military_base" then
                expected_node = "default:steelblock"
            elseif building.type == "trade_center" then
                expected_node = "default:goldblock"
            end
            
            if node.name ~= expected_node then
                minetest.set_node(node_pos, {name=expected_node})
            end
        end
        
        -- Update building health
        building.current_health = building.max_health
        
        minetest.chat_send_player(player_name, 
            "Building repaired for "..repair_cost.." iron! Now at 100% integrity.")
        
        -- Consume one repair kit
        itemstack:take_item()
        return itemstack
    end
})

-- Craft recipe for repair kit
minetest.register_craft({
    output = "geopolitical:repair_kit",
    recipe = {
        {"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
        {"default:steel_ingot", "default:gold_ingot", "default:steel_ingot"},
        {"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"}
    }
})

-- Add building integrity info to /buildings command
minetest.register_chatcommand("building_info", {
    params = "",
    description = "Check the integrity of a building you're standing in",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found" end
        
        local pos = player:get_pos()
        pos.x = math.floor(pos.x + 0.5)
        pos.y = math.floor(pos.y + 0.5)
        pos.z = math.floor(pos.z + 0.5)
        
        -- Find building at this position
        local building
        for hash, b in pairs(geopolitical.building_health) do
            local bpos = minetest.get_position_from_hash(hash)
            local half_x = math.floor(geopolitical.BUILDINGS[b.type].size.x / 2)
            local half_z = math.floor(geopolitical.BUILDINGS[b.type].size.z / 2)
            
            if pos.x >= bpos.x - half_x and pos.x <= bpos.x + half_x and
               pos.y >= bpos.y and pos.y <= bpos.y + geopolitical.BUILDINGS[b.type].size.y-1 and
               pos.z >= bpos.z - half_z and pos.z <= bpos.z + half_z then
                building = b
                break
            end
        end
        
        if not building then
            return false, "You're not inside any building"
        end
        
        local building_def
        for _, def in ipairs(geopolitical.BUILDINGS) do
            if def.id == building.type then
                building_def = def
                break
            end
        end
        
        if not building_def then return false, "Building type not found" end
        
        local health_percent = (building.current_health / building.max_health) * 100
        local status_msg
        
        if health_percent >= 90 then
            status_msg = "§aExcellent condition"
        elseif health_percent >= 70 then
            status_msg = "§bGood condition"
        elseif health_percent >= 50 then
            status_msg = "§eDamaged"
        elseif health_percent >= 30 then
            status_msg = "§6Heavily damaged"
        elseif health_percent >= 20 then
            status_msg = "§cCritical condition"
        else
            status_msg = "§4Non-functional"
        end
        
        return true, string.format("%s Integrity: %.1f%%\n%s\nRepair cost: %d iron",
            building_def.name, health_percent, status_msg,
            math.floor((100 - health_percent) / 10))
    end
})
