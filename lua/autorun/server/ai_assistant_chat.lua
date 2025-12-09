--[[
    AI Assistant Chat Handler
    Captures player chat and sends to the AI bridge.
]]

-- Ensure AIAssistant global exists (handles load order)
AIAssistant = AIAssistant or {}
AIAssistant.Chat = AIAssistant.Chat or {}

-- Fallback Debug function if config hasn't loaded yet
AIAssistant.Debug = AIAssistant.Debug or function(...) print("[AI Assistant]", ...) end

-- Hook into player chat
hook.Add("PlayerSay", "AIAssistant_ChatHook", function(ply, text, teamChat)
    local lower = string.lower(text)
    
    -- Ignore AI Live commands - they are handled by ai_assistant_ai_live.lua
    if string.sub(lower, 1, 8) == "/ai_live" or string.sub(lower, 1, 8) == "!ai_live" then
        return -- Let the AI Live handler process these
    end
    
    -- Check for AI prefix
    local prefix = AIAssistant.Config.CHAT_PREFIX
    local prefixAlt = AIAssistant.Config.CHAT_PREFIX_ALT
    
    local message = nil
    
    if string.sub(text, 1, #prefix) == prefix then
        message = string.Trim(string.sub(text, #prefix + 1))
    elseif string.sub(text, 1, #prefixAlt) == prefixAlt then
        message = string.Trim(string.sub(text, #prefixAlt + 1))
    end
    
    if not message then return end -- Not an AI command
    
    -- Check if player can use AI
    if not AIAssistant.CanUse(ply) then
        ply:ChatPrint("[AI Assistant] You don't have permission to use the AI assistant.")
        return ""
    end
    
    -- Check for empty message
    if message == "" then
        ply:ChatPrint("[AI Assistant] Usage: " .. prefix .. " <your message>")
        return ""
    end
    
    -- Check connection status
    if not AIAssistant.WS.Connected then
        ply:ChatPrint("[AI Assistant] Not connected to bridge. Please wait or try !ai_reconnect")
        return ""
    end
    
    -- Show the player's message in chat with their name
    for _, p in ipairs(player.GetAll()) do
        p:ChatPrint(ply:Nick() .. " -> AI: " .. message)
    end
    
    -- Notify player we're processing
    net.Start("AIAssistant_Thinking")
    net.WriteBool(true)
    net.Send(ply)
    
    -- Send to bridge
    local success = AIAssistant.WS.SendChat(ply, message)
    
    if not success then
        ply:ChatPrint("[AI Assistant] Failed to send message. Please try again.")
    end
    
    return "" -- Suppress the original chat message
end)

-- Maximum bytes for chat message (GMod limit is 255, using 230 to leave room for prefix)
local MAX_MSG_BYTES = 230
local MSG_PREFIX = "[AI Assistant] "

-- Split text into chunks that fit within GMod's 255 byte limit
function AIAssistant.Chat.SplitMessage(text)
    if not text or text == "" then
        return {}
    end
    
    -- Check if message fits as-is (accounting for prefix)
    local fullMsg = MSG_PREFIX .. text
    if #fullMsg <= MAX_MSG_BYTES then
        return {text}
    end
    
    local chunks = {}
    local maxTextBytes = MAX_MSG_BYTES - #MSG_PREFIX
    local current = ""
    
    -- First try to split on sentence boundaries (. ! ?)
    local sentences = {}
    for sentence in string.gmatch(text, "[^%.!?]+[%.!?]*%s*") do
        table.insert(sentences, sentence)
    end
    
    -- If no sentences found, treat whole text as one
    if #sentences == 0 then
        sentences = {text}
    end
    
    for _, sentence in ipairs(sentences) do
        -- Check if adding this sentence would exceed limit
        if #current + #sentence <= maxTextBytes then
            current = current .. sentence
        else
            -- Save current chunk if it has content
            if #current > 0 then
                table.insert(chunks, string.Trim(current))
            end
            
            -- If sentence itself is too long, split on words
            if #sentence > maxTextBytes then
                local words = {}
                for word in string.gmatch(sentence, "%S+%s*") do
                    table.insert(words, word)
                end
                
                current = ""
                for _, word in ipairs(words) do
                    if #current + #word <= maxTextBytes then
                        current = current .. word
                    else
                        if #current > 0 then
                            table.insert(chunks, string.Trim(current))
                        end
                        -- If single word is too long, just add it (will be truncated by GMod)
                        if #word > maxTextBytes then
                            table.insert(chunks, string.sub(word, 1, maxTextBytes))
                        else
                            current = word
                        end
                    end
                end
            else
                current = sentence
            end
        end
    end
    
    -- Add remaining content
    if #current > 0 then
        table.insert(chunks, string.Trim(current))
    end
    
    return chunks
end

-- Show AI response to player
function AIAssistant.Chat.ShowResponse(ply, text)
    if not IsValid(ply) then return end
    
    -- Stop thinking indicator
    net.Start("AIAssistant_Thinking")
    net.WriteBool(false)
    net.Send(ply)
    
    -- Split message if needed to avoid 255 byte limit
    local chunks = AIAssistant.Chat.SplitMessage(text)
    
    -- Send each chunk with a small delay to maintain order
    for i, chunk in ipairs(chunks) do
        timer.Simple((i - 1) * 0.15, function()
            if IsValid(ply) then
                ply:ChatPrint(MSG_PREFIX .. chunk)
            end
        end)
    end
    
    -- Note: We're using ChatPrint above, so we don't send AIAssistant_Response
    -- net message anymore (that would cause duplicate display on client)
    
    -- Also show in server console
    AIAssistant.Debug("Response to", ply:Nick() .. ":", string.sub(text, 1, 100))
end

-- Broadcast AI message to all players
function AIAssistant.Chat.Broadcast(text)
    for _, ply in ipairs(player.GetAll()) do
        AIAssistant.Chat.ShowResponse(ply, text)
    end
end

-- Console command for direct AI interaction (useful for testing)
concommand.Add("ai_say", function(ply, cmd, args)
    if not IsValid(ply) then return end
    
    local message = table.concat(args, " ")
    if message == "" then
        ply:ChatPrint("Usage: ai_say <your message>")
        return
    end
    
    if not AIAssistant.CanUse(ply) then
        ply:ChatPrint("You don't have permission to use the AI assistant.")
        return
    end
    
    if not AIAssistant.WS.Connected then
        ply:ChatPrint("Not connected to bridge.")
        return
    end
    
    AIAssistant.WS.SendChat(ply, message)
end)

-- Status command
concommand.Add("ai_status", function(ply)
    local status = AIAssistant.WS.Connected and "Connected" or "Disconnected"
    local msg = "[AI Assistant] Status: " .. status
    
    if AIAssistant.WS.ReconnectAttempts > 0 then
        msg = msg .. " (Reconnect attempts: " .. AIAssistant.WS.ReconnectAttempts .. ")"
    end
    
    if IsValid(ply) then
        ply:ChatPrint(msg)
    else
        print(msg)
    end
end)

-- Clear memory command
concommand.Add("ai_clear", function(ply)
    if not IsValid(ply) then return end
    
    if not AIAssistant.WS.Connected then
        ply:ChatPrint("[AI Assistant] Not connected to bridge.")
        return
    end
    
    -- Send clear command to AI (handled as special message)
    AIAssistant.WS.SendChat(ply, "clear")
    ply:ChatPrint("[AI Assistant] Memory clear requested...")
end)

-- Also handle !ai_clear in chat
hook.Add("PlayerSay", "AIAssistant_ClearMemory", function(ply, text)
    local lower = string.lower(text)
    
    if lower == "!ai_clear" or lower == "/ai_clear" then
        if AIAssistant.CanUse(ply) and AIAssistant.WS.Connected then
            AIAssistant.WS.SendChat(ply, "clear")
            ply:ChatPrint("[AI Assistant] Memory clear requested...")
        else
            ply:ChatPrint("[AI Assistant] Not connected or no permission.")
        end
        return ""
    end
    
    if lower == "!ai_memory" or lower == "/ai_memory" then
        if AIAssistant.CanUse(ply) and AIAssistant.WS.Connected then
            AIAssistant.WS.SendChat(ply, "memory")
        else
            ply:ChatPrint("[AI Assistant] Not connected or no permission.")
        end
        return ""
    end
end)

AIAssistant.Debug("Chat handler loaded")

