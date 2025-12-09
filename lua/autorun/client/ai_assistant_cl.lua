--[[
    AI Assistant Client-Side
    Handles HUD, chat display, and streaming response UI.
]]

AIAssistant = AIAssistant or {}
AIAssistant.Client = AIAssistant.Client or {}

-- State
AIAssistant.Client.IsThinking = false
AIAssistant.Client.StreamText = ""
AIAssistant.Client.ShowStream = false
AIAssistant.Client.ThinkingDots = 0
AIAssistant.Client.LastDotTime = 0

-- Colors
local COLOR_ASSISTANT_NAME = Color(100, 200, 255)
local COLOR_ASSISTANT_TEXT = Color(255, 255, 255)
local COLOR_THINKING = Color(180, 180, 180)
local COLOR_TOOL = Color(255, 200, 100)

-- Receive AI response
net.Receive("AIAssistant_Response", function()
    local text = net.ReadString()
    
    AIAssistant.Client.IsThinking = false
    AIAssistant.Client.ShowStream = false
    AIAssistant.Client.StreamText = ""
    
    -- Display in chat
    chat.AddText(
        COLOR_ASSISTANT_NAME, "[AI Assistant] ",
        COLOR_ASSISTANT_TEXT, text
    )
    
    -- Play notification sound
    surface.PlaySound("buttons/button14.wav")
end)

-- Receive streaming update
net.Receive("AIAssistant_StreamUpdate", function()
    local text = net.ReadString()
    
    AIAssistant.Client.StreamText = text
    AIAssistant.Client.ShowStream = true
    AIAssistant.Client.IsThinking = false
end)

-- Streaming ended
net.Receive("AIAssistant_StreamEnd", function()
    AIAssistant.Client.ShowStream = false
    AIAssistant.Client.StreamText = ""
end)

-- Thinking status
net.Receive("AIAssistant_Thinking", function()
    local thinking = net.ReadBool()
    AIAssistant.Client.IsThinking = thinking
    AIAssistant.Client.ThinkingDots = 0
    
    if thinking then
        AIAssistant.Client.StreamText = ""
        AIAssistant.Client.ShowStream = false
    end
end)

-- Tool execution notification
net.Receive("AIAssistant_ToolExec", function()
    local tool = net.ReadString()
    
    chat.AddText(
        COLOR_TOOL, "[AI] ",
        Color(200, 200, 200), "Executing: ",
        Color(255, 255, 255), tool
    )
end)

-- Draw streaming response / thinking indicator
hook.Add("HUDPaint", "AIAssistant_HUD", function()
    if not AIAssistant.Client.IsThinking and not AIAssistant.Client.ShowStream then
        return
    end
    
    local scrW, scrH = ScrW(), ScrH()
    local boxW = math.min(600, scrW - 100)
    local boxX = (scrW - boxW) / 2
    local boxY = scrH - 200
    
    -- Background
    surface.SetDrawColor(20, 20, 25, 240)
    surface.DrawRect(boxX, boxY, boxW, 100)
    
    -- Border
    surface.SetDrawColor(100, 200, 255, 200)
    surface.DrawOutlinedRect(boxX, boxY, boxW, 100, 2)
    
    -- Icon/Header
    draw.SimpleText("AI Assistant", "DermaLarge", boxX + 15, boxY + 10, COLOR_ASSISTANT_NAME)
    
    local text = ""
    
    if AIAssistant.Client.IsThinking then
        -- Animate dots
        if CurTime() - AIAssistant.Client.LastDotTime > 0.3 then
            AIAssistant.Client.ThinkingDots = (AIAssistant.Client.ThinkingDots % 3) + 1
            AIAssistant.Client.LastDotTime = CurTime()
        end
        
        text = "Thinking" .. string.rep(".", AIAssistant.Client.ThinkingDots)
        draw.SimpleText(text, "DermaDefault", boxX + 15, boxY + 45, COLOR_THINKING)
        
    elseif AIAssistant.Client.ShowStream then
        -- Show streaming text (truncate if too long)
        text = AIAssistant.Client.StreamText
        if #text > 200 then
            text = "..." .. string.sub(text, -197)
        end
        
        -- Word wrap
        surface.SetFont("DermaDefault")
        local lines = {}
        local currentLine = ""
        
        for word in string.gmatch(text, "%S+") do
            local testLine = currentLine .. (currentLine ~= "" and " " or "") .. word
            local w, h = surface.GetTextSize(testLine)
            
            if w > boxW - 30 then
                table.insert(lines, currentLine)
                currentLine = word
            else
                currentLine = testLine
            end
        end
        if currentLine ~= "" then
            table.insert(lines, currentLine)
        end
        
        -- Draw lines (max 3)
        for i, line in ipairs(lines) do
            if i > 3 then break end
            draw.SimpleText(line, "DermaDefault", boxX + 15, boxY + 30 + (i * 18), COLOR_ASSISTANT_TEXT)
        end
    end
end)

-- Console command for client-side status
concommand.Add("ai_client_status", function()
    print("[AI Assistant Client]")
    print("  Thinking:", AIAssistant.Client.IsThinking)
    print("  Streaming:", AIAssistant.Client.ShowStream)
    print("  Stream Length:", #AIAssistant.Client.StreamText)
end)

print("[AI Assistant] Client loaded")
