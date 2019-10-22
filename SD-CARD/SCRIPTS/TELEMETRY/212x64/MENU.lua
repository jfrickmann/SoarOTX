-- 212x64/MENU.lua
-- Timestamp: 2019-10-20
-- Created by Jesper Frickmann

local menu = { }
menu.items = { "EMPTY" } -- Menu menu.items
menu.title = "EMPTY" -- Menu menu.title
menu.firstItem = 1 -- Item on first line of menu

function menu.Draw(selected)
	soarUtil.InfoBar(menu.title)
	lcd.drawPixmap(156, 8, "/IMAGES/Lua-girl.bmp")

	-- Scroll if necessary
	if selected < menu.firstItem then
		menu.firstItem = selected
	elseif selected - menu.firstItem > 5 then
		menu.firstItem = selected - 5
	end
		
	for line = 1, math.min(6, #menu.items - menu.firstItem + 1) do
		local item = line + menu.firstItem - 1
		local y0 = 1 + 9 * line
		local att = 0
		
		if item == selected then att = INVERS end
		lcd.drawText(0, y0, menu.items[item], att)
	end
end -- Draw

return menu