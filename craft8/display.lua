-- display.lua
local Display = {}
Display.__index = Display

function Display.new()
    local self = setmetatable({}, Display)
    
    -- Create a 64x32 2D array filled with 0s
    self.vram = {}
    for y = 0, 31 do
        self.vram[y] = {}
        for x = 0, 63 do
            self.vram[y][x] = 0
        end
    end
    
    -- A flag so the main loop knows when it actually needs to redraw
    self.drawFlag = false 
    return self
end

function Display:clear()
    for y = 0, 31 do
        for x = 0, 63 do
            self.vram[y][x] = 0
        end
    end
    self.drawFlag = true
end

return Display