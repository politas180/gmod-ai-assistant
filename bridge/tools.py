"""
GMod AI Assistant - Tool Definitions
Defines all available tools in OpenAI function calling format.
"""

GMOD_TOOLS = [
    # ============================================
    # SPAWNING TOOLS
    # ============================================
    {
        "type": "function",
        "function": {
            "name": "spawn_prop",
            "description": "Spawn a prop/model in the game world. Use position='looking_at' to spawn where the player is aiming/looking.",
            "parameters": {
                "type": "object",
                "properties": {
                    "model": {
                        "type": "string",
                        "description": "Model path (e.g., 'props_c17/oildrum001.mdl' or full path 'models/props_c17/oildrum001.mdl')"
                    },
                    "position": {
                        "type": "string",
                        "description": "Where to spawn: 'looking_at' (at crosshair/aim point - USE THIS when player says 'where I'm looking', 'there', 'at that spot'), 'in_front', 'behind', 'left', 'right', 'above', 'here', or 'x,y,z' coordinates. Defaults to looking_at if not specified."
                    },
                    "frozen": {
                        "type": "boolean",
                        "description": "Whether to freeze the prop in place"
                    }
                },
                "required": ["model"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "spawn_npc",
            "description": "Spawn one or more NPCs (zombie, combine, citizen, etc.). Use position='looking_at' to spawn where the player is aiming. Use count to spawn multiple at once (max 20).",
            "parameters": {
                "type": "object",
                "properties": {
                    "npc_type": {
                        "type": "string",
                        "description": "Type of NPC: zombie, fastzombie, headcrab, antlion, combine, soldier, metro, police, citizen, alyx, barney, kleiner, dog, turret, strider, gunship, hunter, vortigaunt, crow, etc."
                    },
                    "count": {
                        "type": "integer",
                        "description": "Number of NPCs to spawn (1-20, default 1). Use this when player asks for multiple NPCs like 'spawn 10 zombies' or 'give me an army'."
                    },
                    "position": {
                        "type": "string",
                        "description": "Where to spawn: 'looking_at' (at crosshair/aim point - PREFERRED for 'where I'm looking', 'there', 'over there', 'at that spot'), 'in_front', 'behind', 'here', or 'x,y,z' coordinates. Defaults to looking_at if not specified."
                    },
                    "weapon": {
                        "type": "string",
                        "description": "Weapon for the NPC to carry (e.g., 'smg1', 'ar2', 'shotgun')"
                    },
                    "friendly": {
                        "type": "boolean",
                        "description": "Make the NPC friendly to the player"
                    },
                    "hostile": {
                        "type": "boolean",
                        "description": "Make the NPC hostile to the player"
                    }
                },
                "required": ["npc_type"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "spawn_entity",
            "description": "Spawn any entity by class name",
            "parameters": {
                "type": "object",
                "properties": {
                    "class": {
                        "type": "string",
                        "description": "Entity class name (e.g., 'item_healthkit', 'weapon_crossbow', 'prop_door_rotating')"
                    },
                    "position": {
                        "type": "string",
                        "description": "Position: 'in_front', 'looking_at', 'here', or 'x,y,z' coordinates"
                    },
                    "properties": {
                        "type": "object",
                        "description": "Key-value properties to set on the entity"
                    }
                },
                "required": ["class"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "spawn_vehicle",
            "description": "Spawn a drivable vehicle",
            "parameters": {
                "type": "object",
                "properties": {
                    "vehicle_type": {
                        "type": "string",
                        "enum": ["jeep", "airboat", "jalopy", "pod"],
                        "description": "Type of vehicle to spawn"
                    },
                    "position": {
                        "type": "string",
                        "description": "Position: 'in_front', 'looking_at', or 'x,y,z' coordinates"
                    }
                },
                "required": ["vehicle_type"]
            }
        }
    },
    
    # ============================================
    # PLAYER TOOLS
    # ============================================
    {
        "type": "function",
        "function": {
            "name": "teleport_player",
            "description": "Teleport the requesting player to a location",
            "parameters": {
                "type": "object",
                "properties": {
                    "position": {
                        "type": "string",
                        "description": "Target position as coordinates WITHOUT parentheses, format: 'x,y,z' (e.g., '1000,2000,-12288'). Use actual numbers separated by commas only."
                    },
                    "location": {
                        "type": "string",
                        "description": "Named location: 'spawn', 'random', 'far' (teleports to a random distant location on the map)"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "set_player_health",
            "description": "Set the player's health",
            "parameters": {
                "type": "object",
                "properties": {
                    "health": {
                        "type": "integer",
                        "description": "Health value (0-1000)"
                    }
                },
                "required": ["health"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "set_player_armor",
            "description": "Set the player's armor",
            "parameters": {
                "type": "object",
                "properties": {
                    "armor": {
                        "type": "integer",
                        "description": "Armor value (0-255)"
                    }
                },
                "required": ["armor"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "give_weapon",
            "description": "Give a weapon to the player",
            "parameters": {
                "type": "object",
                "properties": {
                    "weapon": {
                        "type": "string",
                        "description": "Weapon: crowbar, pistol, smg, shotgun, ar2, rifle, rpg, crossbow, grenade, frag, physcannon, gravgun, physgun, toolgun, slam, bugbait, stunstick, 357, magnum"
                    },
                    "ammo": {
                        "type": "integer",
                        "description": "Amount of ammo to give with the weapon (optional)"
                    }
                },
                "required": ["weapon"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "give_ammo",
            "description": "Give ammo to the player for a specific ammo type",
            "parameters": {
                "type": "object",
                "properties": {
                    "ammo_type": {
                        "type": "string",
                        "description": "Ammo type: smg1, ar2, pistol, 357, buckshot, crossbow, rpg, grenade, slam"
                    },
                    "amount": {
                        "type": "integer",
                        "description": "Amount of ammo to give (default 100)"
                    }
                },
                "required": ["ammo_type"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "set_player_model",
            "description": "Change the player's model/character",
            "parameters": {
                "type": "object",
                "properties": {
                    "model": {
                        "type": "string",
                        "description": "Model: kleiner, alyx, barney, breen, gman, monk, mossman, eli, zombie, combine, soldier, police, or full model path"
                    }
                },
                "required": ["model"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "set_player_speed",
            "description": "Set player movement speed",
            "parameters": {
                "type": "object",
                "properties": {
                    "walk_speed": {
                        "type": "integer",
                        "description": "Walking speed (default: 200)"
                    },
                    "run_speed": {
                        "type": "integer",
                        "description": "Running/sprint speed (default: 400)"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "set_player_scale",
            "description": "Change the player's size",
            "parameters": {
                "type": "object",
                "properties": {
                    "scale": {
                        "type": "number",
                        "description": "Scale factor (0.1 = tiny, 1.0 = normal, 10.0 = giant)"
                    }
                },
                "required": ["scale"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "respawn_player",
            "description": "Respawn the player (useful if stuck or dead)",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "kill_player",
            "description": "Kill the player (they asked for it!)",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "godmode",
            "description": "Toggle invincibility for the player",
            "parameters": {
                "type": "object",
                "properties": {
                    "enable": {
                        "type": "boolean",
                        "description": "True to enable, false to disable, omit to toggle"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "noclip",
            "description": "Toggle noclip (flying through walls) for the player",
            "parameters": {
                "type": "object",
                "properties": {
                    "enable": {
                        "type": "boolean",
                        "description": "True to enable, false to disable, omit to toggle"
                    }
                }
            }
        }
    },
    
    # ============================================
    # WORLD TOOLS
    # ============================================
    {
        "type": "function",
        "function": {
            "name": "set_gravity",
            "description": "Change world gravity",
            "parameters": {
                "type": "object",
                "properties": {
                    "gravity": {
                        "type": "string",
                        "description": "Gravity: 'normal'/'earth' (600), 'moon' (100), 'mars' (227), 'jupiter' (1500), 'zero' (0), 'low' (200), 'high' (1000), or a number"
                    }
                },
                "required": ["gravity"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "set_timescale",
            "description": "Change game speed (slow motion or fast forward)",
            "parameters": {
                "type": "object",
                "properties": {
                    "scale": {
                        "type": "number",
                        "description": "Time scale: 0.1 = very slow, 0.5 = half speed, 1.0 = normal, 2.0 = double speed"
                    }
                },
                "required": ["scale"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "explode",
            "description": "Create an explosion",
            "parameters": {
                "type": "object",
                "properties": {
                    "position": {
                        "type": "string",
                        "description": "Position: 'in_front', 'looking_at', 'here', or 'x,y,z' coordinates"
                    },
                    "magnitude": {
                        "type": "integer",
                        "description": "Explosion power (10-1000, default 100)"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "create_fire",
            "description": "Create fire at a location",
            "parameters": {
                "type": "object",
                "properties": {
                    "position": {
                        "type": "string",
                        "description": "Position: 'in_front', 'looking_at', 'here', or 'x,y,z' coordinates"
                    },
                    "size": {
                        "type": "integer",
                        "description": "Fire size (default 128)"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "cleanup",
            "description": "Remove spawned entities",
            "parameters": {
                "type": "object",
                "properties": {
                    "class": {
                        "type": "string",
                        "description": "Remove specific entity class (e.g., 'prop_physics', 'npc_zombie')"
                    },
                    "all_props": {
                        "type": "boolean",
                        "description": "Remove all physics props"
                    },
                    "all_npcs": {
                        "type": "boolean",
                        "description": "Remove all NPCs"
                    },
                    "all": {
                        "type": "boolean",
                        "description": "Remove everything spawned"
                    },
                    "radius": {
                        "type": "integer",
                        "description": "Only remove within this radius from player"
                    }
                }
            }
        }
    },
    
    # ============================================
    # INFORMATION TOOLS
    # ============================================
    {
        "type": "function",
        "function": {
            "name": "get_player_info",
            "description": "Get detailed information about the requesting player (health, position, weapons, etc.)",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_entities_nearby",
            "description": "Get a list of entities near the player",
            "parameters": {
                "type": "object",
                "properties": {
                    "radius": {
                        "type": "integer",
                        "description": "Search radius in units (default 500)"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_server_info",
            "description": "Get information about the server (map, players, gamemode)",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_map_entities",
            "description": "Get a summary of all entity types on the map",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    
    # ============================================
    # ENTITY MANIPULATION TOOLS
    # ============================================
    {
        "type": "function",
        "function": {
            "name": "remove_entity",
            "description": "Remove a specific entity by its ID",
            "parameters": {
                "type": "object",
                "properties": {
                    "entity_id": {
                        "type": "integer",
                        "description": "The entity ID to remove"
                    }
                },
                "required": ["entity_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "set_entity_color",
            "description": "Change an entity's color",
            "parameters": {
                "type": "object",
                "properties": {
                    "entity_id": {
                        "type": "integer",
                        "description": "Entity ID (omit to use what player is looking at)"
                    },
                    "color": {
                        "type": "string",
                        "description": "Color name: red, green, blue, yellow, purple, orange, pink, white, black, invisible"
                    },
                    "r": {"type": "integer", "description": "Red (0-255)"},
                    "g": {"type": "integer", "description": "Green (0-255)"},
                    "b": {"type": "integer", "description": "Blue (0-255)"},
                    "a": {"type": "integer", "description": "Alpha/transparency (0-255)"}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "set_entity_material",
            "description": "Change an entity's material/texture",
            "parameters": {
                "type": "object",
                "properties": {
                    "entity_id": {
                        "type": "integer",
                        "description": "Entity ID (omit to use what player is looking at)"
                    },
                    "material": {
                        "type": "string",
                        "description": "Material: metal, chrome, wood, invisible, wireframe, debug, or a material path"
                    }
                },
                "required": ["material"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "physgun_freeze",
            "description": "Freeze or unfreeze an entity",
            "parameters": {
                "type": "object",
                "properties": {
                    "entity_id": {
                        "type": "integer",
                        "description": "Entity ID (omit to use what player is looking at)"
                    },
                    "freeze": {
                        "type": "boolean",
                        "description": "True to freeze, false to unfreeze, omit to toggle"
                    }
                }
            }
        }
    },
    
    # ============================================
    # EFFECT TOOLS
    # ============================================
    {
        "type": "function",
        "function": {
            "name": "play_sound",
            "description": "Play a sound effect",
            "parameters": {
                "type": "object",
                "properties": {
                    "sound": {
                        "type": "string",
                        "description": "Sound: explosion, beep, success, fail, alarm, horn, laugh, or a sound file path"
                    },
                    "global": {
                        "type": "boolean",
                        "description": "Play for all players"
                    }
                },
                "required": ["sound"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "create_light",
            "description": "Create a dynamic light source",
            "parameters": {
                "type": "object",
                "properties": {
                    "position": {
                        "type": "string",
                        "description": "Position: 'in_front', 'looking_at', 'here', or 'x,y,z' coordinates"
                    },
                    "color": {
                        "type": "string",
                        "description": "Light color as 'R G B' (e.g., '255 0 0' for red)"
                    },
                    "brightness": {
                        "type": "number",
                        "description": "Light brightness (default 2)"
                    },
                    "distance": {
                        "type": "integer",
                        "description": "Light radius in units (default 256)"
                    }
                }
            }
        }
    },
    
    # ============================================
    # ADMIN TOOLS (require admin permission)
    # ============================================
    {
        "type": "function",
        "function": {
            "name": "run_command",
            "description": "Run a console command (ADMIN ONLY)",
            "parameters": {
                "type": "object",
                "properties": {
                    "command": {
                        "type": "string",
                        "description": "The console command to execute"
                    }
                },
                "required": ["command"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "change_map",
            "description": "Change the current map (ADMIN ONLY)",
            "parameters": {
                "type": "object",
                "properties": {
                    "map": {
                        "type": "string",
                        "description": "Map name (e.g., 'gm_construct', 'gm_flatgrass')"
                    }
                },
                "required": ["map"]
            }
        }
    },
    
    # ============================================
    # AI LIVE COMPANION TOOLS
    # ============================================
    {
        "type": "function",
        "function": {
            "name": "ai_live_spawn",
            "description": "Spawn an AI companion that looks like the player and can navigate/interact with the game world. Uses DrGBase for navmesh navigation. The AI responds only to commands.",
            "parameters": {
                "type": "object",
                "properties": {
                    "name": {
                        "type": "string",
                        "description": "Optional name for the AI companion (default: 'AI Companion')"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_remove",
            "description": "Remove your AI companion",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_move_to",
            "description": "Command your AI companion to move to a location. Use position='looking_at' to send it where the player is looking.",
            "parameters": {
                "type": "object",
                "properties": {
                    "position": {
                        "type": "string",
                        "description": "Position: 'looking_at' (at crosshair), 'in_front', 'behind', or 'x,y,z' coordinates"
                    }
                },
                "required": ["position"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_follow",
            "description": "Command your AI companion to follow you",
            "parameters": {
                "type": "object",
                "properties": {
                    "enable": {
                        "type": "boolean",
                        "description": "True to start following, false to stop (default: true)"
                    },
                    "distance": {
                        "type": "integer",
                        "description": "Distance to maintain from player (default: 150)"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_stop",
            "description": "Command your AI companion to stop moving/following",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_attack",
            "description": "Command your AI companion to attack an entity (NPCs only, won't attack players)",
            "parameters": {
                "type": "object",
                "properties": {
                    "entity_id": {
                        "type": "integer",
                        "description": "Entity ID to attack (omit to attack what player is looking at)"
                    },
                    "target": {
                        "type": "string",
                        "description": "Use 'looking_at' to attack what player is aiming at"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_interact",
            "description": "Command your AI companion to interact with/use an entity (buttons, doors, etc.)",
            "parameters": {
                "type": "object",
                "properties": {
                    "entity_id": {
                        "type": "integer",
                        "description": "Entity ID to interact with (omit to use what player is looking at)"
                    }
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_give_weapon",
            "description": "Give your AI companion a weapon",
            "parameters": {
                "type": "object",
                "properties": {
                    "weapon": {
                        "type": "string",
                        "description": "Weapon: crowbar, pistol, smg, shotgun, ar2, rpg, crossbow, 357, etc."
                    }
                },
                "required": ["weapon"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_set_health",
            "description": "Set your AI companion's health",
            "parameters": {
                "type": "object",
                "properties": {
                    "health": {
                        "type": "integer",
                        "description": "Health value (1-1000)"
                    }
                },
                "required": ["health"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_say",
            "description": "Make your AI companion say something in chat",
            "parameters": {
                "type": "object",
                "properties": {
                    "text": {
                        "type": "string",
                        "description": "Message for the AI to say"
                    }
                },
                "required": ["text"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_status",
            "description": "Get the status of your AI companion (health, position, state, weapon)",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    
    # ============================================
    # AI LIVE PHASE 1: CORE INTERACTIONS
    # ============================================
    {
        "type": "function",
        "function": {
            "name": "ai_live_look_at",
            "description": "Make your AI companion look at a position or entity",
            "parameters": {
                "type": "object",
                "properties": {
                    "entity_id": {"type": "integer", "description": "Entity ID to look at"},
                    "position": {"type": "string", "description": "Position: 'looking_at', 'x,y,z' coords"}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_use",
            "description": "Make your AI use/interact with an entity (press E) - doors, buttons, etc.",
            "parameters": {
                "type": "object",
                "properties": {
                    "entity_id": {"type": "integer", "description": "Entity ID to use (omit for what AI is looking at)"}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_crouch",
            "description": "Make your AI crouch or stand up",
            "parameters": {
                "type": "object",
                "properties": {
                    "enable": {"type": "boolean", "description": "True to crouch, false to stand"}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_jump",
            "description": "Make your AI jump",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_gesture",
            "description": "Make your AI perform a gesture/act (wave, dance, bow, laugh, cheer, salute, robot, zombie, etc.)",
            "parameters": {
                "type": "object",
                "properties": {
                    "gesture": {"type": "string", "description": "Gesture name: wave, dance, bow, laugh, cheer, agree, disagree, salute, point, robot, muscle, zombie"}
                },
                "required": ["gesture"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_kill",
            "description": "Make your AI die (suicide)",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_scan",
            "description": "Get what your AI can see around it - returns list of nearby entities",
            "parameters": {
                "type": "object",
                "properties": {
                    "radius": {"type": "integer", "description": "Search radius (default 1000)"}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_inspect",
            "description": "Get detailed info about an entity your AI is looking at",
            "parameters": {
                "type": "object",
                "properties": {
                    "entity_id": {"type": "integer", "description": "Entity to inspect (omit for what AI is facing)"}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_inventory",
            "description": "Get your AI's current weapons/inventory",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    
    # ============================================
    # AI LIVE PHASE 2: TACTICAL MOVEMENT
    # ============================================
    {
        "type": "function",
        "function": {
            "name": "ai_live_find_cover",
            "description": "Make your AI find cover from enemies using navmesh",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_flank",
            "description": "Make your AI flank the current target (move to the side/behind)",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_retreat",
            "description": "Make your AI retreat from danger",
            "parameters": {
                "type": "object",
                "properties": {
                    "distance": {"type": "integer", "description": "Distance to retreat (default 500)"}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_patrol",
            "description": "Make your AI patrol randomly around the area",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    
    # ============================================
    # AI LIVE PHASE 3: PHYSICS & BUILDING
    # ============================================
    {
        "type": "function",
        "function": {
            "name": "ai_live_physgun_pickup",
            "description": "Make your AI pick up an object (simulated physgun)",
            "parameters": {
                "type": "object",
                "properties": {
                    "entity_id": {"type": "integer", "description": "Entity to pick up (omit for what AI is looking at)"}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_physgun_drop",
            "description": "Make your AI drop the held object",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_physgun_freeze",
            "description": "Make your AI freeze the held object in place (like right-click physgun)",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_physgun_throw",
            "description": "Make your AI throw the held object",
            "parameters": {
                "type": "object",
                "properties": {
                    "force": {"type": "integer", "description": "Throw force (default 1000)"}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_spawn_prop",
            "description": "Make your AI spawn a prop",
            "parameters": {
                "type": "object",
                "properties": {
                    "model": {"type": "string", "description": "Model path (e.g., props_c17/oildrum001.mdl)"}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_remove_prop",
            "description": "Make your AI remove a prop it's looking at",
            "parameters": {
                "type": "object",
                "properties": {
                    "entity_id": {"type": "integer", "description": "Entity to remove (omit for what AI is looking at)"}
                }
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_weld",
            "description": "Make your AI weld two props together",
            "parameters": {
                "type": "object",
                "properties": {
                    "entity1_id": {"type": "integer", "description": "First entity ID"},
                    "entity2_id": {"type": "integer", "description": "Second entity ID"}
                },
                "required": ["entity1_id", "entity2_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_cleanup",
            "description": "Make your AI clean up all props it has spawned",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    
    # ============================================
    # AI LIVE PHASE 4: VEHICLE CONTROL
    # ============================================
    {
        "type": "function",
        "function": {
            "name": "ai_live_enter_vehicle",
            "description": "Make your AI enter the nearest empty vehicle",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_exit_vehicle",
            "description": "Make your AI exit its current vehicle",
            "parameters": {
                "type": "object",
                "properties": {}
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ai_live_drive_to",
            "description": "Make your AI drive the vehicle toward a position",
            "parameters": {
                "type": "object",
                "properties": {
                    "position": {"type": "string", "description": "Position: 'looking_at', or 'x,y,z'"}
                },
                "required": ["position"]
            }
        }
    }
]


def get_tool_names():
    """Get list of all available tool names."""
    return [tool["function"]["name"] for tool in GMOD_TOOLS]


def get_tool_by_name(name):
    """Get a specific tool definition by name."""
    for tool in GMOD_TOOLS:
        if tool["function"]["name"] == name:
            return tool
    return None
