-- TELEMETRY/JF5K/SK8.lua
-- Timestamp: 2020-04-12
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
ui.cutoff, ui.zoom = sk.GetStartHeight()
ui.time = model.getTimer(2).start
ui.editing = 1

local function run(event)
	if soarUtil.EvtEnter(event) then
		ui.editing = ui.editing + 1
		if ui.editing == 4 then 
			sk.run = sk.menu
			sk.SetStartHeight(ui.cutoff, ui.zoom)
			model.setTimer(2, { start = ui.time, value = ui.time })
			return
		end
	end
	
	if ui.editing == 1 then
		if soarUtil.EvtInc(event) then
			if ui.cutoff + ui.zoom >= 120 then
				playTone(3000, 100, 0, PLAY_NOW)
			else
				ui.cutoff = ui.cutoff + 1
			end
		elseif soarUtil.EvtDec(event) then
			if ui.cutoff <= 3 then
				playTone(3000, 100, 0, PLAY_NOW)
			else
				ui.cutoff = ui.cutoff - 1
			end
		end
	elseif ui.editing == 2 then
		if soarUtil.EvtInc(event) then
			if ui.zoom >= 10 or ui.cutoff <= 3 or ui.cutoff + ui.zoom >= 120 then
				playTone(3000, 100, 0, PLAY_NOW)
			else
				ui.zoom = ui.zoom + 1
				ui.cutoff = ui.cutoff - 1
			end
		elseif soarUtil.EvtDec(event) then
			if ui.zoom <= 0 then
				playTone(3000, 100, 0, PLAY_NOW)
			else
				ui.zoom = ui.zoom - 1
				ui.cutoff = ui.cutoff + 1
			end
		end
	else
		if soarUtil.EvtInc(event) then
			if ui.time >= 30 then
				playTone(3000, 100, 0, PLAY_NOW)
			else
				ui.time = ui.time + 1
			end
		elseif soarUtil.EvtDec(event) then
			if ui.time <= 3 then
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