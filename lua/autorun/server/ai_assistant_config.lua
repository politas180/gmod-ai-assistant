--[[
    AI Assistant Configuration
    Configure the bridge connection and assistant settings here.
]]

AIAssistant = AIAssistant or {}
AIAssistant.Config = AIAssistant.Config or {}

-- Bridge WebSocket Settings
AIAssistant.Config.BRIDGE_URL = "ws://localhost:8765"
AIAssistant.Config.RECONNECT_DELAY = 5 -- Seconds between reconnection attempts
AIAssistant.Config.MAX_RECONNECT_DELAY = 60 -- Maximum delay (exponential backoff cap)

-- Assistant Settings
AIAssistant.Config.ASSISTANT_NAME = "AI Assistant"
AIAssistant.Config.CHAT_PREFIX = "!ai" -- Players type "!ai <message>" to talk to the assistant
AIAssistant.Config.CHAT_PREFIX_ALT = "/ai" -- Alternative prefix

-- Colors for chat messages
AIAssistant.Config.Colors = {
    AssistantName = Color(100, 200, 255), -- Light blue for assistant name
    AssistantText = Color(255, 255, 255), -- White for assistant messages
    Thinking = Color(180, 180, 180), -- Gray for "thinking" status
    Error = Color(255, 100, 100), -- Red for errors
    Success = Color(100, 255, 100), -- Green for success messages
    ToolCall = Color(255, 200, 100), -- Orange for tool execution notices
}

-- Access Control (empty = all players allowed)
-- Add SteamID64s here to restrict access, e.g.: {"76561198012345678", "76561198087654321"}
AIAssistant.Config.ALLOWED_PLAYERS = {}

-- Tool Permissions (which tools require admin)
AIAssistant.Config.ADMIN_ONLY_TOOLS = {
    "run_command",
    "kick_player",
    "ban_player",
}

-- Debug mode
AIAssistant.Config.DEBUG = true

-- Utility function for debug logging
function AIAssistant.Debug(...)
    if AIAssistant.Config.DEBUG then
        print("[AI Assistant]", ...)
    end
end

-- Check if a player can use the assistant
function AIAssistant.CanUse(ply)
    if not IsValid(ply) then return false end
    
    -- If no whitelist, everyone can use
    if #AIAssistant.Config.ALLOWED_PLAYERS == 0 then
        return true
    end
    
    -- Check whitelist
    local steamid = ply:SteamID64()
    for _, id in ipairs(AIAssistant.Config.ALLOWED_PLAYERS) do
        if id == steamid then
            return true
        end
    end
    
    return false
end

-- Check if a player can use a specific tool
function AIAssistant.CanUseTool(ply, toolName)
    if not AIAssistant.CanUse(ply) then return false end
    
    -- Check if tool is admin-only
    for _, tool in ipairs(AIAssistant.Config.ADMIN_ONLY_TOOLS) do
        if tool == toolName then
            return ply:IsAdmin() or ply:IsSuperAdmin()
        end
    end
    
    return true
end

AIAssistant.Debug("Configuration loaded")
