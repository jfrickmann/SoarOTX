-- TELEMETRY/JF5K/SK8.lua
-- Timestamp: 2021-01-02
-- Created by Jesper Frickmann
-- Set nominal start height

local sk = ...  -- List of variables shared between fixed and loadable parts

-- If no task is selected, then return name and task list to the menu
if sk.task == 0 then
	local name = "Launch Settings"

	local tasks = {
		"Launch"
	}

	return name, tasks
end

local ui = soarUtil.LoadWxH("JF5K/SK8.lua", sk) -- Screen size specific user interface
ui.cutoff = sk.GetStartHeight()
ui.time = model.getTimer(2).start
ui.editing = 1

local function run(event)
	if event == EVT_VIRTUAL_ENTER then
		ui.editing = ui.editing + 1
		if ui.editing == 3 then
			sk.run = sk.menu
			sk.SetStartHeight(ui.cutoff)
			model.setTimer(2, { start = ui.time, value = ui.time })
			return
		end
	end
	
	if ui.editing == 1 then
		if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
			if ui.cutoff >= 120 then
				playTone(3000, 100, 0, PLAY_NOW)
			else
				ui.cutoff = ui.cutoff + 1
			end
		elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
			if ui.cutoff <= 1 then
				playTone(3000, 100, 0, PLAY_NOW)
			else
				ui.cutoff = ui.cutoff - 1
			end
		end
	else
		if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
			if ui.time >= 30 then
				playTone(3000, 100, 0, PLAY_NOW)
			else
				ui.time = ui.time + 1
			end
		elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
			if ui.time <= 1 then
				playTone(3000, 100, 0, PLAY_NOW)
			else
				ui.time = ui.time - 1
			end
		end
	end
	
	ui.Draw()
	soarUtil.ShowHelp({ enter = "NEXT", ud = "CHANGE" })	
end

return { run = run }