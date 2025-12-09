--[[
    AI Assistant WebSocket Manager
    Handles connection to the Python bridge server using GWSockets.
]]

-- Ensure config is loaded first
if not AIAssistant then
    include("ai_assistant_config.lua")
end

AIAssistant.WS = AIAssistant.WS or {}
AIAssistant.WS.Socket = nil
AIAssistant.WS.Connected = false
AIAssistant.WS.ReconnectAttempts = 0
AIAssistant.WS.PendingCallbacks = {} -- For tracking responses

-- Try to load GWSockets
local gwsocketsLoaded = false
local function TryLoadGWSockets()
    if gwsocketsLoaded then return true end
    
    local success = pcall(require, "gwsockets")
    if success then
        gwsocketsLoaded = true
        AIAssistant.Debug("GWSockets loaded successfully")
        return true
    else
        AIAssistant.Debug("ERROR: GWSockets not found! Please install GWSockets from: https://github.com/FredyH/GWSockets/releases")
        return false
    end
end

-- Generate unique message ID
local messageIdCounter = 0
local function GenerateMessageId()
    messageIdCounter = messageIdCounter + 1
    return "msg_" .. os.time() .. "_" .. messageIdCounter
end

-- Connect to the bridge server
function AIAssistant.WS.Connect()
    if not TryLoadGWSockets() then
        timer.Simple(10, function()
            AIAssistant.Debug("Retrying GWSockets load...")
            AIAssistant.WS.Connect()
        end)
        return
    end
    
    -- Close existing connection if any
    if AIAssistant.WS.Socket then
        AIAssistant.WS.Socket:closeNow()
        AIAssistant.WS.Socket = nil
    end
    
    local url = AIAssistant.Config.BRIDGE_URL
    AIAssistant.Debug("Connecting to bridge at:", url)
    
    local socket = GWSockets.createWebSocket(url, false)
    
    function socket:onConnected()
        AIAssistant.WS.Connected = true
        AIAssistant.WS.ReconnectAttempts = 0
        AIAssistant.Debug("Connected to bridge server!")
        
        -- Notify all players
        for _, ply in ipairs(player.GetAll()) do
            ply:ChatPrint("[AI Assistant] Connected and ready! Type " .. AIAssistant.Config.CHAT_PREFIX .. " <message> to chat.")
        end
        
        -- Send handshake with server info
        AIAssistant.WS.Send({
            type = "handshake",
            server_name = GetHostName(),
            map = game.GetMap(),
            max_players = game.MaxPlayers(),
            player_count = #player.GetAll()
        })
    end
    
    function socket:onMessage(msg)
        AIAssistant.Debug("Received:", string.sub(msg, 1, 200))
        
        local success, data = pcall(util.JSONToTable, msg)
        if not success or not data then
            AIAssistant.Debug("Failed to parse message:", msg)
            return
        end
        
        AIAssistant.WS.HandleMessage(data)
    end
    
    function socket:onError(errMsg)
        AIAssistant.Debug("WebSocket error:", errMsg)
        AIAssistant.WS.Connected = false
    end
    
    function socket:onDisconnected()
        AIAssistant.Debug("Disconnected from bridge")
        AIAssistant.WS.Connected = false
        AIAssistant.WS.Socket = nil
        
        -- Schedule reconnection with exponential backoff
        AIAssistant.WS.ScheduleReconnect()
    end
    
    socket:open()
    AIAssistant.WS.Socket = socket
end

-- Schedule reconnection with exponential backoff
function AIAssistant.WS.ScheduleReconnect()
    AIAssistant.WS.ReconnectAttempts = AIAssistant.WS.ReconnectAttempts + 1
    
    local delay = math.min(
        AIAssistant.Config.RECONNECT_DELAY * (2 ^ (AIAssistant.WS.ReconnectAttempts - 1)),
        AIAssistant.Config.MAX_RECONNECT_DELAY
    )
    
    AIAssistant.Debug("Reconnecting in", delay, "seconds (attempt", AIAssistant.WS.ReconnectAttempts .. ")")
    
    timer.Simple(delay, function()
        if not AIAssistant.WS.Connected then
            AIAssistant.WS.Connect()
        end
    end)
end

-- Send a message to the bridge
function AIAssistant.WS.Send(data)
    if not AIAssistant.WS.Connected or not AIAssistant.WS.Socket then
        AIAssistant.Debug("Cannot send - not connected")
        return false
    end
    
    local json = util.TableToJSON(data)
    AIAssistant.Debug("Sending:", string.sub(json, 1, 200))
    AIAssistant.WS.Socket:write(json)
    return true
end

-- Send a chat message to the AI
function AIAssistant.WS.SendChat(ply, message)
    if not IsValid(ply) then return end
    
    local messageId = GenerateMessageId()
    
    -- Get what the player is looking at
    local trace = ply:GetEyeTrace()
    local lookingAt = nil
    if IsValid(trace.Entity) then
        lookingAt = {
            class = trace.Entity:GetClass(),
            model = trace.Entity:GetModel(),
            position = {
                x = math.Round(trace.Entity:GetPos().x),
                y = math.Round(trace.Entity:GetPos().y),
                z = math.Round(trace.Entity:GetPos().z)
            }
        }
    end
    
    local data = {
        type = "chat",
        message_id = messageId,
        player = {
            name = ply:Nick(),
            steamid = ply:SteamID64(),
            is_admin = ply:IsAdmin(),
            position = {
                x = math.Round(ply:GetPos().x),
                y = math.Round(ply:GetPos().y),
                z = math.Round(ply:GetPos().z)
            },
            angles = {
                pitch = math.Round(ply:EyeAngles().p),
                yaw = math.Round(ply:EyeAngles().y),
                roll = 0
            },
            health = ply:Health(),
            armor = ply:Armor(),
            weapon = IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() or "none",
            looking_at = lookingAt
        },
        text = message,
        map = game.GetMap(),
        time = os.time()
    }
    
    -- Store callback reference
    AIAssistant.WS.PendingCallbacks[messageId] = {
        player = ply,
        timestamp = os.time()
    }
    
    return AIAssistant.WS.Send(data)
end

-- Send tool execution result back to bridge
function AIAssistant.WS.SendToolResult(messageId, toolCallId, toolName, success, result)
    return AIAssistant.WS.Send({
        type = "tool_result",
        message_id = messageId,
        tool_call_id = toolCallId,
        tool = toolName,
        success = success,
        result = result
    })
end

-- Handle incoming messages from bridge
function AIAssistant.WS.HandleMessage(data)
    local msgType = data.type
    
    if msgType == "response" then
        -- AI text response
        AIAssistant.WS.HandleResponse(data)
        
    elseif msgType == "response_stream" then
        -- Streaming response chunk
        AIAssistant.WS.HandleStreamChunk(data)
        
    elseif msgType == "response_end" then
        -- End of streaming response
        AIAssistant.WS.HandleStreamEnd(data)
        
    elseif msgType == "tool_call" then
        -- AI wants to execute a tool
        AIAssistant.WS.HandleToolCall(data)
        
    elseif msgType == "thinking" then
        -- AI is processing
        AIAssistant.WS.HandleThinking(data)
        
    elseif msgType == "error" then
        -- Error from bridge/AI
        AIAssistant.WS.HandleError(data)
        
    else
        AIAssistant.Debug("Unknown message type:", msgType)
    end
end

-- Handle AI text response
function AIAssistant.WS.HandleResponse(data)
    -- Skip if streaming already delivered this message
    if AIAssistant.WS.DeliveredMessages and AIAssistant.WS.DeliveredMessages[data.message_id] then
        AIAssistant.WS.DeliveredMessages[data.message_id] = nil  -- Cleanup
        return
    end
    
    local callback = AIAssistant.WS.PendingCallbacks[data.message_id]
    if callback and IsValid(callback.player) then
        AIAssistant.Chat.ShowResponse(callback.player, data.text)
    else
        -- Broadcast to all if no specific player
        for _, ply in ipairs(player.GetAll()) do
            AIAssistant.Chat.ShowResponse(ply, data.text)
        end
    end
end

-- Streaming response storage
AIAssistant.WS.StreamBuffers = {}

-- Handle streaming response chunk
function AIAssistant.WS.HandleStreamChunk(data)
    local messageId = data.message_id
    
    -- Initialize buffer if needed
    if not AIAssistant.WS.StreamBuffers[messageId] then
        AIAssistant.WS.StreamBuffers[messageId] = {
            text = "",
            lastUpdate = 0
        }
    end
    
    -- Append chunk to buffer
    AIAssistant.WS.StreamBuffers[messageId].text = AIAssistant.WS.StreamBuffers[messageId].text .. (data.chunk or "")
    
    -- Rate-limit UI updates (every 100ms)
    local now = SysTime()
    if now - AIAssistant.WS.StreamBuffers[messageId].lastUpdate > 0.1 then
        AIAssistant.WS.StreamBuffers[messageId].lastUpdate = now
        
        local callback = AIAssistant.WS.PendingCallbacks[messageId]
        if callback and IsValid(callback.player) then
            -- Send streaming update to client
            net.Start("AIAssistant_StreamUpdate")
            net.WriteString(AIAssistant.WS.StreamBuffers[messageId].text)
            net.Send(callback.player)
        end
    end
end

-- Handle end of streaming
function AIAssistant.WS.HandleStreamEnd(data)
    local messageId = data.message_id
    local buffer = AIAssistant.WS.StreamBuffers[messageId]
    
    if buffer then
        local callback = AIAssistant.WS.PendingCallbacks[messageId]
        if callback and IsValid(callback.player) then
            -- Send final complete message
            AIAssistant.Chat.ShowResponse(callback.player, buffer.text)
            
            -- Mark as delivered to prevent duplicate from HandleResponse
            AIAssistant.WS.DeliveredMessages = AIAssistant.WS.DeliveredMessages or {}
            AIAssistant.WS.DeliveredMessages[messageId] = true
            
            -- Notify client that streaming is done
            net.Start("AIAssistant_StreamEnd")
            net.Send(callback.player)
        end
        
        -- Cleanup
        AIAssistant.WS.StreamBuffers[messageId] = nil
    end
    
    -- Cleanup callback
    AIAssistant.WS.PendingCallbacks[messageId] = nil
end

-- Handle tool call request
function AIAssistant.WS.HandleToolCall(data)
    local callback = AIAssistant.WS.PendingCallbacks[data.message_id]
    local ply = callback and callback.player or nil
    
    -- If no callback, try to find player by steam ID
    if not IsValid(ply) and data.player_id then
        for _, p in ipairs(player.GetAll()) do
            if p:SteamID64() == data.player_id then
                ply = p
                break
            end
        end
    end
    
    local toolName = data.tool
    local toolCallId = data.tool_call_id  -- Track the tool call ID for proper result matching
    local args = data.args or {}
    
    AIAssistant.Debug("Tool call:", toolName, "tool_call_id:", toolCallId, "args:", util.TableToJSON(args))
    
    -- Check permissions
    if IsValid(ply) and not AIAssistant.CanUseTool(ply, toolName) then
        AIAssistant.WS.SendToolResult(data.message_id, toolCallId, toolName, false, "Permission denied: " .. toolName .. " requires admin")
        return
    end
    
    -- Notify player about tool execution
    if IsValid(ply) then
        ply:ChatPrint("[AI Assistant] Executing: " .. toolName)
    end
    
    -- Execute the tool
    local success, result = AIAssistant.Tools.Execute(toolName, args, ply)
    
    -- Send result back to bridge (include tool_call_id for proper tracking)
    AIAssistant.WS.SendToolResult(data.message_id, toolCallId, toolName, success, result)
end

-- Handle "thinking" status
function AIAssistant.WS.HandleThinking(data)
    local callback = AIAssistant.WS.PendingCallbacks[data.message_id]
    if callback and IsValid(callback.player) then
        net.Start("AIAssistant_Thinking")
        net.WriteBool(true)
        net.Send(callback.player)
    end
end

-- Handle errors
function AIAssistant.WS.HandleError(data)
    local callback = AIAssistant.WS.PendingCallbacks[data.message_id]
    if callback and IsValid(callback.player) then
        callback.player:ChatPrint("[AI Assistant] Error: " .. (data.error or "Unknown error"))
    end
    
    -- Cleanup
    if data.message_id then
        AIAssistant.WS.PendingCallbacks[data.message_id] = nil
        AIAssistant.WS.StreamBuffers[data.message_id] = nil
    end
end

-- Disconnect from bridge
function AIAssistant.WS.Disconnect()
    if AIAssistant.WS.Socket then
        AIAssistant.WS.Socket:close()
        AIAssistant.WS.Socket = nil
    end
    AIAssistant.WS.Connected = false
end

-- Cleanup old pending callbacks periodically
timer.Create("AIAssistant_CleanupCallbacks", 60, 0, function()
    local now = os.time()
    for id, callback in pairs(AIAssistant.WS.PendingCallbacks) do
        if now - callback.timestamp > 300 then -- 5 minute timeout
            AIAssistant.WS.PendingCallbacks[id] = nil
            AIAssistant.WS.StreamBuffers[id] = nil
        end
    end
end)

-- Network strings for client communication
util.AddNetworkString("AIAssistant_Response")
util.AddNetworkString("AIAssistant_StreamUpdate")
util.AddNetworkString("AIAssistant_StreamEnd")
util.AddNetworkString("AIAssistant_Thinking")
util.AddNetworkString("AIAssistant_ToolExec")

-- Auto-connect on server start
hook.Add("Initialize", "AIAssistant_AutoConnect", function()
    timer.Simple(3, function()
        AIAssistant.WS.Connect()
    end)
end)

-- Reconnect command
concommand.Add("ai_reconnect", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then
        ply:ChatPrint("Only superadmins can use this command")
        return
    end
    
    AIAssistant.Debug("Manual reconnect requested")
    AIAssistant.WS.ReconnectAttempts = 0
    AIAssistant.WS.Connect()
end)

AIAssistant.Debug("WebSocket manager loaded")
