local recipes = require("recipes")
local logic = require("logic")
local ui = require("ui")

local chest = peripheral.find("minecraft:chest")
local stand = peripheral.find("minecraft:brewing_stand")
local tName = os.getComputerLabel() or "turtle"
local isBrewing = false

-- Forward declarations for recursive menus
local mainMenu

-----------------------------------------------------------
-- 1. BREW SUB-MENU
-----------------------------------------------------------
local function brewQuantityMenu(name)
    local max = logic.calculateMaxBrews(name, recipes)
    local items = {
        { text = "Confirm Brew", handler = function()
            term.clear()
            term.setCursorPos(1,1)
            print("How many batches? (Max: "..max..")")
            local qty = tonumber(read())
            if qty and qty > 0 and qty <= max then
                executeBrew(name, qty)
            else
                print("Invalid amount.")
                os.sleep(1)
            end
        end},
        { text = "Back", handler = function() mainMenu() end }
    }
    ui.new(name:upper() .. " (Max: " .. max .. ")", items):run()
end

local function craftableMenu()
    local items = {}
    for name, _ in pairs(recipes) do
        local m = logic.calculateMaxBrews(name, recipes)
        if m > 0 then
            table.insert(items, { text = name .. " ("..m..")", handler = function() brewQuantityMenu(name) end })
        end
    end
    table.insert(items, { text = "Back", handler = function() mainMenu() end })
    ui.new("CRAFTABLE POTIONS", items):run()
end

-----------------------------------------------------------
-- 2. MISSING SUB-MENU
-----------------------------------------------------------
local function showMissingDetails(name)
    term.clear()
    term.setCursorPos(1,2)
    term.setTextColor(colors.yellow)
    print("MISSING INGREDIENTS FOR: " .. name:upper())
    term.setTextColor(colors.white)
    
    local plan = logic.getBrewingPlan(name, recipes)
    for _, step in ipairs(plan) do
        local count = logic.getStock(step.name)
        if count == 0 then
            term.setTextColor(colors.red)
            print(" - " .. step.name .. ": MISSING")
        else
            term.setTextColor(colors.green)
            print(" - " .. step.name .. ": OK ("..count..")")
        end
    end
    
    print("\nPress any key to go back...")
    os.pullEvent("key")
end

local function missingMenu()
    local items = {}
    for name, _ in pairs(recipes) do
        if logic.calculateMaxBrews(name, recipes) == 0 then
            table.insert(items, { text = name, handler = function() showMissingDetails(name) end })
        end
    end
    table.insert(items, { text = "Back", handler = function() mainMenu() end })
    ui.new("UNCRAFTABLE", items):run()
end

-----------------------------------------------------------
-- 3. STATUS & ADMIN
-----------------------------------------------------------
local function statusScreen()
    term.clear()
    term.setCursorPos(1,2)
    print("STOCK LEVELS:")
    print("Water: " .. logic.getStock("_water"))
    print("Awkward: " .. logic.getStock("_awkward"))
    print("Fuel: " .. logic.getStock("minecraft:blaze_powder"))
    print("\nPress any key...")
    os.pullEvent("key")
    mainMenu()
end

local function adminMenu()
    local items = {
        { text = "Global Eject", handler = function() logic.globalEject(chest, stand, tName) end },
        { text = "Back", handler = function() mainMenu() end }
    }
    ui.new("ADMIN TOOLS", items):run()
end

-----------------------------------------------------------
-- MAIN MENU ORCHESTRATOR
-----------------------------------------------------------
function mainMenu()
    local items = {
        { text = "Brew", handler = craftableMenu },
        { text = "Missing", handler = missingMenu },
        { text = "Status", handler = statusScreen },
        { text = "Admin Tools", handler = adminMenu }
    }
    ui.new("ALCH-OS v3.0", items):run()
end

-- Core Background task (Logic & Maintenance)
local function backgroundWorker()
    while true do
        logic.updateSnapshot(chest)
        if not isBrewing then
            logic.fillWaterBottles(chest, tName)
            logic.manageFuel(chest, stand)
            -- Simple Sorter
            local keepers = {["minecraft:potion"]=true, ["minecraft:glass_bottle"]=true, ["minecraft:blaze_powder"]=true, ["minecraft:nether_wart"]=true}
            for _, r in pairs(recipes) do keepers[r.ingredient] = true end
            for i=1, 16 do
                local itm = turtle.getItemDetail(i)
                if itm and not keepers[itm.name] then turtle.select(i) turtle.dropDown() end
            end
        end
        os.sleep(5)
    end
end

-- Start both
parallel.waitForAny(backgroundWorker, function()
    while true do mainMenu() end
end)
