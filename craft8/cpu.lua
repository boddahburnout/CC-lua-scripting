local CPU = {}
CPU.__index = CPU

-- ==========================================
-- 1. The Opcode Dispatch Table (The "Switch")
-- ==========================================

local OpcodeHandlers = {}
local MathHandlers = {}
local SystemHandlers = {}

math.randomseed(os.time())

-- ==========================================
-- Sub-Dispatch Tables (Defined ONCE outside)
-- ==========================================

-- Math Instructions (0x8)
MathHandlers[0x0] = function(self, x, y) self.V[x] = self.V[y] end
MathHandlers[0x1] = function(self, x, y) self.V[x] = bit32.bor(self.V[x], self.V[y]) end
MathHandlers[0x2] = function(self, x, y) self.V[x] = bit32.band(self.V[x], self.V[y]) end
MathHandlers[0x3] = function(self, x, y) self.V[x] = bit32.bxor(self.V[x], self.V[y]) end
MathHandlers[0x4] = function(self, x, y)
    local sum = self.V[x] + self.V[y]
    self.V[x] = bit32.band(sum, 0xFF)
    self.V[15] = (sum > 0xFF) and 1 or 0
end
MathHandlers[0x5] = function(self, x, y)
    local vx, vy = self.V[x], self.V[y]
    self.V[x] = bit32.band(vx - vy, 0xFF)
    self.V[15] = (vx >= vy) and 1 or 0
end
MathHandlers[0x6] = function(self, x, y)
    self.V[15] = bit32.band(self.V[x], 0x1)
    self.V[x] = bit32.rshift(self.V[x], 1)
end
MathHandlers[0x7] = function(self, x, y)
    local vx, vy = self.V[x], self.V[y]
    self.V[x] = bit32.band(vy - vx, 0xFF)
    self.V[15] = (vy >= vx) and 1 or 0
end
MathHandlers[0xE] = function(self, x, y)
    self.V[15] = bit32.rshift(bit32.band(self.V[x], 0x80), 7)
    self.V[x] = bit32.band(bit32.lshift(self.V[x], 1), 0xFF)
end

-- System Instructions (0xF)
SystemHandlers[0x07] = function(self, x)
    -- FX07: Set VX to the current value of the delay timer
    self.V[x] = self.DT
end

SystemHandlers[0x0A] = function(self, x)
    -- FX0A: Wait for key press
    local keyPressed = false
    for i = 0, 15 do
        if self.kb.keys[i] == true then
            self.V[x] = i
            keyPressed = true
            break
        end
    end
    if not keyPressed then self.PC = self.PC - 2 end
end

SystemHandlers[0x15] = function(self, x)
    -- FX15: Set delay timer to VX
    self.DT = self.V[x]
end

SystemHandlers[0x18] = function(self, x)
    -- FX18: Set sound timer to VX
    self.ST = self.V[x]
end

SystemHandlers[0x1E] = function(self, x)
    -- FX1E: Add VX to I
    self.I = self.I + self.V[x]
end

SystemHandlers[0x29] = function(self, x)
    -- FX29: Set I to the location of the sprite for the character in VX.
    -- (Sprites are 5 bytes long, starting at memory address 0x000)
    self.I = self.V[x] * 5
end

SystemHandlers[0x33] = function(self, x)
    -- FX33: Store Binary Coded Decimal representation of VX in memory at I, I+1, and I+2.
    local value = self.V[x]
    self.mem:write(self.I, math.floor(value / 100))
    self.mem:write(self.I + 1, math.floor((value % 100) / 10))
    self.mem:write(self.I + 2, value % 10)
end

SystemHandlers[0x55] = function(self, x)
    -- FX55: Store registers V0 through VX in memory starting at location I.
    for i = 0, x do
        self.mem:write(self.I + i, self.V[i])
    end
end

SystemHandlers[0x65] = function(self, x)
    -- FX65: Read registers V0 through VX from memory starting at location I.
    for i = 0, x do
        self.V[i] = self.mem:read(self.I + i)
    end
end

OpcodeHandlers[0x0] = function(self, opcode, x, y, n, nn, nnn)
if opcode == 0x00E0 then
        self.disp:clear()    
    elseif opcode == 0x00EE then
        self.SP = self.SP - 1
        self.PC = self.stack[self.SP]
    end
end

OpcodeHandlers[0x1] = function(self, opcode, x, y, n, nn, nnn)
    self.PC = nnn
end

OpcodeHandlers[0x2] = function(self, opcode, x, y, n, nn, nnn)
	self.stack[self.SP] = self.PC
	self.SP = self.SP + 1
	self.PC = nnn
end

OpcodeHandlers[0x3] = function(self, opcode, x, y, n, nn, nnn)
	if self.V[x] == nn then
		self.PC = self.PC + 2
	end
end

OpcodeHandlers[0x4] = function(self, opcode, x, y, n, nn, nnn)
	if self.V[x] ~= nn then
		self.PC = self.PC + 2
	end
end

OpcodeHandlers[0x5] = function(self, opcode, x, y, n, nn, nnn)
	if self.V[x] == self.V[y] then
		self.PC = self.PC + 2
	end
end

OpcodeHandlers[0x6] = function(self, opcode, x, y, n, nn, nnn)
    self.V[x] = nn
end

OpcodeHandlers[0x7] = function(self, opcode, x, y, n, nn, nnn)
    self.V[x] = bit32.band(self.V[x] + nn, 0xFF)
end

OpcodeHandlers[0x8] = function(self, opcode, x, y, n, nn, nnn)
    local handler = MathHandlers[n]
    if handler then handler(self, x, y) end
end

OpcodeHandlers[0x9] = function(self, opcode, x, y, n, nn, nnn)
	if self.V[x] ~= self.V[y] then
		self.PC = self.PC + 2
	end
end

OpcodeHandlers[0xA] = function(self, opcode, x, y, n, nn, nnn)
	self.I = nnn
end

OpcodeHandlers[0xB] = function(self, opcode, x, y, n, nn, nnn)
	self.PC = nnn + self.V[0]
end

OpcodeHandlers[0xC] = function(self, opcode, x, y, n, nn, nnn)
	self.V[x] = bit32.band(math.random(0, 255), nn)
end

OpcodeHandlers[0x0] = function(self, opcode, x, y, n, nn, nnn)
    if opcode == 0x00E0 then
        -- 00E0: Clear display
        self.disp:clear()
        
    elseif opcode == 0x00EE then
        -- (Your return from subroutine code is already here)
        self.SP = self.SP - 1
        self.PC = self.stack[self.SP]
    end
end

OpcodeHandlers[0xD] = function(self, opcode, x, y, n, nn, nnn)
    -- DXYN: Draw an N-pixel tall sprite from memory location I at (VX, VY)
    
    -- Note: x and y in the opcode refer to registers, so we must get the values inside them!
    local startX = self.V[x]
    local startY = self.V[y]
    
    self.V[15] = 0 -- Reset collision flag to 0 before drawing
    
    -- Loop through each row of the sprite (n rows total)
    for row = 0, n - 1 do
        -- Read the sprite row data from memory (starting at address I)
        local spriteByte = self.mem:read(self.I + row)
        
        -- Loop through the 8 pixels (bits) in this row
        for col = 0, 7 do
            -- Extract the current bit (1 = draw, 0 = ignore)
            local pixelBit = bit32.band(bit32.rshift(spriteByte, 7 - col), 1)
            
            if pixelBit == 1 then
                -- Calculate screen coordinates. CHIP-8 wraps around the screen edges!
                local screenX = (startX + col) % 64
                local screenY = (startY + row) % 32
                
                -- Check for collision (if the screen pixel is already ON)
                if self.disp.vram[screenY][screenX] == 1 then
                    self.V[15] = 1 -- Set VF flag
                end
                
                -- CHIP-8 drawing is done via XOR!
                self.disp.vram[screenY][screenX] = bit32.bxor(self.disp.vram[screenY][screenX], 1)
            end
        end
    end
    
    -- Tell the main loop the screen has changed
    self.disp.drawFlag = true
end

OpcodeHandlers[0xE] = function(self, opcode, x, y, n, nn, nnn)
    -- Both instructions check the key corresponding to the value inside register VX
    local targetKey = self.V[x]
    
    if nn == 0x9E then
        -- EX9E: Skip next instruction if key with the value of VX is pressed.
        if self.kb.keys[targetKey] == true then
            self.PC = self.PC + 2
        end
        
    elseif nn == 0xA1 then
        -- EXA1: Skip next instruction if key with the value of VX is NOT pressed.
        if self.kb.keys[targetKey] == false then
            self.PC = self.PC + 2
        end
    end
end

OpcodeHandlers[0xF] = function(self, opcode, x, y, n, nn, nnn)
    local handler = SystemHandlers[nn]
    if handler then handler(self, x) end
end

-- TODO: Add the rest of the prefixes (3, 4, 5, 8, 9, A, B, C, D, E, F)


-- ==========================================
-- 2. The CPU Class
-- ==========================================
function CPU.new(memory, keyboard, display)
    local self = setmetatable({}, CPU)
    self.mem = memory
    self.kb = keyboard
    self.disp = display
    
    self.V = {} 
    for i = 0, 15 do self.V[i] = 0 end
    
    self.I = 0       
    self.PC = 0x200  
    
    self.stack = {}
    self.SP = 0      
    
    self.DT = 0      
    self.ST = 0      
    
    return self
end

function CPU:cycle()
    local byte1 = self.mem:read(self.PC)
    local byte2 = self.mem:read(self.PC + 1)
    
    local opcode = bit32.bor(bit32.lshift(byte1, 8), byte2)
    self.PC = self.PC + 2
    
    self:execute(opcode)
end

function CPU:execute(opcode)
    -- Mask out the arguments
    local prefix = bit32.rshift(bit32.band(opcode, 0xF000), 12)
    local x      = bit32.rshift(bit32.band(opcode, 0x0F00), 8)
    local y      = bit32.rshift(bit32.band(opcode, 0x00F0), 4)
    local n      = bit32.band(opcode, 0x000F)
    local nn     = bit32.band(opcode, 0x00FF)
    local nnn    = bit32.band(opcode, 0x0FFF)

    -- Look up the function in our table using the prefix
    local handler = OpcodeHandlers[prefix]
    
    if handler then
        -- If it exists, call it and pass 'self' so it can access registers
        handler(self, opcode, x, y, n, nn, nnn)
    else
        -- Unimplemented opcode trap
        -- print(string.format("Unknown Opcode: 0x%04X", opcode))
    end
end

function CPU:updateTimers(ticks)
    if self.DT > 0 then self.DT = math.max(0, self.DT - ticks) end
    if self.ST > 0 then self.ST = math.max(0, self.ST - ticks) end
end

return CPU