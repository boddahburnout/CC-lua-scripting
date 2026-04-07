-- keyboard.lua
local Keyboard = {}
Keyboard.__index = Keyboard

function Keyboard.new()
    local self = setmetatable({}, Keyboard)
    self.keys = {}
    for i = 0, 15 do
        self.keys[i] = false
    end
    
    -- Map CC key codes to CHIP-8 Hex keys
    self.keymap = {
        [keys.one] = 0x1, [keys.two] = 0x2, [keys.three] = 0x3, [keys.four] = 0xC,
        [keys.q]   = 0x4, [keys.w]   = 0x5, [keys.e]   = 0x6, [keys.r]   = 0xD,
        [keys.a]   = 0x7, [keys.s]   = 0x8, [keys.d]   = 0x9, [keys.f]   = 0xE,
        [keys.z]   = 0xA, [keys.x]   = 0x0, [keys.c]   = 0xB, [keys.v]   = 0xF
    }
    return self
end

function Keyboard:handleEvent(eventType, ccKey)
    local hexKey = self.keymap[ccKey]
    if hexKey then
        if eventType == "key" then
            self.keys[hexKey] = true
        elseif eventType == "key_up" then
            self.keys[hexKey] = false
        end
    end
end

return Keyboard -- Add this line!