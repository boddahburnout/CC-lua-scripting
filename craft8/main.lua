-- main.lua
local Memory = require("memory")
local CPU = require("cpu")
local Keyboard = require("keyboard")
local Display = require("display")
local pixelbox = require("pixelbox_lite")

local args = { ... }

-- If the user didn't type a filename, stop the program and tell them how to use it
if #args == 0 then
    print("Usage: chip8 <rom_file.ch8>")
    return
end

local romFilename = args[1]

local mem = Memory.new()
local kb = Keyboard.new()
local disp = Display.new()
local cpu = CPU.new(mem, kb, disp)

local speaker = peripheral.find("speaker")
if not speaker then
	print("Warning: No speaker attached! Audio disabled.")
	os.sleep(1)
end

print("Loading ROM: " .. romFilename)
local success, errorMessage = mem:loadRom(romFilename)

if not success then
    -- If it failed, print the error and exit
    print("Error: " .. errorMessage)
    return
end

print("ROM loaded! Booting CPU...")
os.sleep(1) -- Pause for a second so you can read the message

term.clear()

-- Load a dummy ROM into memory for testing
-- mem:write(0x200, 0x12) -- 1NNN (Jump)
-- mem:write(0x201, 0x00) -- to 0x200 (infinite loop)

-- Clock Settings
local TARGET_CPU_HZ = 500
local CC_TPS = 20 -- ComputerCraft ticks per second
local CPU_CYCLES_PER_TICK = math.floor(TARGET_CPU_HZ / CC_TPS) -- ~25 instructions per yield
local TIMER_DEC_PER_TICK = 3 -- 60Hz is exactly 3 times the 20Hz CC tick rate
local showDebug = true
local lastDebugTime = os.epoch("utc")
local cyclesThisSecond = 0
local framesThisSecond = 0
local displayFps = 0
local displayHz = 0

local box = pixelbox.new(term.current())

local function renderScreen()
    if not disp.drawFlag then return end

    box:clear(colors.black)
    
    for y = 0, 31 do
        for x = 0, 63 do
            if disp.vram[y][x] == 1 then
                box:set_pixel(x + 1, y + 1, colors.white)
            end
        end
    end
    
    box:render()
    disp.drawFlag = false
    
    -- Increment our frame tracker
    framesThisSecond = framesThisSecond + 1
    
    -- Draw the Debug Overlay on top of the pixelbox canvas
    if showDebug then
        term.setCursorPos(1, 1)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.yellow)
        term.write(string.format(" FPS:%3d | HZ:%4d ", displayFps, displayHz))
    end
end

local function cpuLoop()
    while true do
        for i = 1, CPU_CYCLES_PER_TICK do
            cpu:cycle()
            cyclesThisSecond = cyclesThisSecond + 1
        end
        
        cpu:updateTimers(TIMER_DEC_PER_TICK)
        renderScreen() 

	if cpu.ST > 0 and speaker then
		speaker.playNote("bit", 1.0, 12)
	end
        
        -- Check if 1 real-world second has passed
        local now = os.epoch("utc")
        if now - lastDebugTime >= 1000 then
            displayFps = framesThisSecond
            displayHz = cyclesThisSecond
            
            -- Reset trackers for the next second
            framesThisSecond = 0
            cyclesThisSecond = 0
            lastDebugTime = now
        end
        
        os.sleep(0.05)
    end
end

local function eventLoop()
    while true do
        local event, p1, p2 = os.pullEvent()
        
        if event == "key" or event == "key_up" then
            kb:handleEvent(event, p1)
        elseif event == "char" and p1 == "p" then
            -- Panic button to exit the parallel loop safely
            print("Emulator stopped.")
            break
        end
    end
end

-- Start the emulator
term.clear()
term.setCursorPos(1,1)
print("Starting CHIP-8 Shell...")
parallel.waitForAny(cpuLoop, eventLoop)
