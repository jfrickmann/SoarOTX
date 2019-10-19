-- 128x64/MENU.lua
-- Timestamp: 2019-10-17
-- Created by Jesper Frickmann

local menu = { }
menu.items = { "EMPTY" } -- Menu menu.items
menu.title = "EMPTY" -- Menu menu.title
menu.firstItem = 1 -- Item on first line of menu

local helpTexts = {
	rotary = "\192  \193",
	enter = "SELECT"
}

function menu.Draw(selected)
	soarUtil.InfoBar(menu.title)

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

	if menu.sub then 
		helpTexts.exit = "GO BACK"
	else
		helpTexts.exit = nil
	end

	soarUtil.ShowHelp(helpTexts)
end -- Draw

return menu