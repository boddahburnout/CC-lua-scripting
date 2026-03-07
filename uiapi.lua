local ui = {}

function ui.new(title, items)
    local menu = {
        title = title or "Menu",
        items = items, -- Table of {text = "Name", callback = function}
        selected = 1,
        running = true
    }

    local w, h = term.getSize()

    -- Helper to center text
    local function drawCentered(text, y, bracket)
        local display = bracket and "[  " .. text .. "  ]" or text
        local x = math.floor((w - #display) / 2) + 1
        term.setCursorPos(x, y)
        term.write(display)
    end

    function menu:draw()
        term.clear()
        
        -- Draw Title
        term.setTextColor(colors.yellow)
        drawCentered("-- " .. self.title .. " --", 2)
        
        -- Draw Items
        for i, item in ipairs(self.items) do
            local y = 4 + i
            if i == self.selected then
                term.setTextColor(colors.white)
                drawCentered(item.text, y, true)
            else
                term.setTextColor(colors.gray)
                drawCentered(item.text, y, false)
            end
        end
        
        term.setTextColor(colors.white)
    end

    function menu:run()
        while self.running do
            self:draw()
            local event, key = os.pullEvent("key")
            
            if key == keys.up then
                self.selected = self.selected > 1 and self.selected - 1 or #self.items
            elseif key == keys.down then
                self.selected = self.selected < #self.items and self.selected + 1 or 1
            elseif key == keys.enter then
                term.clear()
                term.setCursorPos(1, 1)
                -- Execute the callback function for the selected item
                self.items[self.selected].handler()
                self.running = false -- Exit menu after selection
            end
        end
    end

    return menu
end

return ui