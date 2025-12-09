--[[
    AI Live Controller
    Manages AI Live companion entities - spawning, removing, and commanding.
]]

-- Ensure AIAssistant global exists
AIAssistant = AIAssistant or {}
AIAssistant.AILive = AIAssistant.AILive or {}

-- Configuration
AIAssistant.AILive.MaxPerPlayer = 1
AIAssistant.AILive.SpawnDistance = 100
AIAssistant.AILive.Entities = {}  -- Track all AI Live entities

-- Check if DrGBase is loaded
local function CheckDrGBase()
    if not DrGBase then
        return false, "DrGBase is required for AI Live companions. Please install DrGBase."
    end
    return true
end

-- Get AI Live entity for a player
function AIAssistant.AILive.GetForPlayer(ply)
    if not IsValid(ply) then return nil end
    
    local steamId = ply:SteamID64()
    for ent, data in pairs(AIAssistant.AILive.Entities) do
        if IsValid(ent) and data.steamId == steamId then
            return ent
        end
    end
    return nil
end

-- Count AI Live entities for a player
function AIAssistant.AILive.CountForPlayer(ply)
    if not IsValid(ply) then return 0 end
    
    local steamId = ply:SteamID64()
    local count = 0
    for ent, data in pairs(AIAssistant.AILive.Entities) do
        if IsValid(ent) and data.steamId == steamId then
            count = count + 1
        end
    end
    return count
end

-- Spawn an AI Live companion for a player
function AIAssistant.AILive.Spawn(ply, name)
    -- Check DrGBase
    local ok, err = CheckDrGBase()
    if not ok then
        return false, err
    end
    
    -- Validate player
    if not IsValid(ply) then
        return false, "Invalid player"
    end
    
    -- Check limit
    if AIAssistant.AILive.CountForPlayer(ply) >= AIAssistant.AILive.MaxPerPlayer then
        return false, "You already have an AI companion. Use /ai_live_remove first."
    end
    
    -- Calculate spawn position (in front of player)
    local spawnPos = ply:GetPos() + ply:GetAimVector() * AIAssistant.AILive.SpawnDistance
    
    -- Trace down to find ground
    local tr = util.TraceLine({
        start = spawnPos + Vector(0, 0, 50),
        endpos = spawnPos - Vector(0, 0, 100),
        mask = MASK_SOLID_BRUSHONLY
    })
    
    if tr.Hit then
        spawnPos = tr.HitPos + Vector(0, 0, 5)
    end
    
    -- Create the entity
    local ent = ents.Create("npc_ai_live")
    if not IsValid(ent) then
        return false, "Failed to create AI companion. Make sure DrGBase is installed."
    end
    
    ent:SetPos(spawnPos)
    ent:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))  -- Face the player
    ent:Spawn()
    ent:Activate()
    
    -- Set owner and name
    ent:SetOwnerPlayer(ply)
    ent:SetAIName(name or "AI Companion")
    
    -- Track the entity
    AIAssistant.AILive.Entities[ent] = {
        steamId = ply:SteamID64(),
        spawnTime = CurTime(),
        name = name or "AI Companion"
    }
    
    if AIAssistant.Debug then AIAssistant.Debug("Spawned AI Live for", ply:Nick()) end
    
    return true, "AI companion spawned! Use /ai to give it commands."
end

-- Remove AI Live companion
function AIAssistant.AILive.Remove(ply)
    local ent = AIAssistant.AILive.GetForPlayer(ply)
    
    if not IsValid(ent) then
        return false, "You don't have an AI companion."
    end
    
    -- Clean up tracking
    AIAssistant.AILive.Entities[ent] = nil
    
    -- Remove the entity
    ent:Remove()
    
    if AIAssistant.Debug then AIAssistant.Debug("Removed AI Live for", ply:Nick()) end
    
    return true, "AI companion removed."
end

-- Called when an AI Live entity dies
function AIAssistant.AILive.OnEntityDeath(ent)
    if AIAssistant.AILive.Entities[ent] then
        AIAssistant.AILive.Entities[ent] = nil
        if AIAssistant.Debug then AIAssistant.Debug("AI Live entity died and was removed from registry") end
    end
end

-- Clean up invalid entities periodically
timer.Create("AIAssistant_AILive_Cleanup", 30, 0, function()
    for ent, data in pairs(AIAssistant.AILive.Entities) do
        if not IsValid(ent) then
            AIAssistant.AILive.Entities[ent] = nil
        end
    end
end)

-- Command handlers for chat
hook.Add("PlayerSay", "AIAssistant_AILiveCommands", function(ply, text)
    local lower = string.lower(text)
    
    -- Spawn command
    if lower == "/ai_live" or lower == "!ai_live" then
        if AIAssistant.CanUse and AIAssistant.CanUse(ply) then
            local success, msg = AIAssistant.AILive.Spawn(ply)
            ply:ChatPrint("[AI Assistant] " .. msg)
        else
            ply:ChatPrint("[AI Assistant] You don't have permission to use AI Live.")
        end
        return ""
    end
    
    -- Remove command
    if lower == "/ai_live_remove" or lower == "!ai_live_remove" then
        if AIAssistant.CanUse and AIAssistant.CanUse(ply) then
            local success, msg = AIAssistant.AILive.Remove(ply)
            ply:ChatPrint("[AI Assistant] " .. msg)
        else
            ply:ChatPrint("[AI Assistant] You don't have permission.")
        end
        return ""
    end
end)

-- Console commands
concommand.Add("ai_live_spawn", function(ply, cmd, args)
    if not IsValid(ply) then return end
    
    if not AIAssistant.CanUse or not AIAssistant.CanUse(ply) then
        ply:ChatPrint("[AI Assistant] You don't have permission.")
        return
    end
    
    local name = args[1]
    local success, msg = AIAssistant.AILive.Spawn(ply, name)
    ply:ChatPrint("[AI Assistant] " .. msg)
end)

concommand.Add("ai_live_remove", function(ply, cmd, args)
    if not IsValid(ply) then return end
    
    if not AIAssistant.CanUse or not AIAssistant.CanUse(ply) then
        ply:ChatPrint("[AI Assistant] You don't have permission.")
        return
    end
    
    local success, msg = AIAssistant.AILive.Remove(ply)
    ply:ChatPrint("[AI Assistant] " .. msg)
end)

-- Status command
concommand.Add("ai_live_status", function(ply, cmd, args)
    if not IsValid(ply) then return end
    
    local ent = AIAssistant.AILive.GetForPlayer(ply)
    
    if not IsValid(ent) then
        ply:ChatPrint("[AI Live] You don't have an AI companion.")
        return
    end
    
    ply:ChatPrint("[AI Live] Status:")
    ply:ChatPrint("  Name: " .. ent:GetAIName())
    ply:ChatPrint("  Health: " .. ent:Health() .. "/" .. ent:GetMaxHealth())
    ply:ChatPrint("  State: " .. (ent.AIState or "unknown"))
    ply:ChatPrint("  Position: " .. tostring(ent:GetPos()))
    
    if ent:HasWeapon() then
        local wep = ent:GetWeapon()
        if IsValid(wep) then
            ply:ChatPrint("  Weapon: " .. wep:GetClass())
        end
    end
end)

if AIAssistant.Debug then
    AIAssistant.Debug("AI Live controller loaded")
else
    print("[AI Assistant] AI Live controller loaded")
end
