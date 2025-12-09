--[[
    AI Assistant Tools
    Implements all the actions the AI can perform in-game.
    This is a comprehensive general-purpose toolset.
]]

-- Ensure AIAssistant global exists (handles load order)
AIAssistant = AIAssistant or {}
AIAssistant.Tools = AIAssistant.Tools or {}
AIAssistant.Tools.Registry = {}

-- Register a tool
function AIAssistant.Tools.Register(name, description, handler)
    AIAssistant.Tools.Registry[name] = {
        name = name,
        description = description,
        handler = handler
    }
    AIAssistant.Debug("Registered tool:", name)
end

-- Execute a tool
function AIAssistant.Tools.Execute(name, args, ply)
    local tool = AIAssistant.Tools.Registry[name]
    
    if not tool then
        return false, "Unknown tool: " .. name
    end
    
    local success, result = pcall(tool.handler, args, ply)
    
    if not success then
        AIAssistant.Debug("Tool error:", name, result)
        return false, "Tool execution error: " .. tostring(result)
    end
    
    return true, result
end

-- Helper: Parse position from string or table
local function ParsePosition(input, ply)
    if not input then return nil end
    
    -- If it's a table with x,y,z
    if type(input) == "table" then
        if input.x and input.y and input.z then
            return Vector(input.x, input.y, input.z)
        end
    end
    
    -- If it's a string
    if type(input) == "string" then
        -- Check for special positions relative to player
        if IsValid(ply) then
            local pos = ply:GetPos()
            local forward = ply:GetAimVector()
            local right = ply:GetRight()
            
            if input == "in_front" or input == "front" then
                return pos + forward * 100
            elseif input == "behind" or input == "back" then
                return pos - forward * 100
            elseif input == "left" then
                return pos - right * 100
            elseif input == "right" then
                return pos + right * 100
            elseif input == "above" then
                return pos + Vector(0, 0, 100)
            elseif input == "here" or input == "player" then
                return pos
            elseif input == "looking_at" or input == "aim" then
                local tr = ply:GetEyeTrace()
                return tr.HitPos + tr.HitNormal * 50
            end
        end
        
        -- Try to parse as "x,y,z"
        local parts = string.Explode(",", input)
        if #parts == 3 then
            local x = tonumber(string.Trim(parts[1]))
            local y = tonumber(string.Trim(parts[2]))
            local z = tonumber(string.Trim(parts[3]))
            if x and y and z then
                return Vector(x, y, z)
            end
        end
    end
    
    return nil
end

-- Helper: Get a position with fallback
local function GetPosition(args, ply, key)
    key = key or "position"
    local pos = ParsePosition(args[key], ply)
    
    if not pos and IsValid(ply) then
        -- Default: in front of player at ground level
        local tr = ply:GetEyeTrace()
        pos = tr.HitPos + tr.HitNormal * 20
    end
    
    return pos or Vector(0, 0, 0)
end

-- ============================================
-- SPAWNING TOOLS
-- ============================================

AIAssistant.Tools.Register("spawn_prop", "Spawn a prop/model in the world", function(args, ply)
    local model = args.model
    
    if not model then
        return {success = false, error = "No model specified"}
    end
    
    -- Add models/ prefix if not present
    if not string.StartWith(model, "models/") then
        model = "models/" .. model
    end
    
    -- Add .mdl extension if not present
    if not string.EndsWith(model, ".mdl") then
        model = model .. ".mdl"
    end
    
    local pos = GetPosition(args, ply)
    local ang = Angle(args.pitch or 0, args.yaw or 0, args.roll or 0)
    
    local prop = ents.Create("prop_physics")
    prop:SetModel(model)
    prop:SetPos(pos)
    prop:SetAngles(ang)
    prop:Spawn()
    prop:Activate()
    
    -- Set owner for cleanup
    if IsValid(ply) then
        prop:SetOwner(ply)
        if prop.CPPISetOwner then
            prop:CPPISetOwner(ply)
        end
    end
    
    -- Optional: freeze the prop
    if args.frozen then
        local phys = prop:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
        end
    end
    
    return {
        success = true,
        entity_id = prop:EntIndex(),
        model = model,
        position = {x = pos.x, y = pos.y, z = pos.z}
    }
end)

AIAssistant.Tools.Register("spawn_npc", "Spawn one or more NPCs", function(args, ply)
    local npcType = args.npc_type or args.type or "npc_citizen"
    local count = math.Clamp(tonumber(args.count) or 1, 1, 20)  -- Max 20 for performance
    
    -- NPC type aliases
    local npcAliases = {
        zombie = "npc_zombie",
        fastzombie = "npc_fastzombie",
        headcrab = "npc_headcrab",
        antlion = "npc_antlion",
        combine = "npc_combine_s",
        soldier = "npc_combine_s",
        metro = "npc_metropolice",
        police = "npc_metropolice",
        citizen = "npc_citizen",
        alyx = "npc_alyx",
        barney = "npc_barney",
        kleiner = "npc_kleiner",
        dog = "npc_dog",
        turret = "npc_turret_floor",
        strider = "npc_strider",
        gunship = "npc_combinegunship",
        hunter = "npc_hunter",
        vortigaunt = "npc_vortigaunt",
        crow = "npc_crow",
        seagull = "npc_seagull",
        pigeon = "npc_pigeon",
    }
    
    npcType = npcAliases[string.lower(npcType)] or npcType
    
    -- Add npc_ prefix if not present
    if not string.StartWith(npcType, "npc_") then
        npcType = "npc_" .. npcType
    end
    
    local basePos = GetPosition(args, ply)
    local spawned = {}
    local failed = 0
    
    for i = 1, count do
        -- Spread NPCs in a circle around the base position
        local offset = Vector(0, 0, 0)
        if i > 1 then
            local angle = (i - 1) * (360 / (count - 1)) * (math.pi / 180)
            local radius = 50 + (count * 10)  -- Increase radius based on count
            offset = Vector(math.cos(angle) * radius, math.sin(angle) * radius, 0)
        end
        local pos = basePos + offset
        
        local npc = ents.Create(npcType)
        if not IsValid(npc) then
            failed = failed + 1
            if i == 1 then
                -- First one failed, return error
                return {success = false, error = "Invalid NPC type: " .. npcType}
            end
        else
            npc:SetPos(pos)
            
            -- Set weapon if specified
            if args.weapon then
                local weapon = args.weapon
                if not string.StartWith(weapon, "weapon_") then
                    weapon = "weapon_" .. weapon
                end
                npc:SetKeyValue("additionalequipment", weapon)
            end
            
            npc:Spawn()
            npc:Activate()
            
            -- Make friendly or hostile
            if args.friendly and IsValid(ply) then
                npc:AddEntityRelationship(ply, D_LI, 99)
            elseif args.hostile and IsValid(ply) then
                npc:AddEntityRelationship(ply, D_HT, 99)
            end
            
            table.insert(spawned, npc:EntIndex())
        end
    end
    
    return {
        success = true,
        count = #spawned,
        entity_ids = spawned,
        npc_type = npcType,
        position = {x = basePos.x, y = basePos.y, z = basePos.z}
    }
end)

AIAssistant.Tools.Register("spawn_entity", "Spawn any entity class", function(args, ply)
    local class = args.class or args.entity_class
    
    if not class then
        return {success = false, error = "No entity class specified"}
    end
    
    local pos = GetPosition(args, ply)
    local ang = Angle(args.pitch or 0, args.yaw or 0, args.roll or 0)
    
    local ent = ents.Create(class)
    if not IsValid(ent) then
        return {success = false, error = "Invalid entity class: " .. class}
    end
    
    ent:SetPos(pos)
    ent:SetAngles(ang)
    
    -- Apply custom properties
    if args.properties and type(args.properties) == "table" then
        for key, value in pairs(args.properties) do
            if type(value) == "string" or type(value) == "number" then
                ent:SetKeyValue(key, tostring(value))
            end
        end
    end
    
    ent:Spawn()
    ent:Activate()
    
    if IsValid(ply) then
        ent:SetOwner(ply)
    end
    
    return {
        success = true,
        entity_id = ent:EntIndex(),
        class = class,
        position = {x = pos.x, y = pos.y, z = pos.z}
    }
end)

AIAssistant.Tools.Register("spawn_vehicle", "Spawn a vehicle", function(args, ply)
    local vehicleType = args.vehicle_type or args.type or "jeep"
    
    -- Vehicle aliases
    local vehicleData = {
        jeep = {class = "prop_vehicle_jeep", model = "models/buggy.mdl", script = "scripts/vehicles/jeep_test.txt"},
        airboat = {class = "prop_vehicle_airboat", model = "models/airboat.mdl", script = "scripts/vehicles/airboat.txt"},
        jalopy = {class = "prop_vehicle_jeep", model = "models/vehicle.mdl", script = "scripts/vehicles/jalopy.txt"},
        pod = {class = "prop_vehicle_prisoner_pod", model = "models/vehicles/prisoner_pod.mdl", script = "scripts/vehicles/prisoner_pod.txt"},
    }
    
    local data = vehicleData[string.lower(vehicleType)] or vehicleData.jeep
    local pos = GetPosition(args, ply)
    
    local vehicle = ents.Create(data.class)
    if not IsValid(vehicle) then
        return {success = false, error = "Failed to create vehicle"}
    end
    
    vehicle:SetModel(data.model)
    vehicle:SetPos(pos + Vector(0, 0, 50))
    vehicle:SetAngles(Angle(0, IsValid(ply) and ply:EyeAngles().y or 0, 0))
    vehicle:SetKeyValue("vehiclescript", data.script)
    vehicle:Spawn()
    vehicle:Activate()
    
    return {
        success = true,
        entity_id = vehicle:EntIndex(),
        vehicle_type = vehicleType
    }
end)

-- ============================================
-- PLAYER TOOLS
-- ============================================

AIAssistant.Tools.Register("teleport_player", "Teleport the requesting player", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player to teleport"}
    end
    
    local pos = nil
    
    -- Named locations
    if args.location or args.landmark then
        local loc = string.lower(args.location or args.landmark)
        
        -- Check for spawn points
        if loc == "spawn" then
            local spawns = ents.FindByClass("info_player_start")
            if #spawns > 0 then
                pos = spawns[1]:GetPos()
            end
        elseif loc == "random" then
            -- Random position on the map
            local mins, maxs = game.GetWorld():GetModelBounds()
            local attempts = 0
            while attempts < 20 and not pos do
                local testPos = Vector(
                    math.Rand(mins.x + 500, maxs.x - 500),
                    math.Rand(mins.y + 500, maxs.y - 500),
                    maxs.z - 100
                )
                -- Trace down to find ground
                local tr = util.TraceLine({
                    start = testPos,
                    endpos = testPos - Vector(0, 0, 10000),
                    mask = MASK_SOLID_BRUSHONLY
                })
                if tr.Hit then
                    pos = tr.HitPos + Vector(0, 0, 10)
                end
                attempts = attempts + 1
            end
        elseif loc == "far" then
            -- Far from current position
            local currentPos = ply:GetPos()
            local mins, maxs = game.GetWorld():GetModelBounds()
            local bestPos = nil
            local bestDist = 0
            
            for i = 1, 10 do
                local testPos = Vector(
                    math.Rand(mins.x + 500, maxs.x - 500),
                    math.Rand(mins.y + 500, maxs.y - 500),
                    maxs.z - 100
                )
                local tr = util.TraceLine({
                    start = testPos,
                    endpos = testPos - Vector(0, 0, 10000),
                    mask = MASK_SOLID_BRUSHONLY
                })
                if tr.Hit then
                    local dist = tr.HitPos:Distance(currentPos)
                    if dist > bestDist then
                        bestDist = dist
                        bestPos = tr.HitPos + Vector(0, 0, 10)
                    end
                end
            end
            pos = bestPos
        end
    end
    
    -- Parse position if not a named location
    if not pos and args.position then
        -- Clean up position string - remove parentheses and spaces
        local cleanPos = args.position
        if type(cleanPos) == "string" then
            cleanPos = string.gsub(cleanPos, "[%(%)%s]", "")
        end
        pos = ParsePosition(cleanPos, ply)
    end
    
    if not pos then
        return {success = false, error = "Invalid position. Use format: 'x,y,z' (e.g., '1000,2000,-12288') or location: 'spawn', 'random', 'far'"}
    end
    
    ply:SetPos(pos)
    
    return {
        success = true,
        position = {x = math.Round(pos.x), y = math.Round(pos.y), z = math.Round(pos.z)}
    }
end)

AIAssistant.Tools.Register("set_player_health", "Set player health", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local health = tonumber(args.health or args.value)
    if not health then
        return {success = false, error = "Invalid health value"}
    end
    
    health = math.Clamp(health, 0, 1000)
    ply:SetHealth(health)
    
    return {success = true, health = health}
end)

AIAssistant.Tools.Register("set_player_armor", "Set player armor", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local armor = tonumber(args.armor or args.value)
    if not armor then
        return {success = false, error = "Invalid armor value"}
    end
    
    armor = math.Clamp(armor, 0, 255)
    ply:SetArmor(armor)
    
    return {success = true, armor = armor}
end)

AIAssistant.Tools.Register("give_weapon", "Give a weapon to the player", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local weapon = args.weapon or args.weapon_class
    if not weapon then
        return {success = false, error = "No weapon specified"}
    end
    
    -- Weapon aliases
    local weaponAliases = {
        crowbar = "weapon_crowbar",
        pistol = "weapon_pistol",
        smg = "weapon_smg1",
        shotgun = "weapon_shotgun",
        ar2 = "weapon_ar2",
        rifle = "weapon_ar2",
        rpg = "weapon_rpg",
        crossbow = "weapon_crossbow",
        grenade = "weapon_frag",
        frag = "weapon_frag",
        physcannon = "weapon_physcannon",
        gravgun = "weapon_physcannon",
        physgun = "weapon_physgun",
        toolgun = "gmod_tool",
        slam = "weapon_slam",
        bugbait = "weapon_bugbait",
        stunstick = "weapon_stunstick",
        ["357"] = "weapon_357",
        magnum = "weapon_357",
    }
    
    -- Ammo type mapping for weapons
    local weaponAmmoTypes = {
        weapon_smg1 = "smg1",
        weapon_ar2 = "ar2",
        weapon_pistol = "pistol",
        weapon_357 = "357",
        weapon_shotgun = "buckshot",
        weapon_crossbow = "xbowbolt",
        weapon_rpg = "rpg_round",
    }
    
    weapon = weaponAliases[string.lower(weapon)] or weapon
    
    -- Add weapon_ prefix if not present
    if not string.StartWith(weapon, "weapon_") and not string.StartWith(weapon, "gmod_") then
        weapon = "weapon_" .. weapon
    end
    
    ply:Give(weapon)
    
    -- Give ammo if requested
    local ammoGiven = 0
    if args.ammo and tonumber(args.ammo) then
        local ammoType = weaponAmmoTypes[weapon]
        if ammoType then
            ammoGiven = tonumber(args.ammo)
            ply:GiveAmmo(ammoGiven, ammoType, true)
        end
    end
    
    return {success = true, weapon = weapon, ammo_given = ammoGiven}
end)

AIAssistant.Tools.Register("give_ammo", "Give ammo to the player", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local ammoType = args.ammo_type or args.type
    if not ammoType then
        return {success = false, error = "No ammo type specified"}
    end
    
    -- Ammo type aliases
    local ammoAliases = {
        smg = "smg1",
        smg1 = "smg1",
        ar2 = "ar2",
        pistol = "pistol",
        ["357"] = "357",
        magnum = "357",
        shotgun = "buckshot",
        buckshot = "buckshot",
        crossbow = "xbowbolt",
        xbow = "xbowbolt",
        rpg = "rpg_round",
        grenade = "grenade",
        slam = "slam",
    }
    
    ammoType = ammoAliases[string.lower(ammoType)] or ammoType
    local amount = tonumber(args.amount) or 100
    
    ply:GiveAmmo(amount, ammoType, true)
    
    return {success = true, ammo_type = ammoType, amount = amount}
end)

AIAssistant.Tools.Register("set_player_model", "Change player model", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local model = args.model
    if not model then
        return {success = false, error = "No model specified"}
    end
    
    -- Model aliases
    local modelAliases = {
        kleiner = "models/player/kleiner.mdl",
        alyx = "models/player/alyx.mdl",
        barney = "models/player/barney.mdl",
        breen = "models/player/breen.mdl",
        gman = "models/player/gman_high.mdl",
        monk = "models/player/monk.mdl",
        mossman = "models/player/mossman.mdl",
        eli = "models/player/eli.mdl",
        zombie = "models/player/zombie_classic.mdl",
        combine = "models/player/combine_soldier.mdl",
        soldier = "models/player/combine_soldier.mdl",
        police = "models/player/police.mdl",
    }
    
    model = modelAliases[string.lower(model)] or model
    
    if not string.StartWith(model, "models/") then
        model = "models/player/" .. model .. ".mdl"
    end
    
    ply:SetModel(model)
    
    return {success = true, model = model}
end)

AIAssistant.Tools.Register("set_player_speed", "Set player movement speed", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local walk = tonumber(args.walk_speed or args.walk)
    local run = tonumber(args.run_speed or args.run)
    
    if walk then
        ply:SetWalkSpeed(math.Clamp(walk, 10, 2000))
    end
    
    if run then
        ply:SetRunSpeed(math.Clamp(run, 10, 2000))
    end
    
    return {
        success = true,
        walk_speed = ply:GetWalkSpeed(),
        run_speed = ply:GetRunSpeed()
    }
end)

AIAssistant.Tools.Register("set_player_scale", "Change player size", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local scale = tonumber(args.scale or args.size) or 1
    scale = math.Clamp(scale, 0.1, 10)
    
    ply:SetModelScale(scale)
    
    return {success = true, scale = scale}
end)

AIAssistant.Tools.Register("respawn_player", "Respawn the player", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    ply:Spawn()
    
    return {success = true}
end)

AIAssistant.Tools.Register("kill_player", "Kill the player", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    ply:Kill()
    
    return {success = true}
end)

AIAssistant.Tools.Register("godmode", "Toggle god mode for player", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local enable = args.enable
    if enable == nil then
        -- Toggle
        enable = not ply:HasGodMode()
    end
    
    if enable then
        ply:GodEnable()
    else
        ply:GodDisable()
    end
    
    return {success = true, godmode = enable}
end)

AIAssistant.Tools.Register("noclip", "Toggle noclip for player", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local enable = args.enable
    if enable == nil then
        -- Toggle
        enable = ply:GetMoveType() ~= MOVETYPE_NOCLIP
    end
    
    if enable then
        ply:SetMoveType(MOVETYPE_NOCLIP)
    else
        ply:SetMoveType(MOVETYPE_WALK)
    end
    
    return {success = true, noclip = enable}
end)

-- ============================================
-- WORLD TOOLS
-- ============================================

AIAssistant.Tools.Register("set_gravity", "Set world gravity", function(args, ply)
    local gravity = args.gravity or args.value
    
    -- Named gravity presets
    local gravityPresets = {
        normal = 600,
        earth = 600,
        moon = 100,
        mars = 227,
        jupiter = 1500,
        zero = 0,
        low = 200,
        high = 1000,
    }
    
    if type(gravity) == "string" then
        gravity = gravityPresets[string.lower(gravity)] or tonumber(gravity)
    end
    
    if not gravity then
        return {success = false, error = "Invalid gravity value"}
    end
    
    gravity = math.Clamp(gravity, 0, 10000)
    game.ConsoleCommand("sv_gravity " .. gravity .. "\n")
    
    return {success = true, gravity = gravity}
end)

AIAssistant.Tools.Register("set_timescale", "Set game time scale (slow motion)", function(args, ply)
    local scale = tonumber(args.scale or args.value) or 1
    scale = math.Clamp(scale, 0.1, 5)
    
    game.ConsoleCommand("host_timescale " .. scale .. "\n")
    
    return {success = true, timescale = scale}
end)

AIAssistant.Tools.Register("set_time", "Set time of day", function(args, ply)
    local time = args.time
    
    -- Try to set env_sun or light_environment
    local sun = ents.FindByClass("env_sun")[1]
    local lightEnv = ents.FindByClass("light_environment")[1]
    
    -- This is limited in source engine, but we can try
    if time == "night" or time == "dark" then
        game.ConsoleCommand("mat_fullbright 0\n")
    elseif time == "bright" or time == "fullbright" then
        game.ConsoleCommand("mat_fullbright 1\n")
    end
    
    return {success = true, time = time}
end)

AIAssistant.Tools.Register("explode", "Create an explosion", function(args, ply)
    local pos = GetPosition(args, ply)
    local magnitude = tonumber(args.magnitude or args.power) or 100
    magnitude = math.Clamp(magnitude, 10, 1000)
    
    local explosion = ents.Create("env_explosion")
    explosion:SetPos(pos)
    explosion:SetKeyValue("iMagnitude", magnitude)
    explosion:Spawn()
    explosion:Fire("Explode", "", 0)
    
    return {
        success = true,
        position = {x = pos.x, y = pos.y, z = pos.z},
        magnitude = magnitude
    }
end)

AIAssistant.Tools.Register("create_fire", "Create fire at a location", function(args, ply)
    local pos = GetPosition(args, ply)
    local size = tonumber(args.size) or 128
    
    local fire = ents.Create("env_fire")
    fire:SetPos(pos)
    fire:SetKeyValue("firesize", size)
    fire:SetKeyValue("health", 30)
    fire:SetKeyValue("fireattack", 4)
    fire:SetKeyValue("StartDisabled", "0")
    fire:Spawn()
    fire:Activate()
    fire:Fire("StartFire", "", 0)
    
    return {success = true, position = {x = pos.x, y = pos.y, z = pos.z}}
end)

AIAssistant.Tools.Register("cleanup", "Remove entities", function(args, ply)
    local targetClass = args.class
    local radius = tonumber(args.radius) or 0
    local count = 0
    
    local entsToRemove = {}
    
    if targetClass then
        -- Remove specific class
        entsToRemove = ents.FindByClass(targetClass)
    elseif args.all_props then
        -- Remove all props
        entsToRemove = ents.FindByClass("prop_physics*")
    elseif args.all_npcs then
        -- Remove all NPCs
        for _, ent in ipairs(ents.GetAll()) do
            if ent:IsNPC() then
                table.insert(entsToRemove, ent)
            end
        end
    elseif args.all then
        -- Remove everything spawned (not map entities)
        for _, ent in ipairs(ents.GetAll()) do
            if ent:CreatedByMap() == false and not ent:IsPlayer() then
                table.insert(entsToRemove, ent)
            end
        end
    end
    
    -- Filter by radius if specified
    if radius > 0 and IsValid(ply) then
        local center = ply:GetPos()
        local filtered = {}
        for _, ent in ipairs(entsToRemove) do
            if ent:GetPos():Distance(center) <= radius then
                table.insert(filtered, ent)
            end
        end
        entsToRemove = filtered
    end
    
    -- Remove the entities
    for _, ent in ipairs(entsToRemove) do
        if IsValid(ent) then
            ent:Remove()
            count = count + 1
        end
    end
    
    return {success = true, removed_count = count}
end)

-- ============================================
-- INFORMATION TOOLS
-- ============================================

AIAssistant.Tools.Register("get_player_info", "Get information about the requesting player", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local pos = ply:GetPos()
    local weapon = ply:GetActiveWeapon()
    
    return {
        success = true,
        name = ply:Nick(),
        steamid = ply:SteamID64(),
        health = ply:Health(),
        armor = ply:Armor(),
        position = {x = math.Round(pos.x), y = math.Round(pos.y), z = math.Round(pos.z)},
        weapon = IsValid(weapon) and weapon:GetClass() or "none",
        is_alive = ply:Alive(),
        is_admin = ply:IsAdmin(),
        team = team.GetName(ply:Team()),
        model = ply:GetModel()
    }
end)

AIAssistant.Tools.Register("get_entities_nearby", "Get list of entities near the player", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local radius = tonumber(args.radius) or 500
    local center = ply:GetPos()
    local entities = {}
    
    for _, ent in ipairs(ents.FindInSphere(center, radius)) do
        if IsValid(ent) and ent ~= ply then
            local pos = ent:GetPos()
            table.insert(entities, {
                id = ent:EntIndex(),
                class = ent:GetClass(),
                model = ent:GetModel() or "",
                distance = math.Round(pos:Distance(center)),
                is_npc = ent:IsNPC(),
                is_player = ent:IsPlayer(),
                name = ent:IsPlayer() and ent:Nick() or nil
            })
            
            -- Limit to 20 entities
            if #entities >= 20 then break end
        end
    end
    
    return {success = true, entities = entities, count = #entities}
end)

AIAssistant.Tools.Register("get_server_info", "Get information about the server", function(args, ply)
    local players = {}
    for _, p in ipairs(player.GetAll()) do
        table.insert(players, {
            name = p:Nick(),
            steamid = p:SteamID64(),
            is_admin = p:IsAdmin()
        })
    end
    
    return {
        success = true,
        server_name = GetHostName(),
        map = game.GetMap(),
        gamemode = engine.ActiveGamemode(),
        player_count = #players,
        max_players = game.MaxPlayers(),
        players = players,
        tickrate = math.Round(1 / engine.TickInterval())
    }
end)

AIAssistant.Tools.Register("get_map_entities", "Get list of entity classes on the map", function(args, ply)
    local classCount = {}
    
    for _, ent in ipairs(ents.GetAll()) do
        local class = ent:GetClass()
        classCount[class] = (classCount[class] or 0) + 1
    end
    
    local result = {}
    for class, count in pairs(classCount) do
        table.insert(result, {class = class, count = count})
    end
    
    -- Sort by count
    table.sort(result, function(a, b) return a.count > b.count end)
    
    -- Limit to top 30
    local limited = {}
    for i = 1, math.min(30, #result) do
        table.insert(limited, result[i])
    end
    
    return {success = true, entity_classes = limited}
end)

-- ============================================
-- ENTITY MANIPULATION TOOLS
-- ============================================

AIAssistant.Tools.Register("remove_entity", "Remove a specific entity by ID", function(args, ply)
    local id = tonumber(args.entity_id or args.id)
    if not id then
        return {success = false, error = "No entity ID specified"}
    end
    
    local ent = Entity(id)
    if not IsValid(ent) then
        return {success = false, error = "Entity not found"}
    end
    
    if ent:IsPlayer() then
        return {success = false, error = "Cannot remove players"}
    end
    
    local class = ent:GetClass()
    ent:Remove()
    
    return {success = true, removed_class = class}
end)

AIAssistant.Tools.Register("set_entity_color", "Set entity color", function(args, ply)
    local id = tonumber(args.entity_id or args.id)
    local ent = id and Entity(id) or nil
    
    -- If no ID, use what player is looking at
    if not IsValid(ent) and IsValid(ply) then
        local tr = ply:GetEyeTrace()
        ent = tr.Entity
    end
    
    if not IsValid(ent) then
        return {success = false, error = "No valid entity"}
    end
    
    local r = tonumber(args.r or args.red) or 255
    local g = tonumber(args.g or args.green) or 255
    local b = tonumber(args.b or args.blue) or 255
    local a = tonumber(args.a or args.alpha) or 255
    
    -- Color presets
    local colorPresets = {
        red = {255, 0, 0},
        green = {0, 255, 0},
        blue = {0, 0, 255},
        yellow = {255, 255, 0},
        purple = {128, 0, 128},
        orange = {255, 165, 0},
        pink = {255, 192, 203},
        white = {255, 255, 255},
        black = {0, 0, 0},
        invisible = {255, 255, 255, 0},
    }
    
    if args.color and colorPresets[string.lower(args.color)] then
        local preset = colorPresets[string.lower(args.color)]
        r, g, b = preset[1], preset[2], preset[3]
        a = preset[4] or 255
    end
    
    ent:SetColor(Color(r, g, b, a))
    ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
    
    return {success = true, color = {r = r, g = g, b = b, a = a}}
end)

AIAssistant.Tools.Register("set_entity_material", "Set entity material/texture", function(args, ply)
    local id = tonumber(args.entity_id or args.id)
    local ent = id and Entity(id) or nil
    
    if not IsValid(ent) and IsValid(ply) then
        local tr = ply:GetEyeTrace()
        ent = tr.Entity
    end
    
    if not IsValid(ent) then
        return {success = false, error = "No valid entity"}
    end
    
    local material = args.material
    
    -- Material presets
    local materialPresets = {
        metal = "models/shiny",
        chrome = "models/shiny",
        wood = "models/props_c17/FurnitureFabric006a",
        invisible = "models/effects/vol_light001",
        wireframe = "models/wireframe",
        debug = "debug/debugvertexcolor",
    }
    
    material = materialPresets[string.lower(material or "")] or material or ""
    
    ent:SetMaterial(material)
    
    return {success = true, material = material}
end)

AIAssistant.Tools.Register("physgun_freeze", "Freeze or unfreeze an entity", function(args, ply)
    local id = tonumber(args.entity_id or args.id)
    local ent = id and Entity(id) or nil
    
    if not IsValid(ent) and IsValid(ply) then
        local tr = ply:GetEyeTrace()
        ent = tr.Entity
    end
    
    if not IsValid(ent) then
        return {success = false, error = "No valid entity"}
    end
    
    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then
        return {success = false, error = "Entity has no physics"}
    end
    
    local freeze = args.freeze
    if freeze == nil then
        -- Toggle
        freeze = phys:IsMotionEnabled()
    end
    
    phys:EnableMotion(not freeze)
    
    return {success = true, frozen = freeze}
end)

-- ============================================
-- EFFECT TOOLS
-- ============================================

AIAssistant.Tools.Register("play_sound", "Play a sound", function(args, ply)
    local sound = args.sound or args.path
    if not sound then
        return {success = false, error = "No sound specified"}
    end
    
    -- Sound presets
    local soundPresets = {
        explosion = "ambient/explosions/explode_9.wav",
        beep = "buttons/button14.wav",
        success = "buttons/button9.wav",
        fail = "buttons/button10.wav",
        alarm = "ambient/alarms/alarm1.wav",
        horn = "ambient/machines/truck_horn.wav",
        laugh = "vo/npc/male01/haha02.wav",
    }
    
    sound = soundPresets[string.lower(sound)] or sound
    
    if args.global then
        -- Play for everyone
        for _, p in ipairs(player.GetAll()) do
            p:EmitSound(sound)
        end
    elseif IsValid(ply) then
        local pos = GetPosition(args, ply)
        sound.Play(sound, pos)
    end
    
    return {success = true, sound = sound}
end)

AIAssistant.Tools.Register("create_light", "Create a dynamic light", function(args, ply)
    local pos = GetPosition(args, ply)
    
    local light = ents.Create("light_dynamic")
    light:SetPos(pos)
    light:SetKeyValue("brightness", args.brightness or 2)
    light:SetKeyValue("distance", args.distance or 256)
    light:SetKeyValue("_light", (args.color or "255 255 255") .. " 255")
    light:Spawn()
    light:Activate()
    light:Fire("TurnOn", "", 0)
    
    return {
        success = true,
        entity_id = light:EntIndex(),
        position = {x = pos.x, y = pos.y, z = pos.z}
    }
end)

-- ============================================
-- ADMIN TOOLS (Require admin permission)
-- ============================================

AIAssistant.Tools.Register("run_command", "Run a console command (ADMIN ONLY)", function(args, ply)
    local command = args.command
    if not command then
        return {success = false, error = "No command specified"}
    end
    
    game.ConsoleCommand(command .. "\n")
    
    return {success = true, command = command}
end)

AIAssistant.Tools.Register("change_map", "Change the current map (ADMIN ONLY)", function(args, ply)
    local map = args.map
    if not map then
        return {success = false, error = "No map specified"}
    end
    
    if not file.Exists("maps/" .. map .. ".bsp", "GAME") then
        return {success = false, error = "Map not found: " .. map}
    end
    
    -- Delay to let the response be sent
    timer.Simple(2, function()
        game.ConsoleCommand("changelevel " .. map .. "\n")
    end)
    
    return {success = true, map = map, changing_in = "2 seconds"}
end)

-- ============================================
-- AI LIVE COMPANION TOOLS
-- ============================================

AIAssistant.Tools.Register("ai_live_spawn", "Spawn an AI companion that looks like you and can navigate the map", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    -- Check if AILive module is loaded
    if not AIAssistant.AILive then
        return {success = false, error = "AI Live module not loaded"}
    end
    
    local name = args.name or "AI Companion"
    local success, msg = AIAssistant.AILive.Spawn(ply, name)
    
    return {success = success, message = msg}
end)

AIAssistant.Tools.Register("ai_live_remove", "Remove your AI companion", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    if not AIAssistant.AILive then
        return {success = false, error = "AI Live module not loaded"}
    end
    
    local success, msg = AIAssistant.AILive.Remove(ply)
    
    return {success = success, message = msg}
end)

AIAssistant.Tools.Register("ai_live_move_to", "Command your AI companion to move to a location", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion. Use ai_live_spawn first."}
    end
    
    local pos = ParsePosition(args.position, ply)
    if not pos then
        return {success = false, error = "Invalid position"}
    end
    
    ent:CommandMoveTo(pos)
    
    return {success = true, message = "AI moving to position", position = {x = pos.x, y = pos.y, z = pos.z}}
end)

AIAssistant.Tools.Register("ai_live_follow", "Command your AI companion to follow you or stop following", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion. Use ai_live_spawn first."}
    end
    
    local enable = args.enable
    if enable == nil then enable = true end
    
    if enable then
        local distance = tonumber(args.distance) or 150
        ent:CommandFollow(ply, distance)
        return {success = true, message = "AI is now following you"}
    else
        ent:CommandStop()
        return {success = true, message = "AI stopped following"}
    end
end)

AIAssistant.Tools.Register("ai_live_stop", "Command your AI companion to stop moving", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion. Use ai_live_spawn first."}
    end
    
    ent:CommandStop()
    
    return {success = true, message = "AI stopped"}
end)

AIAssistant.Tools.Register("ai_live_attack", "Command your AI companion to attack an entity", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion. Use ai_live_spawn first."}
    end
    
    local targetId = tonumber(args.entity_id or args.target_id)
    local target = nil
    
    if targetId then
        target = Entity(targetId)
    elseif args.target == "looking_at" or not args.target then
        -- Attack what player is looking at
        local tr = ply:GetEyeTrace()
        target = tr.Entity
    end
    
    if not IsValid(target) then
        return {success = false, error = "No valid target to attack"}
    end
    
    if target:IsPlayer() then
        return {success = false, error = "AI won't attack players (for safety)"}
    end
    
    ent:CommandAttack(target)
    
    return {success = true, message = "AI attacking " .. target:GetClass(), target_id = target:EntIndex()}
end)

AIAssistant.Tools.Register("ai_live_interact", "Command your AI companion to interact with an entity", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion. Use ai_live_spawn first."}
    end
    
    local targetId = tonumber(args.entity_id or args.target_id)
    local target = nil
    
    if targetId then
        target = Entity(targetId)
    else
        local tr = ply:GetEyeTrace()
        target = tr.Entity
    end
    
    if not IsValid(target) then
        return {success = false, error = "No valid entity to interact with"}
    end
    
    ent:CommandInteract(target)
    
    return {success = true, message = "AI interacting with " .. target:GetClass()}
end)

AIAssistant.Tools.Register("ai_live_give_weapon", "Give your AI companion a weapon", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion. Use ai_live_spawn first."}
    end
    
    local weapon = args.weapon or args.weapon_class
    if not weapon then
        return {success = false, error = "No weapon specified"}
    end
    
    local success = ent:CommandGiveWeapon(weapon)
    
    if success then
        return {success = true, message = "AI now has " .. weapon}
    else
        return {success = false, error = "Failed to give weapon"}
    end
end)

AIAssistant.Tools.Register("ai_live_set_health", "Set your AI companion's health", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion. Use ai_live_spawn first."}
    end
    
    local health = tonumber(args.health) or 100
    ent:CommandSetHealth(health)
    
    return {success = true, health = health}
end)

AIAssistant.Tools.Register("ai_live_say", "Make your AI companion say something", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion. Use ai_live_spawn first."}
    end
    
    local text = args.text or args.message
    if not text or text == "" then
        return {success = false, error = "No message specified"}
    end
    
    ent:CommandSay(text)
    
    return {success = true, message = "AI said: " .. text}
end)

AIAssistant.Tools.Register("ai_live_status", "Get the status of your AI companion", function(args, ply)
    if not IsValid(ply) then
        return {success = false, error = "No player"}
    end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion. Use ai_live_spawn first."}
    end
    
    local pos = ent:GetPos()
    local weapon = (ent.GetWeapon) and ent:GetWeapon() or nil
    
    return {
        success = true,
        name = ent:GetAIName(),
        health = ent:Health(),
        max_health = ent:GetMaxHealth(),
        state = ent.AIState or "unknown",
        position = {x = math.Round(pos.x), y = math.Round(pos.y), z = math.Round(pos.z)},
        weapon = IsValid(weapon) and weapon:GetClass() or "none",
        model = ent:GetModel()
    }
end)

-- ============================================
-- AI LIVE PHASE 1: CORE INTERACTIONS
-- ============================================

AIAssistant.Tools.Register("ai_live_look_at", "Make your AI companion look at a position or entity", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local target = nil
    if args.entity_id then
        target = Entity(tonumber(args.entity_id))
    elseif args.position then
        target = ParsePosition(args.position, ply)
    else
        -- Look at what player is looking at
        local tr = ply:GetEyeTrace()
        target = tr.HitPos
    end
    
    if ent:CommandLookAt(target) then
        return {success = true, message = "AI looking at target"}
    end
    return {success = false, error = "Invalid target"}
end)

AIAssistant.Tools.Register("ai_live_use", "Make your AI companion use/interact with an entity (press E)", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local target = nil
    if args.entity_id then
        target = Entity(tonumber(args.entity_id))
    end
    
    local success, result = ent:CommandUse(target)
    if success then
        return {success = true, message = "AI used " .. result}
    end
    return {success = false, error = result}
end)

AIAssistant.Tools.Register("ai_live_crouch", "Make your AI companion crouch or stand", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local enable = args.enable
    if enable == nil then enable = true end
    
    ent:CommandCrouch(enable)
    return {success = true, message = enable and "AI is crouching" or "AI is standing"}
end)

AIAssistant.Tools.Register("ai_live_jump", "Make your AI companion jump", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    ent:CommandJump()
    return {success = true, message = "AI jumped"}
end)

AIAssistant.Tools.Register("ai_live_gesture", "Make your AI companion perform a gesture (wave, dance, bow, laugh, etc.)", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local gesture = args.gesture or "wave"
    local success, err = ent:CommandGesture(gesture)
    
    if success then
        return {success = true, message = "AI performed " .. gesture}
    end
    return {success = false, error = err or "Unknown gesture"}
end)

AIAssistant.Tools.Register("ai_live_kill", "Make your AI companion die (suicide)", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    ent:CommandKill()
    return {success = true, message = "AI has died"}
end)

AIAssistant.Tools.Register("ai_live_scan", "Get what your AI companion can see around it", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local radius = tonumber(args.radius) or 1000
    local success, entities = ent:CommandScan(radius)
    
    return {success = true, entities = entities, count = #entities}
end)

AIAssistant.Tools.Register("ai_live_inspect", "Get details about what your AI is looking at", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local target = nil
    if args.entity_id then
        target = Entity(tonumber(args.entity_id))
    end
    
    local success, info = ent:CommandInspect(target)
    if success then
        return {success = true, entity = info}
    end
    return {success = false, error = info}
end)

AIAssistant.Tools.Register("ai_live_inventory", "Get your AI companion's weapons/inventory", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local success, inv = ent:CommandInventory()
    return {success = true, inventory = inv}
end)

-- ============================================
-- AI LIVE PHASE 2: TACTICAL MOVEMENT
-- ============================================

AIAssistant.Tools.Register("ai_live_find_cover", "Make your AI find cover from enemies", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local success, msg = ent:CommandFindCover()
    return {success = success, message = msg}
end)

AIAssistant.Tools.Register("ai_live_flank", "Make your AI flank the current target", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local success, msg = ent:CommandFlank()
    return {success = success, message = msg}
end)

AIAssistant.Tools.Register("ai_live_retreat", "Make your AI retreat from danger", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local distance = tonumber(args.distance) or 500
    local success, msg = ent:CommandRetreat(distance)
    return {success = success, message = msg}
end)

AIAssistant.Tools.Register("ai_live_patrol", "Make your AI patrol randomly", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local success, msg = ent:CommandPatrol()
    return {success = success, message = msg}
end)

-- ============================================
-- AI LIVE PHASE 3: PHYSICS & BUILDING
-- ============================================

AIAssistant.Tools.Register("ai_live_physgun_pickup", "Make your AI pick up an object", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local target = nil
    if args.entity_id then
        target = Entity(tonumber(args.entity_id))
    end
    
    local success, msg = ent:CommandPhysgunPickup(target)
    return {success = success, message = msg}
end)

AIAssistant.Tools.Register("ai_live_physgun_drop", "Make your AI drop the held object", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local success, msg = ent:CommandPhysgunDrop()
    return {success = success, message = msg}
end)

AIAssistant.Tools.Register("ai_live_physgun_freeze", "Make your AI freeze the held object in place", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local success, msg = ent:CommandPhysgunFreeze()
    return {success = success, message = msg}
end)

AIAssistant.Tools.Register("ai_live_physgun_throw", "Make your AI throw the held object", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local force = tonumber(args.force) or 1000
    local success, msg = ent:CommandPhysgunThrow(force)
    return {success = success, message = msg}
end)

AIAssistant.Tools.Register("ai_live_spawn_prop", "Make your AI spawn a prop", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local model = args.model or "props_c17/oildrum001.mdl"
    local success, result = ent:CommandSpawnProp(model)
    
    if success then
        return result
    end
    return {success = false, error = result}
end)

AIAssistant.Tools.Register("ai_live_remove_prop", "Make your AI remove a prop it's looking at", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local target = nil
    if args.entity_id then
        target = Entity(tonumber(args.entity_id))
    end
    
    local success, msg = ent:CommandRemoveProp(target)
    return {success = success, message = msg}
end)

AIAssistant.Tools.Register("ai_live_weld", "Make your AI weld two props together", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local ent1 = Entity(tonumber(args.entity1_id or 0))
    local ent2 = Entity(tonumber(args.entity2_id or 0))
    
    local success, msg = ent:CommandWeld(ent1, ent2)
    return {success = success, message = msg}
end)

AIAssistant.Tools.Register("ai_live_cleanup", "Make your AI clean up all props it spawned", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local success, msg = ent:CommandCleanup()
    return {success = success, message = msg}
end)

-- ============================================
-- AI LIVE PHASE 4: VEHICLE CONTROL
-- ============================================

AIAssistant.Tools.Register("ai_live_enter_vehicle", "Make your AI enter the nearest vehicle", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local success, msg = ent:CommandEnterVehicle()
    return {success = success, message = msg}
end)

AIAssistant.Tools.Register("ai_live_exit_vehicle", "Make your AI exit its current vehicle", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local success, msg = ent:CommandExitVehicle()
    return {success = success, message = msg}
end)

AIAssistant.Tools.Register("ai_live_drive_to", "Make your AI drive toward a position", function(args, ply)
    if not IsValid(ply) then return {success = false, error = "No player"} end
    
    local ent = AIAssistant.AILive and AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ent) then
        return {success = false, error = "You don't have an AI companion"}
    end
    
    local pos = ParsePosition(args.position, ply)
    if not pos then
        return {success = false, error = "Invalid position"}
    end
    
    local success, msg = ent:CommandDriveTo(pos)
    return {success = success, message = msg}
end)

AIAssistant.Debug("Tools loaded - " .. table.Count(AIAssistant.Tools.Registry) .. " tools registered")
