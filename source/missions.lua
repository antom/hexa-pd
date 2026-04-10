import 'mission_command'
import 'title'
import 'game'

-- Setting up consts
local pd <const> = playdate
local gfx <const> = pd.graphics
local smp <const> = pd.sound.sampleplayer
local text <const> = getLocalizedText

class('missions').extends(gfx.sprite) -- Create the scene's class
function missions:init(...)
	missions.super.init(self)
	local args = {...} -- Arguments passed in through the scene management will arrive here
	gfx.sprite.setAlwaysRedraw(true)

	function pd.gameWillPause() -- When the game's paused...
		local menu = pd.getSystemMenu()
		pauseimage()
		menu:removeAllMenuItems()
		if not scenemanager.transitioning then
			menu:addMenuItem(text('create'), function()
				scenemanager:transitionscene(mission_command, vars.config, vars.custom)
				fademusic()
			end)
			menu:addMenuItem(text('goback'), function()
				scenemanager:transitionscene(title, false, vars.config.name)
			end)
		end
	end

	assets = {
		stars_small = gfx.image.new('images/stars_small'),
		stars_large = gfx.image.new('images/stars_large'),
		full_circle = gfx.font.new('fonts/full-circle'),
		half_circle = gfx.font.new('fonts/full-circle-halved'),
		grid = pd.ui.gridview.new(200, 125),
		sfx_move = smp.new('audio/sfx/swap'),
		sfx_select = smp.new('audio/sfx/select'),
		sfx_back = smp.new('audio/sfx/back'),
		sfx_bonk = smp.new('audio/sfx/bonk'),
		check = gfx.image.new('images/check'),
	}

	vars = {
		config = args[1],
		custom = args[2],
		custom_files = {},
		custom_total = 0,
		anim_stars_small_x = pd.timer.new(4000, 0, -399),
		anim_stars_small_y = pd.timer.new(2750, 0, -239),
		anim_stars_large_x = pd.timer.new(2500, 0, -399),
		anim_stars_large_y = pd.timer.new(1250, 0, -239),
	}

	vars.progress = save[vars.config.save_progress_to]
	vars.mission_bests = save[vars.config.name .. '_' .. vars.config.save_score_to]
	vars.missions_total = #(vars.config.missions or {})

	if type(vars.config.custom_missions_path) == 'string' then
		vars.custom_files = pd.file.listFiles(vars.config.custom_missions_path)
		vars.custom_total = #vars.custom_files
	end

	assets.grid:setNumberOfRows(1)
	assets.grid:setNumberOfColumns(vars.missions_total)
	assets.grid:setCellPadding(5, 5, 0, 0)
	assets.grid:setSelection(1, 1, math.min((((save.highest_mission > vars.missions_total) and 1) or (save.highest_mission)), vars.missions_total))
	assets.grid:scrollCellToCenter(1, 1, math.min((((save.highest_mission > vars.missions_total) and 1) or (save.highest_mission)), vars.missions_total), false)

	vars.missionsHandlers = {
		leftButtonDown = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
			vars.keytimer = pd.timer.keyRepeatTimerWithDelay(150, 75, function()
				if vars.custom and vars.custom_total > 0 then
					if assets.custom_grid.selectedColumn == 1 then
						playsound(assets.sfx_bonk)
						shakies()
					else
						playsound(assets.sfx_move)
						assets.custom_grid:selectPreviousColumn(false)
					end
				elseif not vars.custom then
					if assets.grid.selectedColumn == 1 then
						playsound(assets.sfx_bonk)
						shakies()
					else
						playsound(assets.sfx_move)
						assets.grid:selectPreviousColumn(false)
					end
				end
			end)
		end,

		leftButtonUp = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
		end,

		rightButtonDown = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
			vars.keytimer = pd.timer.keyRepeatTimerWithDelay(150, 75, function()
				if vars.custom and vars.custom_total > 0 then
					if assets.custom_grid.selectedColumn == vars.custom_total then
						playsound(assets.sfx_bonk)
						shakies()
					else
						playsound(assets.sfx_move)
						assets.custom_grid:selectNextColumn(false)
					end
				elseif not vars.custom then
					if assets.grid.selectedColumn == vars.missions_total then
						playsound(assets.sfx_bonk)
						shakies()
					else
						playsound(assets.sfx_move)
						assets.grid:selectNextColumn(false)
					end
				end
			end)
		end,

		rightButtonUp = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
		end,

		upButtonDown = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
			playsound(assets.sfx_move)
			vars.custom = not vars.custom
		end,

		downButtonDown = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
			playsound(assets.sfx_move)
			vars.custom = not vars.custom
		end,

		BButtonDown = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
			playsound(assets.sfx_back)
			scenemanager:transitionscene(title, false, vars.config.name)
		end,

		AButtonDown = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end

			local mission_variation = nil
			local mission = nil

			if vars.custom then
				mission_variation = vars.custom_missions[assets.custom_grid.selectedColumn].type or nil

				mission = {
					author = vars.custom_missions[assets.custom_grid.selectedColumn].author or nil,
					index = vars.custom_missions[assets.custom_grid.selectedColumn].mission,
					modifier = vars.custom_missions[assets.custom_grid.selectedColumn].modifier or nil,
					start = vars.custom_missions[assets.custom_grid.selectedColumn].start or nil,
					goal = vars.custom_missions[assets.custom_grid.selectedColumn].goal or nil,
					seed = vars.custom_missions[assets.custom_grid.selectedColumn].seed or nil,
					name = vars.custom_missions[assets.custom_grid.selectedColumn].name or nil,
					is_custom = true,
				}
			elseif assets.grid.selectedColumn <= save.highest_mission then
				mission_variation = vars.config.missions[assets.grid.selectedColumn].type or nil

				mission = {
					author = nil,
					index = assets.grid.selectedColumn,
					modifier = vars.config.missions[assets.grid.selectedColumn].modifier or nil,
					start = vars.config.missions[assets.grid.selectedColumn].start,
					goal = vars.config.missions[assets.grid.selectedColumn].goal,
					seed = nil,
					name = vars.config.missions[assets.grid.selectedColumn].name,
					is_custom = false,
				}
			end

			if mission_variation ~= nil and mission ~= nil then
				playsound(assets.sfx_select)
				scenemanager:transitionscene(game, vars.config.name, mission_variation, mission)
				fademusic()
			else
				playsound(assets.sfx_bonk)
				shakies()
			end
		end,
	}
	pd.timer.performAfterDelay(scenemanager.transitiontime, function()
		pd.inputHandlers.push(vars.missionsHandlers)
	end)

	vars.anim_stars_small_x.repeats = true
	vars.anim_stars_small_y.repeats = true
	vars.anim_stars_large_x.repeats = true
	vars.anim_stars_large_y.repeats = true

	function assets.grid:drawCell(section, row, column, selected, x, y, width, height)
		gfx.setColor(gfx.kColorWhite)
		gfx.fillRect(x, y, width, height)
		gfx.setColor(gfx.kColorBlack)
		gfx.drawRect(x, y, width, height)

		if selected then
			gfx.setDitherPattern(0.75, gfx.image.kDitherTypeBayer2x2)
			gfx.fillPolygon(x, y, x + width, y, x + width, y + height, x + width - (width * 0.2), y + height, x + width - (width * 0.05), y + (height / 2), x + width - (width * 0.2), y, x + width * 0.2, y, x + width * 0.05, y + (height / 2), x + width * 0.2, y + height, x, y + height, x, y)
			gfx.setColor(gfx.kColorBlack)
		end

		if column > save.highest_mission then
			assets.half_circle:drawTextAligned(
				'🔒 ' .. text('mission_label') .. column,
				x + (width / 2),
				y + 8,
				kTextAlignment.center
			)

			assets.half_circle:drawTextAligned(
				text('mission_locked'),
				x + (width / 2),
				y + (height / 3),
				kTextAlignment.center
			)
		else
			assets.full_circle:drawTextAligned(
				text('mission_label') .. column,
				x + (width / 2),
				y + 8,
				kTextAlignment.center
			)

			if vars.config.missions[column].type == "picture" then
				assets.full_circle:drawTextAligned(
					text('mission_picture1') .. vars.config.missions[column].name .. text('mission_picture2'),
					x + (width / 2),
					y + (height / 3.7),
					kTextAlignment.center
				)
			elseif vars.config.missions[column].type == "logic" or vars.config.missions[column].type == "speedrun" then
				assets.full_circle:drawTextAligned(
					text('mission_' .. vars.config.missions[column].type .. '_' .. vars.config.missions[column].modifier),
					x + (width / 2),
					y + (height / 3.7),
					kTextAlignment.center
				)
			else
				assets.full_circle:drawTextAligned(
					text('mission_' .. vars.config.missions[column].type),
					x + (width / 2),
					y + (height / 3.7),
					kTextAlignment.center
				)
			end

			if vars.config.missions[column].type == "picture" or vars.config.missions[column].type == "logic" then
				assets.full_circle:drawTextAligned(
					text('swaps') .. text('divvy') .. commalize(vars.mission_bests['mission' .. column] or 0),
					x + (width / 2),
					y + (height - 22),
					kTextAlignment.center
				)
			elseif vars.config.missions[column].type == "time" then
				assets.full_circle:drawTextAligned(
					text('score') .. text('divvy') .. commalize(vars.mission_bests['mission' .. column] or 0),
					x + (width / 2),
					y + (height - 22),
					kTextAlignment.center
				)
			elseif vars.config.missions[column].type == "speedrun" then
				local mins, secs, mils = timecalc(vars.mission_bests['mission' .. column])
				assets.full_circle:drawTextAligned(
					text('time') .. text('divvy') .. mins .. ':' .. secs .. '.' .. mils,
					x + (width / 2),
					y + (height - 22),
					kTextAlignment.center
				)
			end
		end

		if save.highest_mission > column then
			assets.check:draw(x + width - 45, y + height - 50)
		end
	end

	if vars.custom_total > 0 then
		vars.custom_missions = {}
		for i = 1, vars.custom_total do
			if not string.find(vars.custom_files[i], '.json') then
				table.remove(vars.custom_files, i)
			end
		end
		for i = 1, vars.custom_total do
			if vars.mission_bests['mission' .. string.gsub(tostring(vars.custom_files[i]), ".json", "")] == nil then
				vars.mission_bests['mission' .. string.gsub(tostring(vars.custom_files[i]), ".json", "")] = 0
			end
			vars.custom_missions[i] = pd.datastore.read('missions/' .. string.gsub(tostring(vars.custom_files[i]), ".json", ""))
			if vars.custom_missions[i].type == 'time' then
			elseif vars.custom_missions[i].type == 'speedrun' then
			elseif vars.custom_missions[i].type == 'picture' then
				if vars.custom_missions[i].start_point ~= nil then
					vars.custom_missions[i].start = {}
					for n = 1, 19 do
						table.insert(vars.custom_missions[i].start, vars.custom_missions[i].start_point['tri' .. n])
					end
					vars.custom_missions[i].start_point = nil
				end
				if vars.custom_missions[i].goal_point ~= nil then
					vars.custom_missions[i].goal = {}
					for n = 1, 19 do
						table.insert(vars.custom_missions[i].goal, vars.custom_missions[i].goal_point['tri' .. n])
					end
					vars.custom_missions[i].goal_point = nil
				end
			elseif vars.custom_missions[i].type == 'logic' then
			end
		end

		assets.custom_grid = pd.ui.gridview.new(200, 125)
		assets.custom_grid:setNumberOfRows(1)
		assets.custom_grid:setNumberOfColumns(vars.custom_total)
		assets.custom_grid:setCellPadding(5, 5, 0, 0)
		assets.custom_grid:setSelection(1, 1, 1)
		assets.custom_grid:scrollCellToCenter(1, 1, 1, false)

		function assets.custom_grid:drawCell(section, row, column, selected, x, y, width, height)
			gfx.setColor(gfx.kColorWhite)
			gfx.fillRect(x, y, width, height)
			gfx.setColor(gfx.kColorBlack)
			gfx.drawRect(x, y, width, height)
			if selected then
				gfx.setDitherPattern(0.75, gfx.image.kDitherTypeBayer2x2)
				gfx.fillPolygon(x, y, x + width, y, x + width, y + height, x + width - (width * 0.2), y + height, x + width - (width * 0.05), y + (height / 2), x + width - (width * 0.2), y, x + width * 0.2, y, x + width * 0.05, y + (height / 2), x + width * 0.2, y + height, x, y + height, x, y)
				gfx.setColor(gfx.kColorBlack)
			end
			assets.full_circle:drawTextAligned(text('mission_by') .. vars.custom_missions[column].author, x + (width / 2), y + 8, kTextAlignment.center)
			if vars.custom_missions[column].type == "picture" then
				assets.full_circle:drawTextAligned(text('mission_picture1') .. vars.custom_missions[column].name .. text('mission_picture2'), x + (width / 2), y + (height / 3.7), kTextAlignment.center)
			elseif vars.custom_missions[column].type == "logic" or vars.custom_missions[column].type == "speedrun" then
				assets.full_circle:drawTextAligned(text('mission_' .. vars.custom_missions[column].type .. '_' .. vars.custom_missions[column].modifier), x + (width / 2), y + (height / 3.7), kTextAlignment.center)
			else
				assets.full_circle:drawTextAligned(text('mission_' .. vars.custom_missions[column].type), x + (width / 2), y + (height / 3.7), kTextAlignment.center)
			end
			if vars.custom_missions[column].type == "picture" or vars.custom_missions[column].type == "logic" then
				assets.full_circle:drawTextAligned(text('swaps') .. text('divvy') .. commalize(vars.mission_bests['mission' .. vars.custom_missions[column].mission]), x + (width / 2), y + (height - 22), kTextAlignment.center)
			elseif vars.custom_missions[column].type == "time" then
				assets.full_circle:drawTextAligned(text('score') .. text('divvy') .. commalize(vars.mission_bests['mission' .. vars.custom_missions[column].mission]), x + (width / 2), y + (height - 22), kTextAlignment.center)
			elseif vars.custom_missions[column].type == "speedrun" then
				local mins, secs, mils = timecalc(vars.mission_bests['mission' .. vars.custom_missions[column].mission])
				assets.full_circle:drawTextAligned(text('time') .. text('divvy') .. mins .. ':' .. secs .. '.' .. mils, x + (width / 2), y + (height - 22), kTextAlignment.center)
			end
		end
	end

	gfx.sprite.setBackgroundDrawingCallback(function(x, y, width, height)
		assets.stars_small:draw(vars.anim_stars_small_x.value, vars.anim_stars_small_y.value)
		assets.stars_large:draw(vars.anim_stars_large_x.value, vars.anim_stars_large_y.value)
		if (vars.custom and vars.custom_total > 0) or (not vars.custom) then
			gfx.setColor(gfx.kColorWhite)
			gfx.setDitherPattern(0.75, gfx.image.kDitherTypeBayer2x2)
			gfx.fillRect(0, 40, 400, 145)
			gfx.setColor(gfx.kColorBlack)
		else
			gfx.setDitherPattern(0.25, gfx.image.kDitherTypeBayer2x2)
			gfx.fillRect(0, 40, 400, 145)
		end
		if vars.custom then
			if vars.custom_total > 0 then
				assets.custom_grid:drawInRect(0,50, 400, 125)
			else
				gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
				assets.full_circle:drawTextAligned(text('nocustommissions_1'), 200, 70, kTextAlignment.center)
				assets.full_circle:drawTextAligned(text('nocustommissions_2'), 200, 85, kTextAlignment.center)
				assets.half_circle:drawTextAligned(text('nocustommissions_3'), 200, 120, kTextAlignment.center)
				assets.half_circle:drawTextAligned(text('nocustommissions_4'), 200, 135, kTextAlignment.center)
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
			end
		else
			assets.grid:drawInRect(0,50, 400, 125)
		end
		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
		--assets.half_circle:drawText(text('menucustom'), 10, 205)
		assets.half_circle:drawText(text('move') .. ' ' .. text('select') .. ' ' .. text('back'), 10, 220)
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
	end)

	self:add()
	newmusic('title', true)
end

function missions:update()
	local ticks = pd.getCrankTicks(6)
	if ticks ~= 0 and #pd.inputHandlers > 1 then
		if vars.custom then
			if ticks > 0 then
				if assets.custom_grid.selectedColumn == vars.custom_total then
					playsound(assets.sfx_bonk)
					shakies()
				else
					playsound(assets.sfx_move)
					assets.custom_grid:selectNextColumn(false)
				end
			elseif ticks < 0 then
				if assets.custom_grid.selectedColumn == 1 then
					playsound(assets.sfx_bonk)
					shakies()
				else
					playsound(assets.sfx_move)
					assets.custom_grid:selectPreviousColumn(false)
				end
			end
		else
			if ticks > 0 then
				if assets.grid.selectedColumn == vars.missions_total then
					playsound(assets.sfx_bonk)
					shakies()
				else
					playsound(assets.sfx_move)
					assets.grid:selectNextColumn(false)
				end
			elseif ticks < 0 then
				if assets.grid.selectedColumn == 1 then
					playsound(assets.sfx_bonk)
					shakies()
				else
					playsound(assets.sfx_move)
					assets.grid:selectPreviousColumn(false)
				end
			end
		end
	end
end
