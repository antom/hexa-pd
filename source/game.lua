import 'Tanuk_CodeSequence'

-- Setting up consts
local pd <const> = playdate
local gfx <const> = pd.graphics
local smp <const> = pd.sound.sampleplayer
local random <const> = math.random
local floor <const> = math.floor
local ceil <const> = math.ceil
local tris_x <const> = {140, 170, 200, 230, 260, 110, 140, 170, 200, 230, 260, 290, 110, 140, 170, 200, 230, 260, 290}
local tris_y <const> = {70, 70, 70, 70, 70, 120, 120, 120, 120, 120, 120, 120, 170, 170, 170, 170, 170, 170, 170}
local tris_flip <const> = {true, false, true, false, true, true, false, true, false, true, false, true, false, true, false, true, false, true, false}
local tris_modifiers <const> = {
	['black'] = {'color', 'black'},
	['gray'] = {'color', 'gray'},
	['white'] = {'color', 'white'},
	['2x'] = {'powerup', 'double'},
	['bomb'] = {'powerup', 'bomb'},
	['wild'] = {'powerup', 'wild'},
}
local text <const> = getLocalizedText
local min <const> = math.min
local exp <const> = math.exp
local flash_opts <const> = {pd.getReduceFlashing(), false, true}
local flash_int_opts <const> = {70, 100}
local initial_moves_bonus <const> = 5

class('game').extends(gfx.sprite) -- Create the scene's class
function game:init(...)
	game.super.init(self)
	local args = {...} -- Arguments passed in through the scene management will arrive here
	gfx.sprite.setAlwaysRedraw(true)

	function pd.gameWillPause() -- When the game's paused...
		local menu = pd.getSystemMenu()
		pauseimage(vars.game.name or nil)
		menu:removeAllMenuItems()
		if not scenemanager.transitioning then
			if vars.can_do_stuff then
				if vars.mission ~= nil then
					menu:addMenuItem(text('exitmission'), function()
						if vars.timer ~= nil then
							vars.timer:pause()
						end
						vars.can_do_stuff = false
						scenemanager:transitionscene(missions, game_mode_presets[vars.game.preset])
						fademusic()
					end)
				end

				if vars.game.menu_text_endgame or nil then
					menu:addMenuItem(text(vars.game.menu_text_endgame), function()
						self:endround()
					end)
				end

				if not vars.game.is_daily then
					menu:addMenuItem(text('restart'), function()
						self:restart()
					end)
				end
			end

			menu:addCheckmarkMenuItem(text('flip'), save.flip, function(value)
				save.flip = value
			end)
		end
	end

	assets = {
		cursor = gfx.imagetable.new('images/cursor'),
		full_circle = gfx.font.new('fonts/full-circle'),
		half_circle = gfx.font.new('fonts/full-circle-halved'),
		clock = gfx.font.new('fonts/clock'),
		hexa = gfx.imagetable.new('images/hexa_' .. tostring(flash_opts[save.flashing])),
		sfx_move = smp.new('audio/sfx/move'),
		sfx_bonk = smp.new('audio/sfx/bonk'),
		sfx_swap = smp.new('audio/sfx/swap'),
		sfx_hexa = smp.new('audio/sfx/hexa'),
		sfx_vine = smp.new('audio/sfx/vine'),
		sfx_boom = smp.new('audio/sfx/boom'),
		sfx_select = smp.new('audio/sfx/select'),
		sfx_count = smp.new('audio/sfx/count'),
		sfx_start = smp.new('audio/sfx/start'),
		sfx_end = smp.new('audio/sfx/end'),
		sfx_hexaprep = smp.new('audio/sfx/hexaprep'),
		sfx_mission = smp.new('audio/sfx/mission'),
		powerup_double_up = gfx.imagetable.new('images/powerup_double_up'),
		powerup_double_down = gfx.imagetable.new('images/powerup_double_down'),
		powerup_bomb_up = gfx.imagetable.new('images/powerup_bomb_up'),
		powerup_bomb_down = gfx.imagetable.new('images/powerup_bomb_down'),
		powerup_wild_up = gfx.imagetable.new('images/powerup_wild_up'),
		powerup_wild_down = gfx.imagetable.new('images/powerup_wild_down'),
		label_3 = gfx.image.new('images/label_3'),
		label_2 = gfx.image.new('images/label_2'),
		label_1 = gfx.image.new('images/label_1'),
		label_go = gfx.image.new('images/label_go_' .. tostring(save.lang)),
		label_double = gfx.image.new('images/label_double_' .. tostring(save.lang)),
		label_bomb = gfx.image.new('images/label_bomb_' .. tostring(save.lang)),
		label_wild = gfx.image.new('images/label_wild'),
		modal = gfx.image.new('images/modal'),
		bg_tile = gfx.image.new('images/bg_tile'),
		stars = gfx.image.new('images/stars_large'),
		half = gfx.image.new('images/half'),
		mission_complete = gfx.image.new('images/mission_complete_' .. tostring(save.lang)),
	}

	vars = {
		mode = args[1], -- should match game_mode_presets[x].name
		variation = args[2], -- should match game_mode_presets[x].variations[y].name (if set)
		mission = args[3], -- should be similar to game_mode_presets[x].missions[y][z] (if set)
		tris = {},
		crank_deadzone = 0,
		crank_change = 0,
		crank_degrees = 0,
		anim_hexa = pd.timer.new(1, 11, 11),
		anim_cursor_x = pd.timer.new(1, 106, 106),
		anim_cursor_y = pd.timer.new(1, 42, 42),
		anim_cursor = pd.timer.new(0, 1, 1),
		anim_label = pd.timer.new(0, 400, 400),
		anim_modal = pd.timer.new(0, 400, 400),
		anim_bg_stars_x = pd.timer.new(10000, 0, -399),
		anim_bg_stars_y = pd.timer.new(15000, 0, -239),
		anim_powerup = pd.timer.new(700, 1, 4.99),
		lastdir = false,
		flash = flash_opts[save.flashing],
		flash_int = flash_int_opts[save.flash_int],
	}

	vars.gameHandlers = {
		leftButtonDown = function()
			if not vars.can_do_stuff then return end

			vars.lastdir = false
			if vars.slot == 2 then
				vars.slot = 1
				vars.anim_cursor_x:resetnew(80, vars.anim_cursor_x.value, 106, pd.easingFunctions.outBack)
				vars.anim_cursor_y:resetnew(80, vars.anim_cursor_y.value, 42, pd.easingFunctions.outBack)
				playsound(assets.sfx_move)
			elseif vars.slot == 5 then
				vars.slot = 4
				vars.anim_cursor_x:resetnew(80, vars.anim_cursor_x.value, 137, pd.easingFunctions.outBack)
				vars.anim_cursor_y:resetnew(80, vars.anim_cursor_y.value, 92, pd.easingFunctions.outBack)
				playsound(assets.sfx_move)
			elseif vars.slot == 4 then
				vars.slot = 3
				vars.anim_cursor_x:resetnew(80, vars.anim_cursor_x.value, 78, pd.easingFunctions.outBack)
				vars.anim_cursor_y:resetnew(80, vars.anim_cursor_y.value, 92, pd.easingFunctions.outBack)
				playsound(assets.sfx_move)
			else
				playsound(assets.sfx_bonk)
			end
		end,

		rightButtonDown = function()
			if not vars.can_do_stuff then return end

			vars.lastdir = true
			if vars.slot == 1 then
				vars.slot = 2
				vars.anim_cursor_x:resetnew(80, vars.anim_cursor_x.value, 166, pd.easingFunctions.outBack)
				vars.anim_cursor_y:resetnew(80, vars.anim_cursor_y.value, 42, pd.easingFunctions.outBack)
				playsound(assets.sfx_move)
			elseif vars.slot == 3 then
				vars.slot = 4
				vars.anim_cursor_x:resetnew(80, vars.anim_cursor_x.value, 137, pd.easingFunctions.outBack)
				vars.anim_cursor_y:resetnew(80, vars.anim_cursor_y.value, 92, pd.easingFunctions.outBack)
				playsound(assets.sfx_move)
			elseif vars.slot == 4 then
				vars.slot = 5
				vars.anim_cursor_x:resetnew(80, vars.anim_cursor_x.value, 197, pd.easingFunctions.outBack)
				vars.anim_cursor_y:resetnew(80, vars.anim_cursor_y.value, 92, pd.easingFunctions.outBack)
				playsound(assets.sfx_move)
			else
				playsound(assets.sfx_bonk)
			end
		end,

		upButtonDown = function()
			if not vars.can_do_stuff then return end

			if vars.slot == 3 or vars.slot == 4 or vars.slot == 5 then
				if vars.lastdir then
					vars.slot = 2
					vars.anim_cursor_x:resetnew(80, vars.anim_cursor_x.value, 166, pd.easingFunctions.outBack)
					vars.anim_cursor_y:resetnew(80, vars.anim_cursor_y.value, 42, pd.easingFunctions.outBack)
					playsound(assets.sfx_move)
				else
					vars.slot = 1
					vars.anim_cursor_x:resetnew(80, vars.anim_cursor_x.value, 106, pd.easingFunctions.outBack)
					vars.anim_cursor_y:resetnew(80, vars.anim_cursor_y.value, 42, pd.easingFunctions.outBack)
					playsound(assets.sfx_move)
				end
			else
				playsound(assets.sfx_bonk)
			end
		end,

		downButtonDown = function()
			if not vars.can_do_stuff then return end

			if vars.slot == 1 then
				vars.slot = 3
				vars.anim_cursor_x:resetnew(80, vars.anim_cursor_x.value, 78, pd.easingFunctions.outBack)
				vars.anim_cursor_y:resetnew(80, vars.anim_cursor_y.value, 92, pd.easingFunctions.outBack)
				playsound(assets.sfx_move)
			elseif vars.slot == 2 then
				vars.slot = 5
				vars.anim_cursor_x:resetnew(80, vars.anim_cursor_x.value, 197, pd.easingFunctions.outBack)
				vars.anim_cursor_y:resetnew(80, vars.anim_cursor_y.value, 92, pd.easingFunctions.outBack)
				playsound(assets.sfx_move)
			else
				playsound(assets.sfx_bonk)
			end
		end,

		AButtonDown = function()
			if not vars.can_do_stuff then return end

			self:swap(vars.slot, not save.flip)
		end,

		BButtonDown = function()
			if not vars.can_do_stuff then return end

			self:swap(vars.slot, save.flip)
		end,
	}

	vars.losingHandlers = {
		AButtonDown = function()
			if vars.ended and not vars.skippedfanfare then
				self:ersi()
			end
		end,

		BButtonDown = function()
			if vars.ended and not vars.skippedfanfare then
				self:ersi()
			end
		end
	}

	vars.loseHandlers = {
		AButtonDown = function()
			if (vars.game.text_endgame_button_a or 'newgame') == 'showsdailyscores' then
				if catalog then
					fademusic()
					scenemanager:transitionscene(highscores, vars.mode)
				end
			else
				fademusic()
				scenemanager:transitionscene(game, vars.mode, vars.variation, vars.mission)
			end
		end,

		BButtonDown = function()
			fademusic()
			scenemanager:transitionscene(title, false, vars.mode)
		end
	}

	game:reset()

	pd.timer.performAfterDelay(scenemanager.transitiontime, function()
		pd.inputHandlers.push(vars.gameHandlers)
	end)

	assets.bg = gfx.image.new('images/' .. vars.game.bg)


	if vars.game.has_bg_tile then
		if vars.flash then
			vars.anim_bg_tile_x = pd.timer.new(1, 0, 0)
			vars.anim_bg_tile_y = pd.timer.new(1, 0, 0)
		else
			vars.anim_bg_tile_x = pd.timer.new(30000, 0, -399)
			vars.anim_bg_tile_y = pd.timer.new(28000, 0, -239)
		end

		vars.anim_bg_tile_x.repeats = true
		vars.anim_bg_tile_y.repeats = true
	end

	if vars.game.zen or false then
		achievements.grant('chill')
	end

	vars.anim_cursor_x.discardOnCompletion = false
	vars.anim_cursor_y.discardOnCompletion = false
	vars.anim_label.discardOnCompletion = false
	vars.anim_modal.discardOnCompletion = false
	vars.anim_hexa.discardOnCompletion = false
	vars.anim_powerup.repeats = true
	vars.anim_bg_stars_x.repeats = true
	vars.anim_bg_stars_y.repeats = true
	vars.anim_cursor.discardOnCompletion = false

	assets.ui = gfx.image.new('images/' .. ((vars.game.timer and 'ui_arcade') or 'ui_zen'))

	if vars.game.scoreboard or false then
		save.lbs_lastmode = vars.mode
	end

	if vars.game.timer or false then
		vars.timer = pd.timer.new(vars.game.timer, vars.game.timer, 0)
		vars.timer.delay = 4000
		vars.old_timer_value = vars.game.timer
		vars.timer.timerEndedCallback = function()
			self:endround()
		end
	end

	if vars.game.goal ~= nil then
		vars.anim_cursor_y:resetnew(1, 420, 420)
	end

	if vars.game.has_countdown then
		game:countdown()
	else
		pd.timer.performAfterDelay(1000, function()
			if vars.game.music ~= nil  then
				newmusic(vars.game.music, true)
			end

			vars.can_do_stuff = true
			self:check()
		end)
	end

	class('game_canvas', _, classes).extends(gfx.sprite)
	function classes.game_canvas:init()
		classes.game_canvas.super.init(self)
		self:setCenter(0, 0)
		self:setSize(400, 240)
		self:setOpaque(true)
		self:add()
	end
	function classes.game_canvas:draw()
		assets.bg:draw(0, 0)
		if vars.game.has_bg_tile then
			assets.bg_tile:draw((floor(vars.anim_bg_tile_x.value / 2) * 2) - 1, (floor(vars.anim_bg_tile_y.value / 2) * 2) - 1)
		end
		assets.stars:draw(vars.anim_bg_stars_x.value, vars.anim_bg_stars_y.value)
		if assets.draw_label ~= nil then assets.draw_label:draw(vars.anim_label.value, -13) end
		assets.ui:draw(0, 0)
		for i = 1, 19 do
			game:tri(tris_x[i], tris_y[i], tris_flip[i], vars.tris[i].color, vars.tris[i].powerup)
		end
		local cursor = floor(vars.anim_cursor.value) or 1
		assets.cursor[cursor]:draw(vars.anim_cursor_x.value - (2 * (cursor - 1)), vars.anim_cursor_y.value - (3 * (cursor - 1)))
		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)

		if vars.game.statuses ~= nil then
			local statuses = deepcopy(vars.game.statuses)
			local status_offset_y = 10

			for i = 1, #statuses do
				local status_type = type(statuses[i])

				if status_type == 'string' then
					statuses[i] = game:status(statuses[i])
				elseif status_type == 'function' then
					statuses[i] = statuses[i]()
				end

				if statuses[i].label ~= nil then
					assets.half_circle:drawText(vars.game.lang[statuses[i].label] or statuses[i].label, 10, status_offset_y)
				end

				if statuses[i].value ~= nil then
					assets.full_circle:drawText(statuses[i].value, 10, status_offset_y + 15)
				end

				status_offset_y += 35
			end
		end

		if vars.timer ~= nil then
			assets.clock:drawText(ceil(vars.timer.value / 1000), 305, 55)
		end

		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		assets.hexa[floor(vars.anim_hexa.value)]:draw(0, 0)

		if not vars.can_do_stuff then
			assets.half:draw(0, 0)
		end

		if vars.missioncomplete then
			assets.mission_complete:draw(0, 0)
		end

		assets.modal:draw(0, vars.anim_modal.value)
	end

	sprites.canvas = classes.game_canvas()
	sprites.code = Tanuk_CodeSequence({pd.kButtonRight, pd.kButtonUp, pd.kButtonB, pd.kButtonDown, pd.kButtonUp, pd.kButtonB, pd.kButtonDown, pd.kButtonUp, pd.kButtonB}, function() self:boom(true) end, true)
	self:add()
	pd.datastore.write(save)
end

function game:setup(mode, variation, mission)
	variation = variation or 'default'
	mission = mission or nil

	local values = {}

	for i = 1, #game_mode_presets do
		if game_mode_presets[i].name == mode then
			for key, value in pairs(game_mode_presets[i]) do
				if key ~= 'missions' then
					values[key] = deepcopy(value)
				end
			end

			values.preset = i
		end
	end

	if next(values) == nil then
		error('HEXA cannot be played in "' .. mode .. '" mode :(')
	end

	-- set up a game mode variation if defined
	if type(values.variations) == 'table' then
		for i = 1, #values.variations do
			if values.variations[i].name == variation then
				for key, value in pairs(values.variations[i]) do
					if key == 'name' then
						values.variation = value
					else
						values[key] = value
					end
				end
			end
		end

		if values.variation == nil then
			error('Unable to set up the "' .. variation .. '" variation for the "' .. mode .. '" mode of play :(')
		end

		values.variations = nil
	end

	-- set up a game mode mission if defined
	if mission ~= nil then
		-- create a copy so changes are only done locally so the mission argument can be re-used.
		local mission = deepcopy(mission)

		-- move certain valid keys to the game mode
		local valid_keys = {
			'modifier', -- modifier for whatever, depending on the mission
			'start',    -- starting layout
			'goal',     -- finishing layout, for picture mode
			'seed',     -- number seed, for time attack
		}

		for i = 1, #valid_keys do
			local valid_key = valid_keys[i]

			if mission[valid_key] ~= nil then
				values[valid_key] = mission[valid_key]
				mission[valid_key] = nil
			end
		end

		if values.modifier_target ~= nil then
			local valid_modifier_targets = {
				'timer',
			}

			for i = 1, #valid_modifier_targets do
				if valid_modifier_targets[i] == values.modifier_target then
					values[values.modifier_target] = values.modifier
				end
			end

			values.modifier =  nil
			values.modifier_target = nil
		end

		mission.best = save[mode .. '_' .. values.save_score_to]['mission' .. mission.index]

		values.mission = mission
	end

	-- set up default values
	setmetatable(values, {
		__index = {
			type = mode,
			vars = {},
			can_go_boom = true,
			has_bg_tile = true,
			has_powerups = true,
			has_countdown = true,
			has_stopwatch = false,
			is_daily = false,
			bg = 'bg_zen',
			music_playlist = 'arcade',
			timer_max = 60000,
		}
	})

	-- if the timer value is specified in seconds, convert it to milliseconds
	if values.timer ~= nil and values.timer < 1000 then
		values.timer = values.timer * 1000
	end

	-- filter the music playlist
	local playlist_filter = '^' .. (values.music_playlist or values.type or vars.mode) .. '%d+$'
	local playlist = {}

	for i = 1, #tunes do
		if string.match(tunes[i], playlist_filter) then
			table.insert(playlist, tunes[i])
		end
	end

	-- pick a tune at random
	values.music = playlist[math.random(1, #playlist)]

	-- set the game mode language to the current language setting (or empty if not set)
	if values.lang ~= nil and values.lang[save.lang] ~= nil then
		values.lang = values.lang[save.lang]
	else
		values.lang = {}
	end

	-- pre-pick a random message for the fanfare
	if values.lang['fanfare_messages'] then
		values.fanfare_message = values.lang['fanfare_messages'][random(1, #values.lang['fanfare_messages'])]
	elseif type(values.based_on) == 'string' then
		values.fanfare_message = text(values.based_on .. '_message' .. random(1, 10))
	else
		values.fanfare_message = text(mode .. '_message' .. random(1, 10))
	end

	return values
end

function game:status(handle)
	if handle == 'score' then
		return {
			label = text('score'),
			value = commalize(vars.score),
		}

	elseif handle == 'high-score' then
		return {
			label = text('high'),
			value = commalize((vars.score > (save[vars.game.save_score_to] or 0) and vars.score) or (save[vars.game.save_score_to] or 0)),
		}

	elseif handle == 'moves' or handle == 'swaps' then
		return {
			label = text('swaps'),
			value = commalize(vars.moves),
		}

	elseif handle == 'hexas' then
		return {
			label = text('hexas'),
			value = commalize(vars.hexas),
		}

	elseif handle == 'time' then
		local mins, secs, mils = timecalc(vars.time)

		return {
			label = text('time'),
			value = mins .. ':' .. secs .. '.' .. mils
		}

	elseif handle == 'mission-high-score' then
		return {
			label = text('high'),
			value = commalize((vars.score > vars.game.mission.best and vars.score) or vars.game.mission.best)
		}

	elseif handle == 'mission-best' then
		return {
			label = text('best'),
			value = commalize(vars.game.mission.best),
		}

	elseif handle == 'mission-best-time' then
		local bestmins, bestsecs, bestmils = timecalc(vars.game.mission.best)

		return {
			label = text('best'),
			value = bestmins .. ':' .. bestsecs .. '.' .. bestmils
		}

	elseif handle == 'seed' then
		return {
			label = text('seed'),
			value = vars.seed,
		}

	elseif handle == 'hardmodeg' then
		return {
			label = (save.hardmode and text('hardmodeg')) or '',
		}
	end

	return nil
end

function game:seed()
	local seed = vars.game.seed or nil

	if seed == 'daily' then
		return pd.getGMTTime().year .. pd.getGMTTime().month .. pd.getGMTTime().day
	elseif seed == 'timed' then
		if vars.seed ~= nil and vars.seed ~= 0 then
			return vars.seed
		elseif vars.mission ~= nil and vars.mission.index ~= nil then
			return 123459 * vars.mission.index
		end
	end

	return playdate.getSecondsSinceEpoch()
end

function game:countdown()
	vars.countdown_timers = {
		-- 3
		pd.timer.performAfterDelay(1000, function()
			playsound(assets.sfx_count)
			assets.draw_label = assets.label_3
			vars.anim_label:resetnew(1000, 350, -200, pd.easingFunctions.linear)
		end),

		-- 2
		pd.timer.performAfterDelay(2000, function()
			playsound(assets.sfx_count)
			assets.draw_label = assets.label_2
			vars.anim_label:resetnew(1000, 350, -200, pd.easingFunctions.linear)
		end),

		-- 1
		pd.timer.performAfterDelay(3000, function()
			playsound(assets.sfx_count)
			assets.draw_label = assets.label_1
			vars.anim_label:resetnew(1000, 350, -200, pd.easingFunctions.linear)
		end),

		-- go!
		pd.timer.performAfterDelay(4000, function()
			playsound(assets.sfx_start)

			assets.draw_label = assets.label_go
			vars.anim_label:resetnew(1000, 400, -200, pd.easingFunctions.linear)
			vars.anim_label.timerEndedCallback = function()
				assets.draw_label = nil
			end

			if vars.timer ~= nil then
				vars.timer.delay = 0
				vars.timer:start()
			end

			if vars.game.start ~= nil then
				vars.tris = deepcopy(vars.game.start)
			end

			if vars.game.music ~= nil  then
				newmusic(vars.game.music, true)
			end

			vars.anim_cursor_y:resetnew(1, 42, 42)

			vars.can_do_stuff = true
			self:check()
		end),
	}
end

function game:tri(x, y, up, color, powerup)
	if color == "white" or color == "gray" then
		gfx.setColor(gfx.kColorWhite)
	end

	if color ~= "none" then
		if up then
			gfx.fillTriangle(x, y - 25, x + 30, y + 25, x - 30, y + 25)
		else
			gfx.fillTriangle(x, y + 25, x + 30, y - 25, x - 30, y - 25)
		end
		if color == "gray" then
			gfx.setColor(gfx.kColorBlack)
			gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer4x4)
			if up then
				gfx.fillTriangle(x, y - 25, x + 30, y + 25, x - 30, y + 25)
			else
				gfx.fillTriangle(x, y + 25, x + 30, y - 25, x - 30, y - 25)
			end
		end
		gfx.setColor(gfx.kColorBlack)
		if up then
			gfx.drawTriangle(x, y - 25, x + 30, y + 25, x - 30, y + 25)
		else
			gfx.drawTriangle(x, y + 25, x + 30, y - 25, x - 30, y - 25)
		end
	else
		gfx.setDitherPattern(0.75, gfx.image.kDitherTypeBayer4x4)
		if up then
			gfx.fillTriangle(x, y - 25, x + 30, y + 25, x - 30, y + 25)
		else
			gfx.fillTriangle(x, y + 25, x + 30, y - 25, x - 30, y - 25)
		end
	end
	gfx.setColor(gfx.kColorBlack)
	if powerup ~= '' then
		assets['powerup_' .. powerup .. (up and '_up' or '_down')][math.max(1, math.min(vars.flash and 1 or floor(vars.anim_powerup.value), 4))]:draw(x - 28, y - 23)
	end
end

function game:swap(slot, dir)
	if not vars.active_hexa then
		vars.movesbonus -= 1
		if vars.movesbonus < 0 then vars.movesbonus = 0 end
		vars.anim_cursor:resetnew(75, 2.99, 1)
		vars.moves += 1
		save.swaps += 1
		playsound(assets.sfx_swap)
		local tochange
		temp1, temp2, temp3, temp4, temp5, temp6 = self:findslot(slot)
		if slot == 1 then
			tochange = {1, 2, 3, 7, 8, 9}
		elseif slot == 2 then
			tochange = {3, 4, 5, 9, 10, 11}
		elseif slot == 3 then
			tochange = {6, 7, 8, 13, 14, 15}
		elseif slot == 4 then
			tochange = {8, 9, 10, 15, 16, 17}
		elseif slot == 5 then
			tochange = {10, 11, 12, 17, 18, 19}
		end
		if dir then
			vars.tris[tochange[2]] = temp1
			vars.tris[tochange[3]] = temp2
			vars.tris[tochange[6]] = temp3
			vars.tris[tochange[1]] = temp4
			vars.tris[tochange[4]] = temp5
			vars.tris[tochange[5]] = temp6
		else
			vars.tris[tochange[4]] = temp1
			vars.tris[tochange[1]] = temp2
			vars.tris[tochange[2]] = temp3
			vars.tris[tochange[5]] = temp4
			vars.tris[tochange[6]] = temp5
			vars.tris[tochange[3]] = temp6
		end
		self:check()
	end
end

function game:check()
	if vars.game.goal ~= nil then
		local layout_goal_achieved = true

		for i = 1, 19 do
			local colorcheck1 = vars.tris[i].color
			local colorcheck2 = vars.game.goal[i].color
			if colorcheck1 ~= colorcheck2 then
				layout_goal_achieved = false
				return
			end
		end

		if layout_goal_achieved then
			self:endround()
		end

		return
	end

	if not vars.can_do_stuff then return end

	local temp1
	local temp2
	local temp3
	local temp4
	local temp5
	local temp6
	local bomb_temp1
	local bomb_temp2
	local bomb_temp3
	local bomb_temp4
	local bomb_temp5
	local bomb_temp6
	local bomb_imminent = false
	local color
	for i = 1, 5 do
		temp1, temp2, temp3, temp4, temp5, temp6 = self:findslot(i)
		for i = 1, 3 do
			if i == 1 then
				color = "white"
			elseif i == 2 then
				color = "black"
			elseif i == 3 then
				color = "gray"
			end
			if (temp1.color == color or temp1.powerup == "wild") and (temp2.color == color or temp2.powerup == "wild") and (temp3.color == color or temp3.powerup == "wild") and (temp4.color == color or temp4.powerup == "wild") and (temp5.color == color or temp5.powerup == "wild") and (temp6.color == color or temp6.powerup == "wild") then
				if temp1.powerup == "bomb" or temp2.powerup == "bomb" or temp3.powerup == "bomb" or temp4.powerup == "bomb" or temp5.powerup == "bomb" or temp6.powerup == "bomb" then
					bomb_temp1 = temp1
					bomb_temp2 = temp2
					bomb_temp3 = temp3
					bomb_temp4 = temp4
					bomb_temp5 = temp5
					bomb_temp6 = temp6
					bomb_imminent = true
				else
					self:hexa(temp1, temp2, temp3, temp4, temp5, temp6)
					return
				end
			end
		end
	end
	if bomb_imminent then
		self:hexa(bomb_temp1, bomb_temp2, bomb_temp3, bomb_temp4, bomb_temp5, bomb_temp6)
		return
	end
	if vars.combo > 0 then
		vars.combo = 0
	end
end

function game:colorflip(temp1, temp2, temp3, temp4, temp5, temp6, yes)
	if yes then
		if (temp1.color == "white" and temp1.powerup ~= "wild") or (temp2.color == "white" and temp2.powerup ~= "wild") or (temp3.color == "white" and temp3.powerup ~= "wild") or (temp4.color == "white" and temp4.powerup ~= "wild") or (temp5.color == "white" and temp5.powerup ~= "wild") or (temp6.color == "white" and temp6.powerup ~= "wild") then
			temp1.color = "gray"
			temp2.color = "gray"
			temp3.color = "gray"
			temp4.color = "gray"
			temp5.color = "gray"
			temp6.color = "gray"
		else
			temp1.color = "white"
			temp2.color = "white"
			temp3.color = "white"
			temp4.color = "white"
			temp5.color = "white"
			temp6.color = "white"
		end
	else
		temp1.color = vars.tempcolor1
		temp2.color = vars.tempcolor2
		temp3.color = vars.tempcolor3
		temp4.color = vars.tempcolor4
		temp5.color = vars.tempcolor5
		temp6.color = vars.tempcolor6
	end
end

function game:hexa(temp1, temp2, temp3, temp4, temp5, temp6)
	pd.inputHandlers.pop()
	vars.active_hexa = true
	vars.tempcolor1 = temp1.color
	vars.tempcolor2 = temp2.color
	vars.tempcolor3 = temp3.color
	vars.tempcolor4 = temp4.color
	vars.tempcolor5 = temp5.color
	vars.tempcolor6 = temp6.color
	assets.sfx_hexaprep:setRate(1 + (0.1 * vars.combo))
	playsound(assets.sfx_hexaprep)
	self:colorflip(temp1, temp2, temp3, temp4, temp5, temp6, true)
	pd.timer.performAfterDelay(vars.flash_int, function()
		if not vars.flash then
			self:colorflip(temp1, temp2, temp3, temp4, temp5, temp6, false)
		end
	end)
	pd.timer.performAfterDelay(vars.flash_int * 2, function()
		playsound(assets.sfx_hexaprep)
		self:colorflip(temp1, temp2, temp3, temp4, temp5, temp6, not vars.flash)
	end)
	pd.timer.performAfterDelay(vars.flash_int * 3, function()
		if not vars.flash then
			self:colorflip(temp1, temp2, temp3, temp4, temp5, temp6, false)
		end
	end)
	pd.timer.performAfterDelay(vars.flash_int * 4, function()
		if vars.can_do_stuff or (not vars.can_do_stuff and vars.ended) then
			vars.hexas += 1
			save.hexas += 1
			vars.combo += 1
			shakies()
			shakies_y()

			local multiplier = 1

			if temp1.powerup == 'wild' or temp2.powerup == 'wild' or temp3.powerup == 'wild' or temp4.powerup == 'wild' or temp5.powerup == 'wild' or temp6.powerup == 'wild' then
				save.wild_match += 1
			end

			if temp1.powerup == "double" or temp2.powerup == "double" or temp3.powerup == "double" or temp4.powerup == "double" or temp5.powerup == "double" or temp6.powerup == "double" then
				save.double_match += 1
				multiplier = 2

				playsound(assets.sfx_select)
				assets.draw_label = assets.label_double
				vars.anim_label:resetnew(1200, 400, -200, pd.easingFunctions.linear)
				vars.anim_label.timerEndedCallback = function()
					assets.draw_label = nil
				end
			end

			if (temp1.color == "white" and temp1.powerup ~= "wild") or (temp2.color == "white" and temp2.powerup ~= "wild") or (temp3.color == "white" and temp3.powerup ~= "wild") or (temp4.color == "white" and temp4.powerup ~= "wild") or (temp5.color == "white" and temp5.powerup ~= "wild") or (temp6.color == "white" and temp6.powerup ~= "wild") then
				vars.score += (100 * multiplier) * vars.combo
				save.total_score += (100 * multiplier) * vars.combo
				save.white_match += 1
			elseif (temp1.color == "gray" and temp1.powerup ~= "wild") or (temp2.color == "gray" and temp2.powerup ~= "wild") or (temp3.color == "gray" and temp3.powerup ~= "wild") or (temp4.color == "gray" and temp4.powerup ~= "wild") or (temp5.color == "gray" and temp5.powerup ~= "wild") or (temp6.color == "gray" and temp6.powerup ~= "wild") then
				vars.score += (150 * multiplier) * vars.combo
				save.total_score += (150 * multiplier) * vars.combo
				save.gray_match += 1
			elseif (temp1.color == "black" and temp1.powerup ~= "wild") or (temp2.color == "black" and temp2.powerup ~= "wild") or (temp3.color == "black" and temp3.powerup ~= "wild") or (temp4.color == "black" and temp4.powerup ~= "wild") or (temp5.color == "black" and temp5.powerup ~= "wild") or (temp6.color == "black" and temp6.powerup ~= "wild") then
				vars.score += (200 * multiplier) * vars.combo
				save.total_score += (200 * multiplier) * vars.combo
				save.black_match += 1
			end

			if type(vars.game.timer_boost) == 'table' and vars.can_do_stuff then
				local timer_boost_x = ((multiplier == 2) and vars.game.timer_boost[3]) or vars.game.timer_boost[1]
				local timer_boost_y = ((multiplier == 2) and vars.game.timer_boost[4]) or vars.game.timer_boost[2]
				local timer_boost_value = (timer_boost_x * exp(-0.105 * vars.hexas)) + timer_boost_y
				local new_timer_value = min(vars.timer.value + timer_boost_value, vars.game.timer_max)
				vars.timer:resetnew(new_timer_value, new_timer_value, 0)
			end

			vars.score += 10 * vars.movesbonus
			save.total_score += 10 * vars.movesbonus
			vars.movesbonus = initial_moves_bonus
			if temp1.powerup == "bomb" or temp2.powerup == "bomb" or temp3.powerup == "bomb" or temp4.powerup == "bomb" or temp5.powerup == "bomb" or temp6.powerup == "bomb" then
				save.bomb_match += 1
				self:randomizehexaplex()
				playsound(assets.sfx_boom)
				assets.draw_label = assets.label_bomb
				vars.anim_label:resetnew(1200, 400, -200, pd.easingFunctions.linear)
				vars.anim_label.timerEndedCallback = function()
					assets.draw_label = nil
				end
			else
				temp1.color, temp1.powerup = self:randomizetri()
				temp2.color, temp2.powerup = self:randomizetri()
				temp3.color, temp3.powerup = self:randomizetri()
				temp4.color, temp4.powerup = self:randomizetri()
				temp5.color, temp5.powerup = self:randomizetri()
				temp6.color, temp6.powerup = self:randomizetri()
				if save.sfx then
					local random = random(1, 10000)
					if random == 1 then
						assets.sfx_vine:play()
					else
						assets.sfx_hexa:play()
					end
				end
			end
			vars.anim_hexa:resetnew(600, 1, 11)
			if vars.game.start ~= nil and vars.game.modifier ~= nil then
				local logictest = true

				if vars.game.modifier == 'board' then
					for i = 1, 19 do
						if vars.tris[i].color ~= 'none' then
							logictest = false
						end
					end
				else
					for tris_modifier, values in pairs(tris_modifiers) do
						if tris_modifier == vars.game.modifier  then
							for i = 1, 19 do
								if vars.tris[i][values[1]] == values[2] then
									logictest = false
								end
							end
						end
					end
				end

				if logictest then
					self:endround()
				end
			end
			pd.timer.performAfterDelay(200, function()
				pd.inputHandlers.push(vars.gameHandlers)
				vars.active_hexa = false
				self:check()
			end)
		end
	end)
end

function game:boom(boomed)
	if vars.game.can_go_boom and ((boomed and not vars.boomed) or (not boomed)) and vars.can_do_stuff then
		shakies()
		shakies_y()

		if not boomed then
			if vars.game.goal ~= nil then
				vars.tris = deepcopy(vars.game.goal)
			elseif vars.game.start ~= nil then
				vars.tris = deepcopy(vars.game.start)
			else
				self:randomizehexaplex()
			end
		else
			self:randomizehexaplex()
		end

		playsound(assets.sfx_boom)
		assets.draw_label = assets.label_bomb
		vars.anim_label:resetnew(1200, 400, -200, pd.easingFunctions.linear)
		if boomed then
			vars.boomed = true
			self:check()
		end
	end
end

function game:findslot(slot)
	local temp1
	local temp2
	local temp3
	local temp4
	local temp5
	local temp6
	if slot == 1 then
		-- 1, 2, 3, 7, 8, 9
		temp1 = vars.tris[1]
		temp2 = vars.tris[2]
		temp3 = vars.tris[3]
		temp4 = vars.tris[7]
		temp5 = vars.tris[8]
		temp6 = vars.tris[9]
	elseif slot == 2 then
		-- 3, 4, 5, 9, 10, 11
		temp1 = vars.tris[3]
		temp2 = vars.tris[4]
		temp3 = vars.tris[5]
		temp4 = vars.tris[9]
		temp5 = vars.tris[10]
		temp6 = vars.tris[11]
	elseif slot == 3 then
		-- 6, 7, 8, 13, 14, 15
		temp1 = vars.tris[6]
		temp2 = vars.tris[7]
		temp3 = vars.tris[8]
		temp4 = vars.tris[13]
		temp5 = vars.tris[14]
		temp6 = vars.tris[15]
	elseif slot == 4 then
		-- 8, 9, 10, 15, 16, 17
		temp1 = vars.tris[8]
		temp2 = vars.tris[9]
		temp3 = vars.tris[10]
		temp4 = vars.tris[15]
		temp5 = vars.tris[16]
		temp6 = vars.tris[17]
	elseif slot == 5 then
		-- 10, 11, 12, 17, 18, 19
		temp1 = vars.tris[10]
		temp2 = vars.tris[11]
		temp3 = vars.tris[12]
		temp4 = vars.tris[17]
		temp5 = vars.tris[18]
		temp6 = vars.tris[19]
	end
	return temp1, temp2, temp3, temp4, temp5, temp6
end

function game:randomizetri()
	if vars.game.start ~= nil and vars.game.modifier ~= nil then
		color = "none"
		powerup = ""
		return color, powerup
	else
		local randomcolor = random(1, 3)
		local randompowerup = random(1, 50)
		local color
		local powerup
		if randomcolor == 1 then
			color = "black"
		elseif randomcolor == 2 then
			color = "white"
		elseif randomcolor == 3 then
			color = "gray"
		end
		if vars.game.has_powerups then
			if randompowerup == 1 or randompowerup == 2 or randompowerup == 3 then
				powerup = "double"
			elseif randompowerup == 4 then
				powerup = "bomb"
			elseif randompowerup == 5 then
				powerup = "wild"
			else
				powerup = ""
			end
		else
			powerup = ""
		end
		return color, powerup
	end
end

function game:randomizehexaplex()
	local newcolor
	local newpowerup

	for i = 1, 19 do
		newcolor, newpowerup = self:randomizetri()
		vars.tris[i] = {index = i, color = newcolor, powerup = newpowerup}
	end
end

function game:reset()
	vars.game = self:setup(
		vars.mode,
		vars.variation,
		vars.mission
	)

	if debugging then
		print('--- game mode ---')
		printTable(vars.game)
	end

	vars.can_do_stuff = false
	vars.time = 0
	vars.score = 0
	vars.combo = 0
	vars.moves = 0
	vars.movesbonus = initial_moves_bonus
	vars.hexas = 0
	vars.slot = 1
	vars.active_hexa = false
	vars.ended = false
	vars.boomed = false
	vars.missioncomplete = false
	vars.skippedfanfare = false
	vars.anim_hexa:resetnew(1, 11, 11)
	vars.anim_cursor_x:resetnew(1, 106, 106)
	vars.anim_cursor_y:resetnew(1, 42, 42)
	vars.anim_label:resetnew(0, 400, 400)

	if (vars.timer or false) and (vars.game.timer or false) then
		vars.timer:resetnew(vars.game.timer, vars.game.timer, 0)
		vars.timer:pause()
		vars.old_timer_value = vars.game.timer

		vars.timer.timerEndedCallback = function()
			self:endround()
		end
	else
		vars.timer = nil
	end

	if #playdate.inputHandlers == 1 then
		pd.inputHandlers.push(vars.gameHandlers)
	end

	vars.seed = self:seed()
	math.randomseed(vars.seed)

	if vars.game.goal ~= nil then
		vars.tris = deepcopy(vars.game.goal)
	elseif vars.game.start ~= nil then
		vars.tris = deepcopy(vars.game.start)
	else
		self:randomizehexaplex()
	end
end

function game:restart()
	fademusic(1)
	self:boom(false)
	game:reset()
	game:countdown()
end

function game:fanfare(music)
	newmusic(music)

	local timings = {0, 0, 0, 0, 0, 0}

	if music == 'lose' then
		timings = {548, 2146, 3957, 5740, 6330, 8976}
	elseif music == 'zen_end' then
		timings = {2215, 3342, 3900, 4310, 5300, 8000}
	end

	vars.fanfare_timers = {
		pd.timer.performAfterDelay(timings[1], function()
			gfx.pushContext(assets.modal)
				gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
				if vars.game.zen or false then
					assets.full_circle:drawTextAligned(text('zen1'), 240, 50, kTextAlignment.center)
				else
					assets.full_circle:drawTextAligned(text('score1') .. commalize(vars.score) .. text('score2'), 240, 50, kTextAlignment.center)
				end
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
			gfx.popContext()
		end),

		pd.timer.performAfterDelay(timings[2], function()
			gfx.pushContext(assets.modal)
				gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
				if vars.moves == 1 then
					assets.full_circle:drawTextAligned(text('stats1') .. commalize(vars.moves) .. text('stats2b'), 240, 75, kTextAlignment.center)
				else
					assets.full_circle:drawTextAligned(text('stats1') .. commalize(vars.moves) .. text('stats2a'), 240, 75, kTextAlignment.center)
				end
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
			gfx.popContext()
		end),

		pd.timer.performAfterDelay(timings[3], function()
			gfx.pushContext(assets.modal)
				gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
				if vars.hexas == 1 then
					assets.full_circle:drawTextAligned(text('stats3') .. commalize(vars.hexas) .. text('stats4b'), 240, 90, kTextAlignment.center)
				else
					assets.full_circle:drawTextAligned(text('stats3') .. commalize(vars.hexas) .. text('stats4a'), 240, 90, kTextAlignment.center)
				end
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
			gfx.popContext()
		end),

		pd.timer.performAfterDelay(timings[4], function()
			local ratio = ratiotext(vars.moves, vars.hexas)

			gfx.pushContext(assets.modal)
				gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
				if ratio then
					assets.full_circle:drawTextAligned(text('stats5a') .. ratio .. '.', 240, 120, kTextAlignment.center)
				else
					assets.full_circle:drawTextAligned(text('stats5b'), 240, 120, kTextAlignment.center)
				end
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
			gfx.popContext()
		end),

		pd.timer.performAfterDelay(timings[5], function()
			gfx.pushContext(assets.modal)
				gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
				assets.full_circle:drawTextAligned(vars.game.fanfare_message, 190, 150, kTextAlignment.center)
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
			gfx.popContext()
		end),

		pd.timer.performAfterDelay(timings[6], function()
			pd.inputHandlers.push(vars.loseHandlers, true)
			gfx.pushContext(assets.modal)
				gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
				assets.half_circle:drawText(text(vars.game.text_endgame_button_a or 'newgame') .. ' ' .. text('back'), 40, 205)
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
			gfx.popContext()
		end),
	}
end

function game:ersi()
	vars.skippedfanfare = true
	pd.inputHandlers.push(vars.loseHandlers, true)

	if vars.fanfare_timers ~= nil then
		for i = 1, #vars.fanfare_timers do
			vars.fanfare_timers[i]:pause()
			vars.fanfare_timers[i].timerEndedCallback()
		end

		vars.fanfare_timers = nil
	end
end

function game:endround()
	fademusic(1)

	if not vars.ended then
		if vars.timer ~= nil then
			vars.timer:pause()
		end

		if vars.goal ~= nil or vars.timer == nil then
			playsound(assets.sfx_start)
		else
			playsound(assets.sfx_end)
		end
	end

	if vars.mission ~= nil then
		if not vars.ended then
			self:save_score()
		end

		pd.timer.performAfterDelay(1500, function()
			if vars.game.goal ~= nil and vars.active_hexa then
				self:endround()
				return
			end

			playsound(assets.sfx_mission)
			vars.missioncomplete = true
			updatecheevos()
			pd.datastore.write(save)

			pd.timer.performAfterDelay(1500, function()
				scenemanager:transitionscene(missions, game_mode_presets[vars.game.preset])--(vars.mission ~= nil and vars.mission > 50))
			end)
		end)
	else
		pd.timer.performAfterDelay(((vars.timer and 2000) or 1000), function()
			if vars.active_hexa then
				self:endround()
				return
			end

			if vars.game.scoreboard or false then
				local can_post_to_scoreboard = catalog

				if vars.game.is_daily then
					save.lastdaily.mode = vars.mode
					save.lastdaily.score = vars.score
					can_post_to_scoreboard = (save.lastdaily.year == pd.getGMTTime().year and save.lastdaily.month == pd.getGMTTime().month and save.lastdaily.day == pd.getGMTTime().day)
				end

				if can_post_to_scoreboard then
					pd.scoreboards.addScore(vars.game.scoreboard, vars.score, function(status, result)
						if vars.game.is_daily then
							save.lastdaily.sent = (status.code == 'OK')
						end

						if pd.isSimulator == 1 then
							printTable(status)
							printTable(result)
						end
					end)
				end
			end

			self:save_score()

			updatecheevos()
			pd.datastore.write(save)
			vars.anim_modal:resetnew(500, 240, 0, pd.easingFunctions.outBack)

			self:fanfare((vars.game.has_countdown and 'lose') or 'zen_end')

			if save.skipfanfare then
				self:ersi()
			else
				pd.inputHandlers.push(vars.losingHandlers, true)
			end
		end)
	end

	vars.can_do_stuff = false
	vars.ended = true
end

function game:get_mission_save_keys()
	return
		vars.game.name .. '_' .. vars.game.save_score_to,
		'mission' .. vars.game.mission.index
end

function game:save_score()
	if vars.game.mission ~= nil then
		if vars.game.save_progress_to ~= nil then
			if vars.game.mission.index == save[vars.game.save_progress_to] then
				save[vars.game.save_progress_to] += 1
			end
		end

		local key_mission = vars.game.name .. '_' .. vars.game.save_score_to
		local key_index = 'mission' .. vars.game.mission.index

		if (vars.game.start ~= nil or vars.game.goal ~= nil) and not vars.game.has_stopwatch then
			if save[key_mission][key_index] == 0 or save[key_mission][key_index] > vars.moves then
				save[key_mission][key_index] = vars.moves
			end
		elseif vars.game.has_stopwatch then
			if save[key_mission][key_index] == 0 or save[key_mission][key_index] > vars.time then
				save[key_mission][key_index] = vars.time
			end
		else
			if save[key_mission][key_index] < vars.score then
				save[key_mission][key_index] = vars.score
			end
		end
	elseif (vars.game.save_score_to or false) and vars.score > (save[vars.game.save_score_to] or 0) then
		save[vars.game.save_score_to] = vars.score
	end
end

function game:update()
	local ticks = pd.getCrankTicks(3 * save.sensitivity)

	if save.crank and vars.can_do_stuff and not vars.active_hexa then
		vars.crank_degrees += pd.getCrankChange()
		if ticks ~= 0 and vars.crank_deadzone == 0 then
			vars.crank_deadzone = ticks
		end
		if vars.crank_deadzone == 0 then
			vars.crank_change += pd.getCrankChange()
		end
		if vars.crank_degrees >= (vars.crank_change + 2) then
			if vars.crank_deadzone > 0 then
				for i = 1, vars.crank_deadzone do
					self:swap(vars.slot, not save.flip)
				end
			end
			vars.crank_deadzone = 0
			vars.crank_degrees = 0
			vars.crank_change = 0
		end
		if vars.crank_degrees <= (vars.crank_change - 2) then
			if vars.crank_deadzone < 0 then
				for i = 1, -vars.crank_deadzone do
					self:swap(vars.slot, save.flip)
				end
			end
			vars.crank_deadzone = 0
			vars.crank_degrees = 0
			vars.crank_change = 0
		end
	end

	if vars.timer ~= nil then
		if vars.timer.value < 10001 then
			local otv = math.floor(vars.old_timer_value / 1000)

			if otv > math.floor(vars.timer.value / 1000) then
				shakies(500, 11 - otv)
				shakies_y(750, 11 - otv)
				playsound(assets.sfx_count)
			end
		end

		vars.old_timer_value = vars.timer.value
	end

	if vars.game.has_stopwatch and vars.can_do_stuff then
		vars.time += 1
	end

	if vars.can_do_stuff then
		save.gametime += 1
	end
end
