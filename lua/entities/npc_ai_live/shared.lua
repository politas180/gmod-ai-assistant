--[[
    AI Live Companion - Shared
    An AI-controlled NPC that can navigate and interact with the game world.
    Uses DrGBase for navmesh navigation.
]]

if not DrGBase then
    print("[AI Live] ERROR: DrGBase is required for AI Live companions!")
    return
end

ENT.Base = "drgbase_nextbot_human"
ENT.Type = "nextbot"

ENT.PrintName = "AI Live Companion"
ENT.Category = "AI Assistant"
ENT.Spawnable = false  -- Only spawn via command
ENT.AdminOnly = true

-- Network variables
ENT.IsDrGNextbot = true
ENT.IsDrGNextbotHuman = true
ENT.IsAILive = true

-- Misc
ENT.Models = {"models/player/kleiner.mdl"}  -- Default, will be set to player model
ENT.BloodColor = BLOOD_COLOR_RED
ENT.RagdollOnDeath = true
ENT.CollisionBounds = Vector(16, 16, 72)

-- Stats
ENT.SpawnHealth = 100
ENT.HealthRegen = 0

-- AI Settings
ENT.BehaviourType = AI_BEHAV_CUSTOM  -- Custom behavior, we control it
ENT.Omniscient = false
ENT.SpotDuration = 30
ENT.RangeAttackRange = 1500
ENT.MeleeAttackRange = 75
ENT.ReachEnemyRange = 1000

-- Detection
ENT.EyeBone = "ValveBiped.Bip01_Head1"
ENT.EyeOffset = Vector(5, 0, 2.5)
ENT.SightFOV = 150
ENT.SightRange = 5000

-- Locomotion - fast and responsive
ENT.Acceleration = 2000
ENT.Deceleration = 2000
ENT.JumpHeight = 58
ENT.StepHeight = 20
ENT.MaxYawRate = 500
ENT.DeathDropHeight = 500

-- Movement - fast like a player
ENT.UseWalkframes = false  -- Disable for consistent speed
ENT.WalkSpeed = 250
ENT.RunSpeed = 500

-- Climbing
ENT.ClimbLedges = true
ENT.ClimbLedgesMaxHeight = 100
ENT.ClimbLadders = true
ENT.ClimbLaddersUp = true
ENT.ClimbSpeed = 100
ENT.ClimbUpAnimation = ACT_ZOMBIE_CLIMB_UP
ENT.ClimbOffset = Vector(-14, 0, 0)

-- Animations
ENT.WalkAnimation = ACT_WALK
ENT.WalkAnimRate = 1
ENT.RunAnimation = ACT_RUN
ENT.RunAnimRate = 1
ENT.IdleAnimation = ACT_IDLE
ENT.IdleAnimRate = 1
ENT.JumpAnimation = ACT_JUMP
ENT.JumpAnimRate = 1

-- Weapons
ENT.UseWeapons = true
ENT.Weapons = {}
ENT.DropWeaponOnDeath = true
ENT.AcceptPlayerWeapons = true
ENT.WeaponAccuracy = 0.85

-- Relationships
ENT.DefaultRelationship = D_NU
ENT.Factions = {FACTION_REBELS}
ENT.Frightening = false

-- Possession (disabled for AI Live)
ENT.PossessionEnabled = false

-- Sounds
ENT.OnSpawnSounds = {}
ENT.OnIdleSounds = {}
ENT.OnDamageSounds = {"vo/npc/male01/pain01.wav", "vo/npc/male01/pain02.wav"}
ENT.OnDeathSounds = {"vo/npc/male01/pain07.wav"}

-- DO NOT TOUCH --
AddCSLuaFile()
DrGBase.AddNextbot(ENT)
