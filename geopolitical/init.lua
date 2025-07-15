
-- Geopolitical Mod - Fully Refactored with Persistence
-- Note: No guns included. Handles countries, diplomacy, identities, and tech progression.

-- === Config ===
local countries = {"Zarnovia", "Belgrast", "Karelia", "Velturn", "Rhodesia", "Tarkhan", "New Andoria", "Myvak"}
local ranks = {"President", "Soldier", "Engineer", "Citizen"}

local country_spawns = {
    Zarnovia = {x=100, y=10, z=100},
    Belgrast = {x=200, y=10, z=100},
    Karelia = {x=300, y=10, z=100},
    Velturn = {x=400, y=10, z=100},
    Rhodesia = {x=500, y=10, z=100},
    Tarkhan = {x=600, y=10, z=100},
    ["New Andoria"] = {x=700, y=10, z=100},
    Myvak = {x=800, y=10, z=100},
}

-- === Storage & Persistence ===
local base_path = minetest.get_worldpath() .. "/geopolitical_"
local files = {
    diplomacy = base_path .. "diplomacy.txt",
    requests = base_path .. "requests.txt",
    pdata = base_path .. "player_data.txt",
    identities = base_path .. "identities.txt",
    tech = base_path .. "tech_levels.txt",
}

local function save_table(path, table_data)
    local file = io.open(path, "w")
    if file then file:write(minetest.serialize(table_data)) file:close() end
end

local function load_table(path)
    local file = io.open(path, "r")
    if file then local data = file:read("*a") file:close() return minetest.deserialize(data) or {} end
    return {}
end

-- Load on startup
diplomacy = load_table(files.diplomacy)
pending_requests = load_table(files.requests)
player_data = load_table(files.pdata)
player_identities = load_table(files.identities)
country_tech_levels = load_table(files.tech)
tech_trees = {}

-- Example tech tree definition (you can customize this per country)
for _, country in ipairs(countries) do
    tech_trees[country] = {
        unlocked = { "basic_mining" },
        techs = {
            basic_mining = { desc = "Basic mining techniques", unlock_cost = 0 },
            advanced_weapons = { desc = "Advanced weaponry (disabled)", unlock_cost = 5 },
            trade_routes = { desc = "Enables trade infrastructure", unlock_cost = 3 },
            diplomacy_expert = { desc = "Unlocks advanced diplomacy", unlock_cost = 4 },
        }
    }
end

-- Init if empty
for _, c in ipairs(countries) do
    diplomacy[c] = diplomacy[c] or {}
    for _, c2 in ipairs(countries) do
        if c ~= c2 and not diplomacy[c][c2] then
            diplomacy[c][c2] = "peace"
        end
    end
    country_tech_levels[c] = country_tech_levels[c] or 1
end

-- Auto save
local save_timer = 0
minetest.register_globalstep(function(dtime)
    save_timer = save_timer + dtime
    if save_timer > 300 then
        save_table(files.diplomacy, diplomacy)
        save_table(files.requests, pending_requests)
        save_table(files.pdata, player_data)
        save_table(files.identities, player_identities)
        save_table(files.tech, country_tech_levels)
        save_timer = 0
    end
end)

-- Save on shutdown
minetest.register_on_shutdown(function()
    save_table(files.diplomacy, diplomacy)
    save_table(files.requests, pending_requests)
    save_table(files.pdata, player_data)
    save_table(files.identities, player_identities)
    save_table(files.tech, country_tech_levels)
end)



-- Tech tree example (you expand)
for _, c in ipairs(countries) do
    tech_trees[c] = {
        unlocked = { "basic_mining" },  -- start with basic tech
        techs = {
            basic_mining = {desc="Basic mining techniques", unlock_cost=0},
            advanced_weapons = {desc="Advanced weapon tech", unlock_cost=5},
            trade_routes = {desc="Trade routes", unlock_cost=3},
            diplomacy_expert = {desc="Improved diplomacy", unlock_cost=4},
        }
    }
end

local function build_base(pos)
    local base_nodes = {
        {x=0, y=0, z=0, node="default:stone"},
        {x=1, y=0, z=0, node="default:stone"},
        {x=0, y=0, z=1, node="default:stone"},
        {x=1, y=0, z=1, node="default:stone"},
        {x=0, y=1, z=0, node="default:glass"},
        {x=1, y=1, z=0, node="default:glass"},
        {x=0, y=1, z=1, node="default:glass"},
        {x=1, y=1, z=1, node="default:glass"},
    }
    for _, b in ipairs(base_nodes) do
        local p = vector.add(pos, b)
        minetest.set_node(p, {name = b.node})
    end
end

minetest.register_tool("geopolitical:base_tool", {
    description = "Deployable Base Tool",
    inventory_image = "default_tool_steelaxe.png",
    on_use = function(itemstack, user, pointed_thing)
        if pointed_thing.type ~= "node" then return end
        local pos = vector.add(pointed_thing.under, {x=0, y=1, z=0})
        build_base(pos)
        minetest.chat_send_player(user:get_player_name(), "[Geopolitical] Base deployed.")
    end
})

-- Trench Deployment Tool (actual sand & dirt used)
local function build_trench(pos, material)
    local node = material == "sand" and "default:sand" or "default:dirt"
    for dx = -1,1 do
        for dz = -1,1 do
            local p = vector.add(pos, {x=dx, y=0, z=dz})
            minetest.remove_node(p)
            minetest.set_node(p, {name = node})
        end
    end
end

minetest.register_tool("geopolitical:trench_tool_dirt", {
    description = "Dirt Trench Tool",
    inventory_image = "default_tool_bronzepick.png",
    on_use = function(itemstack, user, pointed_thing)
        if pointed_thing.type ~= "node" then return end
        build_trench(pointed_thing.under, "dirt")
        minetest.chat_send_player(user:get_player_name(), "[Geopolitical] Dirt trench built.")
    end
})

minetest.register_tool("geopolitical:trench_tool_sandbag", {
    description = "Sandbag Trench Tool",
    inventory_image = "default_tool_bronzepick.png^[colorize:#ddddaa:80",
    on_use = function(itemstack, user, pointed_thing)
        if pointed_thing.type ~= "node" then return end
        build_trench(pointed_thing.under, "sand")
        minetest.chat_send_player(user:get_player_name(), "[Geopolitical] Sandbag trench built.")
    end
})

-- Missile Launch UI
local function missile_launch_formspec(player_name)
    return [[
        size[6,4]
        label[0,0;Missile Launch Terminal]
        label[0,1;Currently simulated with dirt blocks.]
        button[0,2;5,1;buy_dirt;Simulate Launch (Get Dirt)]
    ]]
end

-- Missile Control Panel Node
minetest.register_node("geopolitical:missile_terminal", {
    description = "Missile Control Terminal",
    tiles = {"default_steel_block.png"},
    groups = {cracky=1},
    on_rightclick = function(pos, node, clicker)
        local name = clicker:get_player_name()
        minetest.show_formspec(name, "geopolitical:missile_ui", missile_launch_formspec(name))
    end
})

-- Silo Builder Tool
local function build_missile_silo(pos)
    for dx = -2, 2 do
        for dz = -2, 2 do
            for dy = 0, 4 do
                local p = vector.add(pos, {x=dx, y=dy, z=dz})
                local wall = (math.abs(dx) == 2 or math.abs(dz) == 2)
                local node = (dy == 4) and "default:glass" or (wall and "default:stone" or "air")
                minetest.set_node(p, {name = node})
            end
        end
    end
    -- Place terminal inside
    minetest.set_node(vector.add(pos, {x=0, y=1, z=0}), {name="geopolitical:missile_terminal"})
end

minetest.register_tool("geopolitical:missile_silo_tool", {
    description = "Missile Silo Builder",
    inventory_image = "default_tool_mese.png",
    on_use = function(itemstack, user, pointed_thing)
        if pointed_thing.type ~= "node" then return end
        local pos = vector.add(pointed_thing.under, {x=0, y=1, z=0})
        build_missile_silo(pos)
        minetest.chat_send_player(user:get_player_name(), "[Geopolitical] Missile silo constructed.")
    end
})
function relations_formspec(player_name, selected_country)
    local pdata = player_data[player_name]
    local my_country = pdata and pdata.country or "None"

    local formspec = "size[8,10]"
    formspec = formspec .. "label[0,0;Relations Overview]"
    formspec = formspec .. "dropdown[0,0.5;6,0.8;country;"..table.concat(countries, ",")..";" .. (table.indexof(countries, selected_country) or 1) .. "]"
    formspec = formspec .. "label[0,1.5;Inspecting country: "..selected_country.."]"

    -- Your relation with selected
    if my_country ~= "None" and my_country ~= selected_country then
        local rel = diplomacy[my_country][selected_country] or "peace"
        formspec = formspec .. "label[0,2.2;Your relation with "..selected_country..": "..rel.."]"
    end

    -- Other pacts of selected country
    formspec = formspec .. "label[0,3.0;"..selected_country.."'s pacts:]"

    local y = 3.5
    for _, other in ipairs(countries) do
        if other ~= selected_country then
            local rel = diplomacy[selected_country][other]
            if rel and rel ~= "peace" then
                formspec = formspec .. string.format("label[0,%f;→ %s: %s]", y, other, rel)
                y = y + 0.5
            end
        end
    end

    return formspec
end

-- Pending Requests helpers
function add_request(to_country, from_country, type)
    pending_requests[to_country] = pending_requests[to_country] or {}
    table.insert(pending_requests[to_country], {from = from_country, type = type})
end

function accept_diplomacy_request(to, from, type, playername)
    diplomacy[to][from] = type
    diplomacy[from][to] = type
    pending_requests[to] = pending_requests[to] or {}
    for i, req in ipairs(pending_requests[to]) do
        if req.from == from and req.type == type then
            table.remove(pending_requests[to], i)
            break
        end
    end
    minetest.chat_send_all("[Diplomacy] "..to.." and "..from.." have agreed on "..type.."!")
end

function reject_diplomacy_request(to, from, type, playername)
    pending_requests[to] = pending_requests[to] or {}
    for i, req in ipairs(pending_requests[to]) do
        if req.from == from and req.type == type then
            table.remove(pending_requests[to], i)
            break
        end
    end
    minetest.chat_send_player(playername, "You rejected "..type.." request from "..from)
end


-- Count players in a country (online + offline)
local function count_country_players(country)
    local count = 0
    for _, data in pairs(player_data) do
        if data.country == country then
            count = count + 1
        end
    end
    return count
end

-- Assign identity name
local first_names = {
    "Alex", "Morgan", "Taylor", "Jordan", "Casey", "Riley", "Quinn", "Parker", "Reese", "Jamie"
}
local last_names = {
    "Stone", "Blaze", "Hawk", "Storm", "Knight", "Fox", "Wolf", "Viper", "Steel", "Shadow"
}
local function generate_identity()
    return first_names[math.random(#first_names)] .. " " .. last_names[math.random(#last_names)]
end

local function give_starter_gear(player)
    local inv = player:get_inventory()
    inv:add_item("main", "default:pick_iron")
    inv:add_item("main", "default:axe_iron")
    inv:add_item("main", "default:sword_iron")
end

local function apply_abilities(player, rank)
    if rank == "Engineer" then
        player:set_physics_override({speed=1.2, jump=1.0})
        minetest.chat_send_player(player:get_player_name(), "[Abilities] Engineer: +20% speed")
    elseif rank == "Soldier" then
        player:set_physics_override({speed=1.0, jump=1.1})
        minetest.chat_send_player(player:get_player_name(), "[Abilities] Soldier: +10% jump")
    elseif rank == "President" then
        player:set_armor_groups({fleshy=75})
        minetest.chat_send_player(player:get_player_name(), "[Abilities] President: Damage resistance")
    else
        player:set_physics_override({speed=1.0, jump=1.0})
        player:set_armor_groups({fleshy=100})
    end
end

local function set_spawn(player, country)
    local pos = country_spawns[country]
    if pos then
        player:set_pos(pos)
    else
        minetest.log("warning", "[geopolitical] No spawn pos for country: "..country)
    end
end

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()

    -- Initialize player data if missing
    if not player_data[name] then
        -- Assign random country, identity, and rank
        local country = countries[math.random(#countries)]
        local identity = generate_identity()
        local count = count_country_players(country)
        local rank = (count == 0) and "President" or "Citizen"
        player_data[name] = {country=country, rank=rank, identity=identity}
        save_table(files.pdata, player_data)
        minetest.chat_send_player(name, "[Geopolitics] Welcome, " ..
            minetest.colorize("#00ff00", identity) ..
            ", you have been assigned to " ..
            minetest.colorize("#00ffff", country) ..
            " as a " .. minetest.colorize("#ffff00", rank) .. ".")
    else
        local info = player_data[name]
        minetest.chat_send_player(name, "[Geopolitics] Welcome back, " ..
            minetest.colorize("#00ff00", info.identity) ..
            ", " .. minetest.colorize("#ffff00", info.rank) ..
            " of " .. minetest.colorize("#00ffff", info.country) .. "!")
    end

    set_spawn(player, player_data[name].country)
    give_starter_gear(player)
    apply_abilities(player, player_data[name].rank)
end)


minetest.register_on_respawnplayer(function(player)
    local name = player:get_player_name()
    local data = player_data[name]
    if data then
        local identity = generate_identity()
        local rank = "Citizen"
        if count_country_players(data.country) == 1 then
            rank = "President"
        end
        player_data[name].identity = identity
        player_data[name].rank = rank
        save_data(name)
        minetest.after(0.5, function()
            minetest.chat_send_player(name, "[Geopolitics] You respawned as " ..
                minetest.colorize("#00ff00", identity) ..
                ", a " .. minetest.colorize("#ffff00", rank) ..
                " of " .. minetest.colorize("#00ffff", data.country) .. ".")
        end)
        set_spawn(player, data.country)
        apply_abilities(player, rank)
        give_starter_gear(player)
    end
end)

-- Chat override
minetest.register_on_chat_message(function(name, message)
    local data = player_data[name]
    if data then
        local identity = data.identity or name
        minetest.chat_send_all("[" .. data.country .. "] " .. identity .. ": " .. message)
        return true
    end
    return false
end)

minetest.register_chatcommand("myinfo", {
    description = "Check your country, rank and identity.",
    func = function(name)
        local info = player_data[name]
        if info then
            return true, string.format("You are %s (%s) of %s.", info.identity, info.rank, info.country)
        else
            return false, "No information found."
        end
    end
})

-- Diplomacy request logic
local function can_manage_diplomacy(player_name)
    local pdata = player_data[player_name]
    return pdata and pdata.rank == "President"
end

local function send_diplomacy_request(from_country, to_country, req_type, player_name)
    if not diplomacy[from_country] or not diplomacy[from_country][to_country] then
        minetest.chat_send_player(player_name, "Invalid countries.")
        return
    end
    -- War requests auto-accepted
    if req_type == "war" then
        diplomacy[from_country][to_country] = "war"
        diplomacy[to_country][from_country] = "war"
        minetest.chat_send_all("[Diplomacy] " .. from_country .. " declared war on " .. to_country .. "!")
        return
    end
    -- For others, add request
    add_request(to_country, from_country, req_type)
    minetest.chat_send_player(player_name, "Request sent for " .. req_type .. " to " .. to_country .. ". Waiting for acceptance.")
end

local function accept_diplomacy_request(to_country, from_country, req_type, player_name)
    local requests = pending_requests[to_country]
    if not requests then return false end
    for i, req in ipairs(requests) do
        if req.from == from_country and req.type == req_type then
            diplomacy[to_country][from_country] = req_type
            diplomacy[from_country][to_country] = req_type
            table.remove(requests, i)
            minetest.chat_send_all("[Diplomacy] " .. to_country .. " accepted " .. req_type .. " with " .. from_country .. ".")
            return true
        end
    end
    return false
end

local function reject_diplomacy_request(to_country, from_country, req_type, player_name)
    local requests = pending_requests[to_country]
    if not requests then return false end
    for i, req in ipairs(requests) do
        if req.from == from_country and req.type == req_type then
            table.remove(requests, i)
            minetest.chat_send_player(player_name, "Request rejected.")
            return true
        end
    end
    return false
end
minetest.register_node("geopolitical:relations_block", {
    description = "Country Relations Viewer",
    tiles = {"default_paper.png"},
    groups = {choppy=2, oddly_breakable_by_hand=2},
    on_rightclick = function(pos, node, player)
        local name = player:get_player_name()
        local pdata = player_data[name]
        local my_country = pdata and pdata.country or "None"
        local country_str = table.concat(countries, ",")
        minetest.show_formspec(name, "geopolitical:relations", relations_formspec(name, countries[1] or "None"))
    end,
})

-- Diplomacy Control Block (for managing diplomacy)
minetest.register_node("geopolitical:diplomacy_block", {
    description = "Diplomacy Block",
    tiles = {"default_wood.png"},
    groups = {choppy = 2, oddly_breakable_by_hand = 2},
    on_rightclick = function(pos, node, player, itemstack, pointed_thing)
        local name = player:get_player_name()
        local pdata = player_data[name]
        if not pdata or pdata.rank ~= "President" then
            minetest.chat_send_player(name, "Only Presidents can use this.")
            return
        end

        local your_country = pdata.country
        local country_list = {}
        for _, c in ipairs(countries) do
            if c ~= your_country then table.insert(country_list, c) end
        end

        local country_str = table.concat(country_list, ",")
        local formspec = "size[7,6]" ..
            "label[0,0;Your country: " .. your_country .. "]" ..
            "dropdown[0,1;5,0.8;target_country;" .. country_str .. ";1]" ..
            "dropdown[0,2;5,0.8;diplomatic_action;Alliance,Non-aggression pact,Army passage pact,Terminate alliance,Terminate non-aggression,Declare war;1]" ..
            "button[0,3;3,1;send_request;Send]"

        minetest.show_formspec(name, "geopolitical:diplomacy_ui", formspec)
    end,
})

function diplomacy_formspec(player_name)
    local pdata = player_data[player_name]
    if not pdata then return "size[6,8]label[1,1;No data found]" end

    local formspec = "size[8,10]label[0,0;Diplomacy Control - Your country: "..pdata.country.."]"

    local y = 1.5
    for i, c1 in ipairs(countries) do
        for j, c2 in ipairs(countries) do
            if i < j then
                local status = diplomacy[c1][c2] or "peace"
                local color = status == "peace" and "#00ff00" or
                              status == "war" and "#ff0000" or
                              status == "non_aggression" and "#ffff00" or
                              status == "alliance" and "#0000ff" or
                              status == "army_pass" and "#ff8800" or
                              "#ffffff"

                formspec = formspec .. string.format(
                    "label[0,%f;%s - %s:]button[5,%f;1,0.5;%s_toggle;%s]",
                    y, c1, c2, y, c1.."_"..c2, status:upper()
                )
                y = y + 0.6
            end
        end
    end

    -- Pending requests section for player's country
    local pend = pending_requests[pdata.country] or {}
    formspec = formspec .. "label[0,"..(y+0.2)..";Pending Requests:]"
    local y2 = y + 1
    for i, req in ipairs(pend) do
        formspec = formspec .. string.format(
            "label[0,%f;%s requests %s]",
            y2, req.from, req.type
        )
        formspec = formspec .. string.format(
            "button[4,%f;1,0.5;accept_%d;Accept]",
            y2, i
        )
        formspec = formspec .. string.format(
            "button[5,%f;1,0.5;reject_%d;Reject]",
            y2, i
        )
        y2 = y2 + 0.6
    end

    return formspec
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    local name = player:get_player_name()
    local pdata = player_data[name]
    if not pdata then return end

    -- Handle Relations Viewer UI
    if formname == "geopolitical:relations" then
        for k, v in pairs(fields) do
            if k == "country" then
                minetest.show_formspec(name, "geopolitical:relations", relations_formspec(name, v))
                return
            end
        end
    end

    -- Handle Diplomacy UI (sending requests)
    if formname == "geopolitical:diplomacy_ui" then
        if pdata.rank ~= "President" then
            minetest.chat_send_player(name, "Only Presidents can use diplomacy.")
            return
        end

        if fields.send_request and fields.target_country and fields.diplomatic_action then
            local from = pdata.country
            local to = fields.target_country
            local action = fields.diplomatic_action

            if from == to then
                minetest.chat_send_player(name, "You cannot target your own country.")
                return
            end

            local map = {
                ["Alliance"] = "alliance",
                ["Non-aggression pact"] = "non_aggression",
                ["Army passage pact"] = "army_pass",
                ["Terminate alliance"] = "remove_alliance",
                ["Terminate non-aggression"] = "remove_non_aggression",
                ["Declare war"] = "war"
            }

            local action_code = map[action]
            if not action_code then
                minetest.chat_send_player(name, "Invalid action.")
                return
            end

            if action_code == "war" then
                diplomacy[from][to] = "war"
                diplomacy[to][from] = "war"
                minetest.chat_send_all("[Diplomacy] "..from.." has declared WAR on "..to.."!")
            elseif action_code == "remove_alliance" then
                if diplomacy[from][to] == "alliance" then
                    diplomacy[from][to] = "peace"
                    diplomacy[to][from] = "peace"
                    minetest.chat_send_all("[Diplomacy] "..from.." has terminated its alliance with "..to..".")
                else
                    minetest.chat_send_player(name, "No alliance exists to terminate.")
                end
            elseif action_code == "remove_non_aggression" then
                if diplomacy[from][to] == "non_aggression" then
                    diplomacy[from][to] = "peace"
                    diplomacy[to][from] = "peace"
                    minetest.chat_send_all("[Diplomacy] "..from.." has ended the non-aggression pact with "..to..".")
                else
                    minetest.chat_send_player(name, "No non-aggression pact exists.")
                end
            else
                add_request(to, from, action_code)
                minetest.chat_send_player(name, "Request sent to "..to.." for: "..action_code)
            end
        end
        return
    end

    -- Handle Diplomacy Request Viewer (for receiving/accepting/rejecting)
    if formname == "geopolitical:diplomacy" then
        if pdata.rank ~= "President" then
            minetest.chat_send_player(name, "Only Presidents can handle diplomacy.")
            return
        end

        for key, _ in pairs(fields) do
            -- Accepting request
            if key:match("^accept_%d+$") then
                local idx = tonumber(key:match("^accept_(%d+)$"))
                local pend = pending_requests[pdata.country] or {}
                local req = pend[idx]
                if req then
                    accept_diplomacy_request(pdata.country, req.from, req.type, name)
                end
                minetest.show_formspec(name, "geopolitical:diplomacy", diplomacy_formspec(name))
                return

            -- Rejecting request
            elseif key:match("^reject_%d+$") then
                local idx = tonumber(key:match("^reject_(%d+)$"))
                local pend = pending_requests[pdata.country] or {}
                local req = pend[idx]
                if req then
                    reject_diplomacy_request(pdata.country, req.from, req.type, name)
                end
                minetest.show_formspec(name, "geopolitical:diplomacy", diplomacy_formspec(name))
                return
            end
        end
    end
end)



minetest.register_node("geopolitical:tech_upgrade_block", {
    description = "Tech Upgrade Block",
    tiles = {"default_gold_block.png"},
    groups = {cracky=2, oddly_breakable_by_hand=2},
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_string("infotext", "Tech Upgrade Block (Insert gold to upgrade your country's tech level)")
        meta:set_int("upgrade_cost", 1) -- cost in gold per upgrade (change later)
    end,
    on_receive_fields = function(pos, formname, fields, sender)
        -- Optional: implement form for upgrades if needed
    end,
    on_metadata_inventory_put = function(pos, listname, index, stack, player)
        local name = player:get_player_name()
        local pdata = player_data[name]
        if not pdata then
            minetest.chat_send_player(name, "No geopolitical data assigned.")
            return
        end
        if pdata.rank ~= "President" then
            minetest.chat_send_player(name, "Only Presidents can upgrade tech.")
            return
        end

        -- Check inserted item is gold lump
local allowed_ores = {
    ["default:gold_lump"] = 1,
    ["default:diamond"] = 3,
    ["default:mese_crystal"] = 5,
}

local ore_value = allowed_ores[stack:get_name()]
if not ore_value then
    minetest.chat_send_player(name, "Only certain ores can be used to upgrade tech.")
    return
end

local total_value = ore_value * stack:get_count()
country_tech_levels[pdata.country] = (country_tech_levels[pdata.country] or 1) + total_value

minetest.chat_send_all("[Tech] " .. pdata.country .. " tech level increased to " .. country_tech_levels[pdata.country])

    end,
    on_metadata_inventory_move = function() end,
    on_metadata_inventory_take = function() end,
    on_metadata_inventory_list = function() end,
})


-- Relations Info Block

minetest.register_node("geopolitical:relations_block", {
    description = "Country Relations Info Block",
    tiles = {"default_stone.png"},
    groups = {cracky=2, oddly_breakable_by_hand=2},
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_string("formspec", relations_formspec(nil))
        meta:set_string("infotext", "Relations Info Block")
    end,
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        local name = clicker:get_player_name()
        minetest.show_formspec(name, "geopolitical:relations", relations_formspec(name))
    end,
})

-- Relations form: choose country to inspect and show relations with your country
function relations_formspec(player_name, selected_country)
    selected_country = selected_country or countries[1]
    local pdata = player_data[player_name]
    local my_country = pdata and pdata.country or "None"
    local formspec = "size[8,10]label[0,0;Relations Info]dropdown[0,0.5;4,1;country;"..table.concat(countries, ",")..";"..(table.indexof(countries, selected_country) or 1).."]"
    formspec = formspec .. string.format("label[0,1.8;Your country: %s]", my_country)
    formspec = formspec .. "label[0,2.4;Relations with "..selected_country..":]"

    for _, c in ipairs(countries) do
        if c ~= selected_country then
            local rel = diplomacy[selected_country][c] or "peace"
            formspec = formspec .. string.format("label[0,%f;%s - %s: %s]", 2.4 + 0.6 * _, selected_country, c, rel)
        end
    end

    if my_country ~= "None" then
        local my_rel = diplomacy[my_country][selected_country] or "peace"
        formspec = formspec .. string.format("label[0,9;Your country (%s) status with %s: %s]", my_country, selected_country, my_rel)
    end

    return formspec
end



-- Tech Trees (you can extend and hook effects)

minetest.register_chatcommand("techs", {
    description = "Show your country's tech tree",
    func = function(name)
        local pdata = player_data[name]
        if not pdata then
            return false, "No data."
        end
        local tech = tech_trees[pdata.country]
        if not tech then
            return false, "No tech tree for your country."
        end
        local unlocked = tech.unlocked
        local lines = {"Unlocked techs:"}
        for _, t in ipairs(unlocked) do
            lines[#lines+1] = "- " .. t .. ": " .. tech.techs[t].desc
        end
        return true, table.concat(lines, "\n")
    end
})


-- Tech Tree Expansion
if not tech_trees then tech_trees = {} end
for _, c in ipairs(countries or {}) do
    tech_trees[c] = tech_trees[c] or { unlocked={}, techs={} }
    tech_trees[c].techs["missiles"] = {
        desc = "Unlock long-range missiles.",
        unlock_cost = 10
    }
    tech_trees[c].techs["trenches"] = {
        desc = "Allow construction of trenches.",
        unlock_cost = 3
    }
    tech_trees[c].techs["outposts"] = {
        desc = "Enable deployment of small outposts.",
        unlock_cost = 5
    }
end

-- Presidential Dashboard Block
minetest.register_node("geopolitical:dashboard_block", {
    description = "Presidential Dashboard",
    tiles = {"default_meselamp.png"},
    groups = {cracky=1},
    on_rightclick = function(pos, node, clicker)
        local name = clicker:get_player_name()
        minetest.show_formspec(name, "geopolitical:dashboard", geopolitical.dashboard_formspec(name))
    end
})

geopolitical = geopolitical or {}
function geopolitical.dashboard_formspec(name)
    local pdata = player_data[name]
    if not pdata or pdata.rank ~= "President" then
        return "size[6,3]label[0,1;Access denied. Presidents only.]"
    end
    local c = pdata.country
    local tech = country_tech_levels[c] or 1
    local pend = pending_requests[c] or {}

    local fs = "size[9,9]label[0,0;President Dashboard for "..c.."]" ..
        "label[0,1;Tech Level: "..tech.."]" ..
        "label[0,1.5;Unlocked Techs:]"

    local y = 2
    for _, t in ipairs(tech_trees[c].unlocked or {}) do
        fs = fs .. "label[0,"..y..";- "..t.."]"
        y = y + 0.4
    end

    fs = fs .. "label[5,1.5;Pending Diplomacy:]"
    for i, req in ipairs(pend) do
        fs = fs .. string.format("label[5,%f;%s -> %s (%s)]", 1.9 + i * 0.5, req.from, c, req.type)
    end

    return fs
end

-- Handle missile UI response
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "geopolitical:missile_ui" and fields.buy_dirt then
        local inv = player:get_inventory()
        inv:add_item("main", "default:dirt")
        minetest.chat_send_player(player:get_player_name(), "[Silo] Missile simulated: 1x dirt received.")
    end
end)


