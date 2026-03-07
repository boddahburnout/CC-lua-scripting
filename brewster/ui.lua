local ui = {}

function ui.new(title, items)
    local menu = {
        title = title or "Menu",
        items = items, 
        selected = 1,
        running = true
    }

    function menu:stop()
        self.running = false
    end

    local w, h = term.getSize()

    local function drawCentered(text, y, bracket)
        local display = bracket and "[  " .. text .. "  ]" or text
        local x = math.floor((w - #display) / 2) + 1
        term.setCursorPos(x, y)
        term.write(display)
    end

    function menu:draw()
        term.clear()
        term.setTextColor(colors.yellow)
        drawCentered("-- " .. self.title .. " --", 2)
        
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
    end

    function menu:run()
        while self.running do
            self:draw()
            local _, key = os.pullEvent("key")
            if key == keys.up then
                self.selected = self.selected > 1 and self.selected - 1 or #self.items
            elseif key == keys.down then
                self.selected = self.selected < #self.items and self.selected + 1 or 1
            elseif key == keys.enter then
                term.clear()
                term.setCursorPos(1, 1)
                self.items[self.selected].handler() -- Execute the handler
                self.running = false 
            end
        end
    end

    return menu
end

return ui
