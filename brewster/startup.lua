local function backgroundWorker()
    while true do
        logic.updateSnapshot(chest)
        
        if not isBrewing then
            -- 1. Auto-Stock Awkward Potions (< 15)
            if logic.getStock("_awkward") < 15 then
                local can = logic.getStock("minecraft:nether_wart") > 0 and 
                            (logic.getStock("_water") + logic.getStock("minecraft:glass_bottle")) >= 3
                if can then executeBrew("awkward", 1, true) end
            end

            -- 2. Physical Maintenance
            logic.fillWaterBottles(chest, tName)
            logic.manageFuel(chest, stand)
            if logic.getStock("minecraft:blaze_powder") < 5 then logic.craftBlazePowder(chest, tName) end
            if logic.getStock("minecraft:glass_bottle") < 6 then logic.craftBottles(chest, tName) end
            
            -- 3. AGGRESSIVE INVENTORY SORTER
            -- Define what we want to keep in the chest
            local keepers = {
                ["minecraft:potion"]=true, 
                ["minecraft:glass_bottle"]=true, 
                ["minecraft:blaze_powder"]=true, 
                ["minecraft:nether_wart"]=true, 
                ["minecraft:glass"]=true, 
                ["minecraft:blaze_rod"]=true
            }
            -- Dynamically add all ingredients from your recipes file
            for _, r in pairs(recipes) do keepers[r.ingredient] = true end

            for i = 1, 16 do
                local itm = turtle.getItemDetail(i)
                if itm then
                    if keepers[itm.name] then
                        -- It's a useful item, put it in the chest
                        turtle.select(i)
                        chest.pullItems(tName, i) 
                    else
                        -- It's junk, get rid of it
                        turtle.select(i)
                        turtle.dropDown() -- Or turtle.drop() depending on your setup
                    end
                end
            end
        end
        os.sleep(5)
    end
end

-----------------------------------------------------------
-- 4. BOOT ORCHESTRATOR
-----------------------------------------------------------
parallel.waitForAny(backgroundWorker, function()
    while true do mainMenu() end
end)
