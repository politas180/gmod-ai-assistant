# GMod AI Assistant

An AI assistant for Garry's Mod that can **actually control your game**! Type `!ai spawn 10 zombies` and watch it happen.

## Features

- **Natural Language Commands**: Just type what you want in chat
- **40+ Game Tools**: Spawn props, NPCs, vehicles, give weapons, change gravity, teleport, and more
- **Cloud & Local AI**: Use free Cerebras API or run AI locally with LM Studio/Ollama
- **Streaming Responses**: Watch the AI think in real-time
- **Context Aware**: AI knows your position, health, what you're looking at
- **AI Live Companion**: Spawn an AI buddy that fights alongside you!

## Installation

### Step 1: Subscribe on Steam Workshop
Subscribe to the addon on the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=YOUR_WORKSHOP_ID)

### Step 2: Install GWSockets (REQUIRED)
1. Download `gmsv_gwsockets_win32.dll` from [GWSockets Releases](https://github.com/FredyH/GWSockets/releases)
2. Place it in: `GarrysMod/lua/bin/` (create the `bin` folder if needed)
3. Restart GMod

### Step 3: Download the Bridge Server
Download the latest release from the [Releases page](https://github.com/Politas180/gmod-ai-assistant/releases) and extract the `bridge/` folder.

### Step 4: Get a FREE AI API Key
1. Go to [cloud.cerebras.ai](https://cloud.cerebras.ai/)
2. Sign up for a **free** account
3. Create an API key
4. Open `bridge/config.py` and paste your key:
```python
CEREBRAS_API_KEY = "your-api-key-here"
```

### Step 5: Install Python Requirements
```bash
cd bridge
pip install -r requirements.txt
```

## Usage

### 1. Start the Bridge Server
```bash
cd bridge
python bridge_server.py
```
Or double-click `run_bridge.bat` on Windows.

### 2. Launch Garry's Mod
Start a game (singleplayer works!) and you should see **"AI Assistant connected"** in chat.

### 3. Talk to the AI!
| Example | What happens |
|---------|--------------|
| `!ai Hello!` | AI greets you back |
| `!ai Spawn 5 zombies` | Spawns 5 zombies |
| `!ai Give me an RPG` | Gives you an RPG |
| `!ai Set gravity to moon` | Low gravity! |
| `!ai Make me tiny` | Shrinks your player |
| `!ai Teleport me somewhere random` | Teleports you |
| `!ai Spawn a tank` | Spawns a tank |

## 🛠️ Available Tools

### Spawning
- `spawn_prop` - Spawn any prop/model
- `spawn_npc` - Spawn zombies, combine, citizens (with count parameter!)
- `spawn_vehicle` - Spawn jeep, airboat, tank
- `spawn_entity` - Spawn any entity class

### Player Control
- `teleport_player` - Move around the map
- `give_weapon` - Get any weapon
- `set_player_health/armor` - Modify stats
- `set_player_speed/scale` - Speed and size
- `godmode` / `noclip` - Toggle abilities

### World
- `set_gravity` - Moon, Mars, zero-g, or custom
- `set_timescale` - Slow motion or speed up
- `explode` / `create_fire` - Destruction!
- `cleanup` - Clean up spawned entities

### AI Live Companion
- `ai_live_spawn` - Spawn your AI buddy
- `ai_live_follow/stop` - Movement control
- `ai_live_attack` - Combat commands
- `ai_live_give_weapon` - Arm your friend
- And 20+ more companion actions!

## ⚙️ Configuration

### Using Different AI Providers

Edit `bridge/config.py`:

**Cerebras (Cloud, Free)**
```python
PROVIDER = "cerebras"
CEREBRAS_API_KEY = "your-api-key"
```

**LM Studio (Local)**
```python
PROVIDER = "lmstudio"
```

**Ollama (Local)**
```python
PROVIDER = "ollama"
OLLAMA_MODEL = "llama3.1:8b"
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "GWSockets not found" | Place DLL in `lua/bin/`, restart GMod |
| "Not connected to bridge" | Run `bridge_server.py`, check firewall |
| AI doesn't respond | Check API key, check bridge console for errors |
| Commands don't work | Make sure model supports function/tool calling |

## Console Commands

| Command | Description |
|---------|-------------|
| `!ai <message>` | Chat with AI |
| `/ai <message>` | Alternative prefix |
| `ai_status` | Check connection |
| `ai_reconnect` | Reconnect to bridge |

## Contributing

Contributions are welcome! Feel free to submit issues and pull requests.

## License

MIT License - Do whatever you want with it!

---

**Made with ❤️ for the GMod community**
