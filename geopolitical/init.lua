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

-- Add to your existing geopolitical.lua file

-- Building Definitions
geopolitical.BUILDINGS = {
    {
        id = "farm",
        name = "Farm",
        description = "Generates food for your country",
        cost = {gold = 50, iron = 20, food = 10},
        roles = {"engineer", "president"},
        generate = {food = 2},
        interval = 60,
        size = {x = 3, y = 2, z = 3},
        node = "farming:soil_wet",
        texture = "default_grass.png",
        limit = 5
    },
    {
        id = "mine",
        name = "Mine",
        description = "Generates iron and gold for your country",
        cost = {gold = 30, iron = 50, food = 5},
        roles = {"engineer", "president"},
        generate = {iron = 1, gold = 0.5},
        interval = 90,
        size = {x = 3, y = 3, z = 3},
        node = "default:stone",
        texture = "default_stone.png",
        limit = 3
    },
    {
        id = "trade_center",
        name = "Trade Center",
        description = "Increases gold generation and enables foreign trade",
        cost = {gold = 200, iron = 100, food = 50},
        roles = {"engineer", "president"},
        generate = {gold = 5},
        bonus = {trade = true},
        interval = 60,
        size = {x = 5, y = 4, z = 5},
        node = "default:goldblock",
        texture = "default_gold_block.png",
        limit = 2
    },
    {
        id = "military_base",
        name = "Military Base",
        description = "Enables missile construction and trains soldiers",
        cost = {gold = 300, iron = 200, food = 100},
        roles = {"engineer", "president"},
        bonus = {military = true},
        size = {x = 7, y = 5, z = 7},
        node = "default:steelblock",
        texture = "default_steel_block.png",
        limit = 1
    },
    {
        id = "missile_silo",
        name = "Missile Silo",
        description = "Allows construction and launch of missiles",
        cost = {gold = 500, iron = 300, food = 50},
        roles = {"engineer", "president"},
        requires = "military_base",
        bonus = {missiles = true},
        size = {x = 5, y = 7, z = 5},
        node = "default:obsidian",
        texture = "default_obsidian.png",
        limit = 1
    },
    {
        id = "port",
        name = "Port",
        description = "Enables naval trade and faster resource generation",
        cost = {gold = 400, iron = 200, food = 150},
        roles = {"engineer", "president"},
        bonus = {trade = true, generation = 1.5},
        size = {x = 9, y = 3, z = 9},
        node = "default:wood",
        texture = "default_wood.png",
        requires_water = true,
        limit = 1
    }
}

-- Building System State
geopolitical.buildings = {}

-- Add this to country initialization
for _, country in pairs(geopolitical.countries) do
    country.buildings = {}
end

-- Building Placement Function
local function place_building(player, building_def, pos)
    local player_name = player:get_player_name()
    local player_data = geopolitical.players[player_name]
    if not player_data then return false, "Player data not found" end
    
    local country = geopolitical.countries[player_data.country]
    if not country then return false, "Country not found" end
    
    -- Check role permission
    local has_role = false
    for _, role in ipairs(building_def.roles) do
        if player_data.role == role then
            has_role = true
            break
        end
    end
    if not has_role then return false, "Your role cannot build this" end
    
    -- Check building limits
    local current_of_type = 0
    for _, b in ipairs(country.buildings) do
        if b.type == building_def.id then
            current_of_type = current_of_type + 1
        end
    end
    if building_def.limit and current_of_type >= building_def.limit then
        return false, "Building limit reached ("..building_def.limit..")"
    end
    
    -- Check requirements
    if building_def.requires then
        local has_requirement = false
        for _, b in ipairs(country.buildings) do
            if b.type == building_def.requires then
                has_requirement = true
                break
            end
        end
        if not has_requirement then
            return false, "Requires "..building_def.requires.." to be built first"
        end
    end
    
    -- Check water requirement for ports
    if building_def.requires_water then
        local water_nearby = false
        for x = -1, 1 do
            for z = -1, 1 do
                local check_pos = vector.add(pos, {x=x, y=-1, z=z})
                local node = minetest.get_node(check_pos)
                if node.name == "default:water_source" or node.name == "default:river_water_source" then
                    water_nearby = true
                    break
                end
            end
            if water_nearby then break end
        end
        if not water_nearby then
            return false, "Must be built next to water"
        end
    end
    
    -- Check resources
    for res, amount in pairs(building_def.cost) do
        if country.resources[res] < amount then
            return false, "Not enough "..res.." (need "..amount..", have "..country.resources[res]..")"
        end
    end
    
    -- Deduct resources
    for res, amount in pairs(building_def.cost) do
        country.resources[res] = country.resources[res] - amount
    end
    
    -- Create building
    local building = {
        type = building_def.id,
        pos = pos,
        country = country.name,
        owner = player_name,
        generated_at = os.time()
    }
    
    table.insert(country.buildings, building)
    table.insert(geopolitical.buildings, building)
    
    -- Create visual structure
    local half_x = math.floor(building_def.size.x / 2)
    local half_z = math.floor(building_def.size.z / 2)
    
    for x = -half_x, half_x do
        for y = 0, building_def.size.y-1 do
            for z = -half_z, half_z do
                local place_pos = vector.add(pos, {x=x, y=y, z=z})
                if y == 0 then
                    -- Foundation
                    minetest.set_node(place_pos, {name=building_def.node})
                elseif y == building_def.size.y-1 then
                    -- Roof
                    minetest.set_node(place_pos, {name=building_def.node})
                else
                    -- Walls
                    if x == -half_x or x == half_x or z == -half_z or z == half_z then
                        minetest.set_node(place_pos, {name=building_def.node})
                    end
                end
            end
        end
    end
    
    -- Add entrance
    minetest.set_node(pos, {name="air"})
    minetest.set_node(vector.add(pos, {x=0, y=1, z=0}), {name="air"})
    
    -- Apply country color
    if minetest.get_modpath("unifieddyes") then
        for x = -half_x, half_x do
            for z = -half_z, half_z do
                local place_pos = vector.add(pos, {x=x, y=1, z=z})
                if minetest.get_node(place_pos).name == building_def.node then
                    minetest.set_node(place_pos, {name="unifieddyes:"..country.color.."_wall"})
                end
            end
        end
    end
    
    -- Apply bonuses
    if building_def.bonus then
        for bonus, value in pairs(building_def.bonus) do
            if bonus == "trade" then
                country.can_trade = true
            elseif bonus == "military" then
                country.can_train_military = true
            elseif bonus == "missiles" then
                country.can_build_missiles = true
            end
        end
    end
    
    return true, building_def.name.." built successfully!"
end

-- Building Resource Generation
local function generate_building_resources()
    local now = os.time()
    
    for _, building in ipairs(geopolitical.buildings) do
        local country = geopolitical.countries[building.country]
        if country then
            local building_def
            for _, def in ipairs(geopolitical.BUILDINGS) do
                if def.id == building.type then
                    building_def = def
                    break
                end
            end
            
            if building_def and building_def.generate and (now - building.generated_at) >= building_def.interval then
                local multiplier = 1
                -- Check for port bonus
                for _, b in ipairs(country.buildings) do
                    if b.type == "port" then
                        multiplier = 1.5
                        break
                    end
                end
                
                for res, amount in pairs(building_def.generate) do
                    country.resources[res] = country.resources[res] + (amount * multiplier)
                end
                building.generated_at = now
            end
        end
    end
    
    minetest.after(10, generate_building_resources)
end

minetest.after(10, generate_building_resources)

-- Building Placement Command
minetest.register_chatcommand("build", {
    params = "<building_type>",
    description = "Build a structure (engineers and president only)",
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        if not player then return false, "Player not found" end
        
        local building_def
        for _, def in ipairs(geopolitical.BUILDINGS) do
            if def.id == param then
                building_def = def
                break
            end
        end
        
        if not building_def then
            local building_list = ""
            for _, def in ipairs(geopolitical.BUILDINGS) do
                building_list = building_list .. def.id .. ", "
            end
            return false, "Invalid building type. Available: "..building_list:sub(1, -3)
        end
        
        local pos = player:get_pos()
        pos.x = math.floor(pos.x + 0.5)
        pos.y = math.floor(pos.y + 0.5)
        pos.z = math.floor(pos.z + 0.5)
        
        -- Adjust position to center of building
        pos.x = pos.x + math.floor(building_def.size.x / 2)
        pos.z = pos.z + math.floor(building_def.size.z / 2)
        
        local success, msg = place_building(player, building_def, pos)
        if success then
            minetest.chat_send_player(name, msg)
            minetest.chat_send_all(name.." has built a "..building_def.name.." for "..geopolitical.players[name].country)
        else
            return false, msg
        end
    end
})

-- Missile System (requires military base and silo)
minetest.register_chatcommand("build_missile", {
    description = "Build a missile (requires military base and silo)",
    func = function(name, param)
        local player_data = geopolitical.players[name]
        if not player_data then return false, "Player data not found" end
        
        local country = geopolitical.countries[player_data.country]
        if not country then return false, "Country not found" end
        
        if not country.can_build_missiles then
            return false, "You need a military base and missile silo to build missiles"
        end
        
        if country.resources.iron < 100 or country.resources.gold < 50 then
            return false, "Need 100 iron and 50 gold to build a missile"
        end
        
        country.resources.iron = country.resources.iron - 100
        country.resources.gold = country.resources.gold - 50
        country.missiles = (country.missiles or 0) + 1
        
        return true, "Missile constructed! Total: "..country.missiles
    end
})

-- Missile Launch Command
minetest.register_chatcommand("launch_missile", {
    params = "<target_country>",
    description = "Launch a missile at another country (president only)",
    func = function(name, param)
        local player_data = geopolitical.players[name]
        if not player_data then return false, "Player data not found" end
        
        if player_data.role ~= "president" then
            return false, "Only the president can launch missiles"
        end
        
        local country = geopolitical.countries[player_data.country]
        if not country then return false, "Country not found" end
        
        if not country.can_build_missiles then
            return false, "You need a military base and missile silo to launch missiles"
        end
        
        if (country.missiles or 0) < 1 then
            return false, "No missiles available"
        end
        
        local target_country = geopolitical.countries[param]
        if not target_country then
            return false, "Target country not found"
        end
        
        country.missiles = country.missiles - 1
        
        -- Damage random building in target country
        if #target_country.buildings > 0 then
            local random_index = math.random(1, #target_country.buildings)
            local destroyed_building = table.remove(target_country.buildings, random_index)
            
            -- Remove building visually
            local building_def
            for _, def in ipairs(geopolitical.BUILDINGS) do
                if def.id == destroyed_building.type then
                    building_def = def
                    break
                end
            end
            
            if building_def then
                local half_x = math.floor(building_def.size.x / 2)
                local half_z = math.floor(building_def.size.z / 2)
                
                for x = -half_x, half_x do
                    for y = 0, building_def.size.y-1 do
                        for z = -half_z, half_z do
                            local place_pos = vector.add(destroyed_building.pos, {x=x, y=y, z=z})
                            minetest.set_node(place_pos, {name="tnt:tnt"})
                        end
                    end
                end
                
                minetest.after(1, function(pos)
                    tnt.boom(pos, {damage_radius=5, radius=3})
                end, destroyed_building.pos)
            end
            
            minetest.chat_send_all("☢️ "..country.name.." launched a missile at "..target_country.name..
                "! Their "..(building_def and building_def.name or "building").." was destroyed!")
        else
            minetest.chat_send_all("☢️ "..country.name.." launched a missile at "..target_country.name..
                " but they have no buildings to damage!")
        end
        
        return true, "Missile launched at "..target_country.name
    end
})

-- Building Info Command
minetest.register_chatcommand("buildings", {
    description = "List your country's buildings",
    func = function(name, param)
        local player_data = geopolitical.players[name]
        if not player_data then return false, "Player data not found" end
        
        local country = geopolitical.countries[player_data.country]
        if not country then return false, "Country not found" end
        
        if #country.buildings == 0 then
            return true, "Your country has no buildings yet. Use /build to create some!"
        end
        
        local building_counts = {}
        for _, building in ipairs(country.buildings) do
            building_counts[building.type] = (building_counts[building.type] or 0) + 1
        end
        
        local msg = "Your country's buildings:\n"
        for building_type, count in pairs(building_counts) do
            for _, def in ipairs(geopolitical.BUILDINGS) do
                if def.id == building_type then
                    msg = msg .. string.format("- %s: %d/%d\n", def.name, count, def.limit or 99)
                    break
                end
            end
        end
        
        -- Show missile count if applicable
        if country.can_build_missiles then
            msg = msg .. "\nMissiles: "..(country.missiles or 0)
        end
        
        return true, msg
    end
})
