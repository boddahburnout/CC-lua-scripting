-- memory.lua (or combined in main)
local Memory = {}
Memory.__index = Memory

function Memory.new()
    local self = setmetatable({}, Memory)
    self.ram = {}
    -- CHIP-8 has 4096 bytes of memory (0x000 to 0xFFF)
    for i = 0, 4095 do
        self.ram[i] = 0
    end
    return self
end

function Memory:read(address)
    return self.ram[address] or 0
end

function Memory:write(address, value)
    if address >= 0 and address < 4096 then
        -- Ensure we only store 8-bit values
        self.ram[address] = bit32.band(value, 0xFF)
    end
end

function Memory:loadRom(filename)
    -- Check if the file actually exists
    if not fs.exists(filename) then
        return false, "File does not exist: " .. filename
    end

    -- Open the file in "rb" (Read Binary) mode
    local file = fs.open(filename, "rb")
    if not file then
        return false, "Failed to open file."
    end

    -- CHIP-8 programs always start at address 0x200
    local currentAddress = 0x200 
    
    -- Read the first byte
    local byte = file.read()
    
    -- Loop through the file until we hit the end (when byte is nil)
    while byte ~= nil do
        self:write(currentAddress, byte)
        currentAddress = currentAddress + 1
        
        -- Prevent overflowing the 4KB RAM if a file is too large
        if currentAddress > 4095 then
            file.close()
            return false, "ROM is too large for memory!"
        end
        
        byte = file.read()
    end

    file.close()
    return true, "ROM loaded successfully."
end

return Memory