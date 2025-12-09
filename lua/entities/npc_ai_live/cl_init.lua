--[[
    AI Live Companion - Client
    Handles rendering and visual effects.
]]

if not DrGBase then return end

include("shared.lua")

-- Draw the AI name above their head
function ENT:CustomDraw()
    if LocalPlayer():GetPos():Distance(self:GetPos()) > 500 then return end
    
    local name = self:GetNW2String("AIName", "AI Companion")
    local owner = self:GetNW2Entity("OwnerPlayer")
    
    local pos = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 15)
    local ang = LocalPlayer():EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)
    
    cam.Start3D2D(pos, ang, 0.1)
        -- Draw name
        draw.SimpleTextOutlined(name, "DermaLarge", 0, 0, Color(100, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
        
        -- Draw owner name
        if IsValid(owner) then
            draw.SimpleTextOutlined("(" .. owner:Nick() .. "'s AI)", "DermaDefault", 0, 25, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
        end
        
        -- Draw health bar
        local health = self:Health()
        local maxHealth = self:GetMaxHealth()
        local healthPercent = health / maxHealth
        
        local barWidth = 100
        local barHeight = 8
        
        -- Background
        surface.SetDrawColor(0, 0, 0, 200)
        surface.DrawRect(-barWidth/2, 40, barWidth, barHeight)
        
        -- Health
        local healthColor = Color(
            255 * (1 - healthPercent),
            255 * healthPercent,
            0
        )
        surface.SetDrawColor(healthColor)
        surface.DrawRect(-barWidth/2 + 1, 41, (barWidth - 2) * healthPercent, barHeight - 2)
    cam.End3D2D()
end

-- Draw state indicator
function ENT:Think()
    -- Optional: Add particle effects or other visual feedback based on state
end
