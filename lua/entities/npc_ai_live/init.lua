--[[
    AI Live Companion - Server Init
    Handles AI behavior, navigation, and bridge communication.
]]

if not DrGBase then return end

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

-- Custom initialization
function ENT:CustomInitialize()
    -- Set relationships - friendly to owner, neutral to others
    self:SetDefaultRelationship(D_NU)
    
    -- Track owner
    self.OwnerPlayer = nil
    self.OwnerSteamID = nil
    
    -- AI State
    self.AIState = "idle"  -- idle, following, moving, interacting, attacking
    self.TargetPosition = nil
    self.TargetEntity = nil
    self.FollowTarget = nil
    self.FollowDistance = 150
    
    -- Command queue
    self.CommandQueue = {}
    self.CurrentCommand = nil
    
    -- Last think time for throttling
    self.LastAIThink = 0
    self.AIThinkInterval = 0.5
    
    -- Speech
    self.LastSpeech = 0
    self.SpeechCooldown = 1
end

-- Set the owner player
function ENT:SetOwnerPlayer(ply)
    if not IsValid(ply) then return end
    
    self.OwnerPlayer = ply
    self.OwnerSteamID = ply:SteamID64()
    
    -- Set model to match player
    local model = ply:GetModel()
    if model and model ~= "" then
        self:SetModel(model)
    end
    
    -- Be friendly to owner
    self:AddEntityRelationship(ply, D_LI, 99)
    
    -- Store owner for networking
    self:SetNW2Entity("OwnerPlayer", ply)
    self:SetNW2String("AIName", "AI Companion")
end

-- Get the owner
function ENT:GetOwnerPlayer()
    if IsValid(self.OwnerPlayer) then
        return self.OwnerPlayer
    end
    -- Try to find by SteamID if player reconnected
    if self.OwnerSteamID then
        for _, ply in ipairs(player.GetAll()) do
            if ply:SteamID64() == self.OwnerSteamID then
                self.OwnerPlayer = ply
                return ply
            end
        end
    end
    return nil
end

-- Set AI name
function ENT:SetAIName(name)
    self:SetNW2String("AIName", name or "AI Companion")
end

function ENT:GetAIName()
    return self:GetNW2String("AIName", "AI Companion")
end

-- Custom AI behavior (overrides default DrGBase behavior)
function ENT:AIBehaviour()
    -- Process current state - no throttling, let DrGBase handle timing
    if self.AIState == "following" and IsValid(self.FollowTarget) then
        self:DoFollow()
    elseif self.AIState == "moving" and self.TargetPosition then
        self:DoMoveTo()
    elseif self.AIState == "attacking" and IsValid(self.TargetEntity) then
        self:DoAttack()
    elseif self.AIState == "interacting" and IsValid(self.TargetEntity) then
        self:DoInteract()
    else
        -- Idle behavior - just stand around, yield quickly
        self:OnIdle()
    end
end

-- Idle behavior
function ENT:OnIdle()
    -- Look around occasionally
    if math.random(1, 100) <= 2 then
        local randomAng = Angle(0, math.random(-180, 180), 0)
        local lookPos = self:GetPos() + randomAng:Forward() * 100
        self:FaceTowards(lookPos)
    end
end

-- Follow behavior - runs inside coroutine
function ENT:DoFollow()
    if not IsValid(self.FollowTarget) then
        self.AIState = "idle"
        return
    end
    
    local dist = self:GetRangeTo(self.FollowTarget)
    
    if dist > self.FollowDistance then
        -- Move towards target using GoTo which handles the coroutine properly
        local result = self:FollowPath(self.FollowTarget, self.FollowDistance * 0.5)
        if result == "unreachable" then
            -- Direct approach as fallback
            self:MoveTowards(self.FollowTarget)
        end
    else
        -- Close enough, face the target
        self:FaceTowards(self.FollowTarget)
    end
end

-- Move to position behavior - runs inside coroutine
function ENT:DoMoveTo()
    if not self.TargetPosition then
        self.AIState = "idle"
        return
    end
    
    local dist = self:GetRangeTo(self.TargetPosition)
    
    if dist > 50 then
        local result = self:FollowPath(self.TargetPosition, 30)
        if result == "reached" then
            self.TargetPosition = nil
            self.AIState = "idle"
        elseif result == "unreachable" then
            -- Try direct movement
            self:MoveTowards(self.TargetPosition)
            -- Give up if still can't reach
            if self:GetRangeTo(self.TargetPosition) > dist then
                self.TargetPosition = nil
                self.AIState = "idle"
            end
        end
    else
        self.TargetPosition = nil
        self.AIState = "idle"
    end
end

-- Attack behavior
function ENT:DoAttack()
    if not IsValid(self.TargetEntity) then
        self.AIState = "idle"
        return
    end
    
    -- Set as enemy
    self:SetEnemy(self.TargetEntity)
    
    local dist = self:GetRangeTo(self.TargetEntity)
    local visible = self:Visible(self.TargetEntity)
    
    if visible then
        self:FaceTowards(self.TargetEntity)
        
        -- Check if we have a weapon
        if self:HasWeapon() then
            -- Range attack
            if dist <= self.RangeAttackRange then
                self:AimAt(self.TargetEntity)
                if dist <= self.MeleeAttackRange then
                    -- Too close for guns, melee
                    self:OnMeleeAttack(self.TargetEntity, self:GetWeapon())
                else
                    -- Shoot
                    self:PrimaryFire()
                end
            else
                -- Get closer
                self:FollowPath(self.TargetEntity, self.RangeAttackRange * 0.75)
            end
        else
            -- No weapon, get close for melee
            if dist <= self.MeleeAttackRange then
                -- Punch attack (basic damage)
                if CurTime() > (self.LastMeleeAttack or 0) + 1 then
                    self.LastMeleeAttack = CurTime()
                    local dmg = DamageInfo()
                    dmg:SetDamage(10)
                    dmg:SetAttacker(self)
                    dmg:SetInflictor(self)
                    dmg:SetDamageType(DMG_CLUB)
                    self.TargetEntity:TakeDamageInfo(dmg)
                    self:EmitSound("npc/zombie/claw_strike" .. math.random(1, 3) .. ".wav")
                end
            else
                self:FollowPath(self.TargetEntity, self.MeleeAttackRange * 0.5)
            end
        end
    else
        -- Can't see target, move towards it
        self:FollowPath(self.TargetEntity, self.MeleeAttackRange)
    end
    
    -- Check if target is dead
    if self.TargetEntity:IsNPC() and self.TargetEntity:Health() <= 0 then
        self.TargetEntity = nil
        self.AIState = "idle"
    elseif self.TargetEntity:IsPlayer() and not self.TargetEntity:Alive() then
        self.TargetEntity = nil
        self.AIState = "idle"
    end
end

-- Interact with entity
function ENT:DoInteract()
    if not IsValid(self.TargetEntity) then
        self.AIState = "idle"
        return
    end
    
    local dist = self:GetRangeTo(self.TargetEntity)
    
    if dist > 80 then
        -- Move closer
        self:FollowPath(self.TargetEntity, 50)
    else
        -- We're close enough, interact
        self:FaceTowards(self.TargetEntity)
        
        -- Try to use the entity
        if self.TargetEntity.Use then
            self.TargetEntity:Use(self, self, USE_ON, 1)
        end
        
        -- Done interacting
        self.TargetEntity = nil
        self.AIState = "idle"
    end
end

-- === COMMAND API ===

-- Command: Move to position
function ENT:CommandMoveTo(pos)
    self.AIState = "moving"
    self.TargetPosition = pos
    self.FollowTarget = nil
    self.TargetEntity = nil
    return true
end

-- Command: Follow entity
function ENT:CommandFollow(target, distance)
    if not IsValid(target) then return false end
    
    self.AIState = "following"
    self.FollowTarget = target
    self.FollowDistance = distance or 150
    self.TargetPosition = nil
    self.TargetEntity = nil
    return true
end

-- Command: Stop following/moving
function ENT:CommandStop()
    self.AIState = "idle"
    self.FollowTarget = nil
    self.TargetPosition = nil
    self.TargetEntity = nil
    self:InvalidatePath()
    return true
end

-- Command: Attack entity
function ENT:CommandAttack(target)
    if not IsValid(target) then return false end
    
    self.AIState = "attacking"
    self.TargetEntity = target
    self.FollowTarget = nil
    self.TargetPosition = nil
    return true
end

-- Command: Interact with entity
function ENT:CommandInteract(target)
    if not IsValid(target) then return false end
    
    self.AIState = "interacting"
    self.TargetEntity = target
    self.FollowTarget = nil
    self.TargetPosition = nil
    return true
end

-- Command: Say something (chat)
function ENT:CommandSay(text)
    if CurTime() < self.LastSpeech + self.SpeechCooldown then
        return false
    end
    self.LastSpeech = CurTime()
    
    -- Broadcast to all players
    local name = self:GetAIName()
    for _, ply in ipairs(player.GetAll()) do
        ply:ChatPrint("[" .. name .. "] " .. text)
    end
    
    return true
end

-- Command: Give weapon
function ENT:CommandGiveWeapon(weaponClass)
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
        ["357"] = "weapon_357",
        magnum = "weapon_357",
    }
    
    weaponClass = weaponAliases[string.lower(weaponClass)] or weaponClass
    
    -- Add weapon_ prefix if needed
    if not string.StartWith(weaponClass, "weapon_") then
        weaponClass = "weapon_" .. weaponClass
    end
    
    return self:GiveWeapon(weaponClass)
end

-- Command: Set health
function ENT:CommandSetHealth(health)
    health = math.Clamp(tonumber(health) or 100, 1, 1000)
    self:SetHealth(health)
    self:SetMaxHealth(health)
    return true
end

-- ============================================
-- PHASE 1: CORE INTERACTIONS
-- ============================================

-- Command: Look at target
function ENT:CommandLookAt(target)
    if isvector(target) then
        self:FaceTowards(target)
        return true
    elseif IsValid(target) then
        self:FaceTowards(target)
        return true
    end
    return false
end

-- Command: Use (press E)
function ENT:CommandUse(target)
    if not IsValid(target) then
        -- Try to find what we're looking at
        local tr = util.TraceLine({
            start = self:GetShootPos(),
            endpos = self:GetShootPos() + self:GetAimVector() * 100,
            filter = self
        })
        target = tr.Entity
    end
    
    if IsValid(target) and target.Use then
        target:Use(self, self, USE_ON, 1)
        return true, target:GetClass()
    end
    return false, "Nothing to use"
end

-- Command: Crouch
function ENT:CommandCrouch(enable)
    if enable then
        self:SetCrouching(true)
    else
        self:SetCrouching(false)
    end
    return true
end

-- Command: Jump
function ENT:CommandJump()
    self:Jump()
    return true
end

-- Command: Gesture/Act
function ENT:CommandGesture(gesture)
    local gestures = {
        wave = ACT_GMOD_GESTURE_WAVE,
        dance = ACT_GMOD_TAUNT_DANCE,
        bow = ACT_GMOD_GESTURE_BOW,
        laugh = ACT_GMOD_TAUNT_LAUGH,
        cheer = ACT_GMOD_TAUNT_CHEER,
        agree = ACT_GMOD_GESTURE_AGREE,
        disagree = ACT_GMOD_GESTURE_DISAGREE,
        salute = ACT_GMOD_GESTURE_SALUTE,
        becon = ACT_GMOD_GESTURE_BECON,
        point = ACT_GMOD_GESTURE_POINT,
        robot = ACT_GMOD_TAUNT_ROBOT,
        muscle = ACT_GMOD_TAUNT_MUSCLE,
        zombie = ACT_GMOD_TAUNT_ZOMBIE,
    }
    
    local act = gestures[string.lower(gesture or "")]
    if act then
        self:PlaySequenceAndWait(self:SelectWeightedSequence(act))
        return true
    end
    return false, "Unknown gesture"
end

-- Command: Kill (suicide)
function ENT:CommandKill()
    self:TakeDamage(self:Health() + 100, self, self)
    return true
end

-- Command: Scan surroundings
function ENT:CommandScan(radius)
    radius = radius or 1000
    local entities = {}
    
    for _, ent in ipairs(ents.FindInSphere(self:GetPos(), radius)) do
        if IsValid(ent) and ent ~= self then
            local entData = {
                id = ent:EntIndex(),
                class = ent:GetClass(),
                distance = math.Round(self:GetPos():Distance(ent:GetPos())),
                visible = self:Visible(ent)
            }
            
            if ent:IsPlayer() then
                entData.type = "player"
                entData.name = ent:Nick()
            elseif ent:IsNPC() then
                entData.type = "npc"
                entData.health = ent:Health()
            elseif ent:GetClass() == "prop_physics" then
                entData.type = "prop"
                entData.model = ent:GetModel()
            elseif ent:IsVehicle() then
                entData.type = "vehicle"
                entData.model = ent:GetModel()
            end
            
            if entData.type then
                table.insert(entities, entData)
            end
        end
    end
    
    -- Sort by distance
    table.sort(entities, function(a, b) return a.distance < b.distance end)
    
    -- Limit to 15
    local limited = {}
    for i = 1, math.min(15, #entities) do
        table.insert(limited, entities[i])
    end
    
    return true, limited
end

-- Command: Inspect entity
function ENT:CommandInspect(target)
    if not IsValid(target) then
        -- Look at what we're facing
        local tr = util.TraceLine({
            start = self:GetShootPos(),
            endpos = self:GetShootPos() + self:GetAimVector() * 500,
            filter = self
        })
        target = tr.Entity
    end
    
    if not IsValid(target) then
        return false, "Nothing to inspect"
    end
    
    local info = {
        id = target:EntIndex(),
        class = target:GetClass(),
        model = target:GetModel(),
        position = {x = target:GetPos().x, y = target:GetPos().y, z = target:GetPos().z}
    }
    
    if target:IsPlayer() then
        info.type = "player"
        info.name = target:Nick()
        info.health = target:Health()
        info.armor = target:Armor()
    elseif target:IsNPC() then
        info.type = "npc"
        info.health = target:Health()
    elseif target:IsVehicle() then
        info.type = "vehicle"
        info.driver = IsValid(target:GetDriver()) and target:GetDriver():Nick() or "empty"
    else
        info.type = "entity"
        local phys = target:GetPhysicsObject()
        if IsValid(phys) then
            info.frozen = not phys:IsMotionEnabled()
            info.mass = phys:GetMass()
        end
    end
    
    return true, info
end

-- Command: Get inventory
function ENT:CommandInventory()
    local weapons = {}
    if self.Weapons then
        for _, wep in ipairs(self.Weapons) do
            table.insert(weapons, wep)
        end
    end
    
    -- Get current weapon
    local current = "none"
    if self:HasWeapon() then
        local wep = self:GetWeapon()
        if IsValid(wep) then
            current = wep:GetClass()
        end
    end
    
    return true, {weapons = weapons, current = current}
end

-- ============================================
-- PHASE 2: TACTICAL MOVEMENT
-- ============================================

-- Command: Find cover
function ENT:CommandFindCover()
    local enemy = self.TargetEntity or self:GetEnemy()
    if not IsValid(enemy) then
        -- Find nearest threat
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 1000)) do
            if IsValid(ent) and (ent:IsNPC() or ent:IsPlayer()) and ent ~= self then
                if self:GetRelationship(ent) == D_HT then
                    enemy = ent
                    break
                end
            end
        end
    end
    
    if not IsValid(enemy) then
        return false, "No threat to hide from"
    end
    
    -- Find cover using navmesh
    local hideSpot = navmesh.FindHidingSpot(self:GetPos(), enemy:GetPos(), 500, 2000)
    if hideSpot then
        self:CommandMoveTo(hideSpot)
        return true, "Moving to cover"
    end
    
    return false, "No cover found"
end

-- Command: Flank target
function ENT:CommandFlank()
    local target = self.TargetEntity or self:GetEnemy()
    if not IsValid(target) then
        return false, "No target to flank"
    end
    
    -- Calculate flank position (perpendicular to target)
    local toTarget = (target:GetPos() - self:GetPos()):GetNormalized()
    local right = toTarget:Cross(Vector(0, 0, 1)):GetNormalized()
    
    -- Try left or right flank
    local flankDist = 300
    local flankPos = target:GetPos() + right * flankDist
    
    -- Validate with navmesh
    local nav = navmesh.GetNearestNavArea(flankPos)
    if not nav then
        flankPos = target:GetPos() - right * flankDist  -- Try other side
        nav = navmesh.GetNearestNavArea(flankPos)
    end
    
    if nav then
        self:CommandMoveTo(nav:GetCenter())
        return true, "Flanking target"
    end
    
    return false, "Cannot find flank route"
end

-- Command: Retreat
function ENT:CommandRetreat(distance)
    distance = distance or 500
    local threat = self.TargetEntity or self:GetEnemy()
    
    local retreatDir
    if IsValid(threat) then
        retreatDir = (self:GetPos() - threat:GetPos()):GetNormalized()
    else
        retreatDir = -self:GetForward()
    end
    
    local retreatPos = self:GetPos() + retreatDir * distance
    
    -- Find valid nav area
    local nav = navmesh.GetNearestNavArea(retreatPos)
    if nav then
        self:CommandMoveTo(nav:GetCenter())
        self.AIState = "moving"
        self.TargetEntity = nil  -- Stop attacking
        return true, "Retreating"
    end
    
    return false, "Cannot retreat"
end

-- Command: Patrol
function ENT:CommandPatrol(radius)
    radius = radius or 500
    
    -- Find random nav area nearby
    local nav = navmesh.GetNearestNavArea(self:GetPos())
    if not nav then
        return false, "No navmesh"
    end
    
    local areas = nav:GetAdjacentAreas()
    if #areas > 0 then
        local randomArea = areas[math.random(#areas)]
        self:CommandMoveTo(randomArea:GetCenter())
        return true, "Patrolling"
    end
    
    return false, "Nowhere to patrol"
end

-- ============================================
-- PHASE 3: PHYSICS & BUILDING
-- ============================================

-- Track held entity and spawned props
ENT.HeldEntity = nil
ENT.SpawnedProps = {}

-- Command: Physgun pickup (simulated)
function ENT:CommandPhysgunPickup(target)
    if not IsValid(target) then
        -- Find what we're looking at
        local tr = util.TraceLine({
            start = self:GetShootPos(),
            endpos = self:GetShootPos() + self:GetAimVector() * 200,
            filter = self
        })
        target = tr.Entity
    end
    
    if not IsValid(target) then
        return false, "Nothing to pick up"
    end
    
    local phys = target:GetPhysicsObject()
    if not IsValid(phys) then
        return false, "Cannot pick up this object"
    end
    
    -- Drop current if holding
    if IsValid(self.HeldEntity) then
        self:CommandPhysgunDrop()
    end
    
    -- "Pick up" by parenting and disabling physics
    self.HeldEntity = target
    self.HeldEntityOriginalPos = target:GetPos()
    
    -- Move object in front of us
    local holdPos = self:GetShootPos() + self:GetAimVector() * 80
    target:SetPos(holdPos)
    phys:EnableMotion(false)
    phys:Wake()
    
    -- Create visual constraint
    self.HeldConstraint = constraint.Weld(self, target, 0, 0, 0, true)
    
    return true, "Picked up " .. target:GetClass()
end

-- Command: Physgun drop
function ENT:CommandPhysgunDrop()
    if not IsValid(self.HeldEntity) then
        return false, "Not holding anything"
    end
    
    -- Remove constraint
    if self.HeldConstraint then
        self.HeldConstraint:Remove()
        self.HeldConstraint = nil
    end
    
    local ent = self.HeldEntity
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(true)
        phys:Wake()
    end
    
    self.HeldEntity = nil
    return true, "Dropped"
end

-- Command: Physgun freeze
function ENT:CommandPhysgunFreeze()
    if not IsValid(self.HeldEntity) then
        return false, "Not holding anything"
    end
    
    -- Remove constraint but keep frozen
    if self.HeldConstraint then
        self.HeldConstraint:Remove()
        self.HeldConstraint = nil
    end
    
    local ent = self.HeldEntity
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end
    
    self.HeldEntity = nil
    return true, "Frozen in place"
end

-- Command: Physgun throw
function ENT:CommandPhysgunThrow(force)
    if not IsValid(self.HeldEntity) then
        return false, "Not holding anything"
    end
    
    force = force or 1000
    
    -- Remove constraint
    if self.HeldConstraint then
        self.HeldConstraint:Remove()
        self.HeldConstraint = nil
    end
    
    local ent = self.HeldEntity
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(true)
        phys:Wake()
        phys:ApplyForceCenter(self:GetAimVector() * force * phys:GetMass())
    end
    
    self.HeldEntity = nil
    return true, "Thrown!"
end

-- Command: Spawn prop
function ENT:CommandSpawnProp(model)
    if not model or model == "" then
        model = "models/props_c17/oildrum001.mdl"
    end
    
    -- Add models/ prefix if needed
    if not string.StartWith(model, "models/") then
        model = "models/" .. model
    end
    
    -- Spawn in front of us
    local spawnPos = self:GetPos() + self:GetForward() * 100 + Vector(0, 0, 50)
    
    local prop = ents.Create("prop_physics")
    if not IsValid(prop) then
        return false, "Failed to create prop"
    end
    
    prop:SetModel(model)
    prop:SetPos(spawnPos)
    prop:Spawn()
    prop:Activate()
    
    -- Track spawned prop
    table.insert(self.SpawnedProps, prop)
    
    return true, {message = "Spawned prop", entity_id = prop:EntIndex(), model = model}
end

-- Command: Remove prop
function ENT:CommandRemoveProp(target)
    if not IsValid(target) then
        -- Find what we're looking at
        local tr = util.TraceLine({
            start = self:GetShootPos(),
            endpos = self:GetShootPos() + self:GetAimVector() * 300,
            filter = self
        })
        target = tr.Entity
    end
    
    if not IsValid(target) then
        return false, "Nothing to remove"
    end
    
    if target:IsPlayer() or target:IsNPC() then
        return false, "Cannot remove players or NPCs"
    end
    
    local class = target:GetClass()
    target:Remove()
    return true, "Removed " .. class
end

-- Command: Weld
function ENT:CommandWeld(ent1, ent2)
    if not IsValid(ent1) or not IsValid(ent2) then
        return false, "Need two valid entities"
    end
    
    local weld = constraint.Weld(ent1, ent2, 0, 0, 0, true)
    if weld then
        return true, "Welded"
    end
    return false, "Failed to weld"
end

-- Command: Cleanup spawned props
function ENT:CommandCleanup()
    local count = 0
    for _, prop in ipairs(self.SpawnedProps) do
        if IsValid(prop) then
            prop:Remove()
            count = count + 1
        end
    end
    self.SpawnedProps = {}
    return true, "Cleaned up " .. count .. " props"
end

-- ============================================
-- PHASE 4: VEHICLE CONTROL
-- ============================================

ENT.CurrentVehicle = nil

-- Command: Enter vehicle
function ENT:CommandEnterVehicle()
    -- Find nearest vehicle
    local nearestVehicle = nil
    local nearestDist = 500
    
    for _, ent in ipairs(ents.FindInSphere(self:GetPos(), nearestDist)) do
        if IsValid(ent) and ent:IsVehicle() then
            local dist = self:GetPos():Distance(ent:GetPos())
            if dist < nearestDist then
                -- Check if empty
                if not IsValid(ent:GetDriver()) then
                    nearestVehicle = ent
                    nearestDist = dist
                end
            end
        end
    end
    
    if not IsValid(nearestVehicle) then
        return false, "No empty vehicle nearby"
    end
    
    -- Enter vehicle
    nearestVehicle:SetNW2Entity("AIDriver", self)
    self.CurrentVehicle = nearestVehicle
    self:SetPos(nearestVehicle:GetPos())
    self:SetParent(nearestVehicle)
    self:SetNoDraw(true)
    
    return true, "Entered " .. nearestVehicle:GetClass()
end

-- Command: Exit vehicle
function ENT:CommandExitVehicle()
    if not IsValid(self.CurrentVehicle) then
        return false, "Not in a vehicle"
    end
    
    local vehicle = self.CurrentVehicle
    vehicle:SetNW2Entity("AIDriver", nil)
    
    -- Exit position
    local exitPos = vehicle:GetPos() + vehicle:GetRight() * 100
    
    self:SetParent(nil)
    self:SetPos(exitPos)
    self:SetNoDraw(false)
    self.CurrentVehicle = nil
    
    return true, "Exited vehicle"
end

-- Command: Drive to position (simplified)
function ENT:CommandDriveTo(pos)
    if not IsValid(self.CurrentVehicle) then
        return false, "Not in a vehicle"
    end
    
    -- Simple driving: just move vehicle toward target
    -- Real implementation would need proper vehicle input simulation
    local vehicle = self.CurrentVehicle
    local phys = vehicle:GetPhysicsObject()
    
    if IsValid(phys) then
        local dir = (pos - vehicle:GetPos()):GetNormalized()
        phys:ApplyForceCenter(dir * 5000)
    end
    
    return true, "Driving toward target"
end

-- ============================================
-- OVERRIDES
-- ============================================

-- Override should run check
function ENT:ShouldRun()
    if self.AIState == "attacking" then return true end
    if self.AIState == "following" and IsValid(self.FollowTarget) then
        -- Run if far from target
        return self:GetRangeTo(self.FollowTarget) > self.FollowDistance * 2
    end
    return false
end

-- Handle damage
function ENT:OnTakeDamage(dmg)
    -- Don't take damage from owner
    local attacker = dmg:GetAttacker()
    if IsValid(attacker) and attacker == self:GetOwnerPlayer() then
        return 0
    end
    
    -- Auto-retaliate if damaged by NPC
    if IsValid(attacker) and attacker:IsNPC() and self.AIState == "idle" then
        self:CommandAttack(attacker)
    end
    
    return dmg:GetDamage()
end

-- Handle death
function ENT:OnDeath()
    -- Drop held entity
    if IsValid(self.HeldEntity) then
        self:CommandPhysgunDrop()
    end
    
    -- Exit vehicle
    if IsValid(self.CurrentVehicle) then
        self:CommandExitVehicle()
    end
    
    local owner = self:GetOwnerPlayer()
    if IsValid(owner) then
        owner:ChatPrint("[AI Assistant] Your AI companion has died!")
        
        -- Clear from AILive registry
        if AIAssistant and AIAssistant.AILive then
            AIAssistant.AILive.OnEntityDeath(self)
        end
    end
end
