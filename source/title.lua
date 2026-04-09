import 'game'
import 'highscores'
import 'missions'
import 'howtoplay'
import 'statistics'
import 'options'
import 'credits'
import 'jukebox'

-- Setting up consts
local pd <const> = playdate
local gfx <const> = pd.graphics
local smp <const> = pd.sound.sampleplayer
local text <const> = getLocalizedText

class('title').extends(gfx.sprite) -- Create the scene's class
function title:init(...)
	title.super.init(self)
	local args = {...} -- Arguments passed in through the scene management will arrive here
	gfx.sprite.setAlwaysRedraw(true)

	function pd.gameWillPause() -- When the game's paused...
		local menu = pd.getSystemMenu()
		pauseimage()
		menu:removeAllMenuItems()
		if not scenemanager.transitioning and vars.selection > 0 then
			menu:addMenuItem(text('jukebox'), function()
				scenemanager:transitionscene(jukebox)
				vars.selection = 0
				fademusic()
			end)
			if catalog then
				menu:addMenuItem(text('rankings'), function()
					scenemanager:transitionscene(highscores)
					vars.selection = 0
				end)
			end
			menu:addMenuItem(text('options'), function()
				scenemanager:transitionscene(options)
				vars.selection = 0
			end)
		end
	end

	assets = {
		title = gfx.image.new('images/title'),
		stars_small = gfx.image.new('images/stars_small'),
		stars_large = gfx.image.new('images/stars_large'),
		logo = gfx.image.new('images/logo'),
		full_circle = gfx.font.new('fonts/full-circle'),
		half_circle = gfx.font.new('fonts/full-circle-halved'),
		sfx_move = smp.new('audio/sfx/swap'),
		sfx_bonk = smp.new('audio/sfx/bonk'),
		sfx_select = smp.new('audio/sfx/select'),
		timer = gfx.image.new('images/timer'),
	}

	vars = {
		animate = args[1], -- bool. does the title animate on transition back?
		default = args[2],
		anim_stars_small_x = pd.timer.new(4000, 0, -399),
		anim_stars_small_y = pd.timer.new(2750, 0, -239),
		anim_stars_large_x = pd.timer.new(2500, 0, -399),
		anim_stars_large_y = pd.timer.new(1250, 0, -239),
		dailyrunnable = false,
		selection = 0,
		game_mode_index = 0,
		game_mode_variation = 0,
	}

	vars.titleHandlers = {
		upButtonDown = function()
			if vars.selection ~= 0 then
				if vars.keytimer ~= nil then vars.keytimer:remove() end
				vars.keytimer = pd.timer.keyRepeatTimerWithDelay(150, 75, function()
					self:change_selection(-1)
				end)
			end
		end,

		upButtonUp = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
		end,

		downButtonDown = function()
			if vars.selection ~= 0 then
				if vars.keytimer ~= nil then vars.keytimer:remove() end
				vars.keytimer = pd.timer.keyRepeatTimerWithDelay(150, 75, function()
					self:change_selection(1)
				end)
			end
		end,

		downButtonUp = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
		end,

		leftButtonDown = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
			self:toggle_mode_variation(-1)
		end,

		leftButtonUp = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
		end,

		rightButtonDown = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
			self:toggle_mode_variation(1)
		end,

		rightButtonUp = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
		end,

		AButtonDown = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end

			if vars.game_mode_index > 0 then
				local selected_game_mode = game_mode_presets[vars.game_mode_index]
				local selected_game_mode_variation = (selected_game_mode.variations and selected_game_mode.variations[vars.game_mode_variation]) or {}
				local can_play = true

				if type(selected_game_mode.missions) == 'table' then
					scenemanager:transitionscene(missions, selected_game_mode)
					return
				elseif selected_game_mode.is_daily then
					can_play = vars.dailyrunnable

					if can_play then
						save.lastdaily.score = 0
						pd.timer.performAfterDelay(500, function()
							save.lastdaily = pd.getGMTTime()
							save.lastdaily.score = 0
							save.lastdaily.sent = false
							pd.datastore.write(save)
						end)
					end
				end

				if can_play then
					scenemanager:transitionscene(game, vars.selections[vars.selection], selected_game_mode_variation.name or nil)
					fademusic()
				else
					shakies()
					playsound(assets.sfx_bonk)
				end
			elseif vars.selections[vars.selection] == "highscores" then
				scenemanager:transitionscene(highscores, save.lbs_lastmode)
			elseif vars.selections[vars.selection] == "statistics" then
				scenemanager:transitionscene(statistics)
			elseif vars.selections[vars.selection] == "howtoplay" then
				scenemanager:transitionscene(howtoplay)
			elseif vars.selections[vars.selection] == "options" then
				scenemanager:transitionscene(options)
			elseif vars.selections[vars.selection] == "credits" then
				scenemanager:transitionscene(credits)
			end
			if scenemanager.transitioning then
				playsound(assets.sfx_select)
				vars.selection = 0
			end
		end,
	}
	pd.timer.performAfterDelay(scenemanager.transitiontime, function()
		pd.inputHandlers.push(vars.titleHandlers)
		if vars.default ~= nil then
			for i = 1, #vars.selections do
				if vars.selections[i] == vars.default then
					vars.selection = i
					self:change_selection()
				end
			end
		end
		if vars.selection == 0 then
			self:change_selection(1)
		end
	end)

	vars.selections = {'statistics', 'howtoplay', 'options', 'credits'}
	vars.text = {text('statistics'), text('howtoplay'), text('options'), text('credits')}

	if catalog then
		table.insert(vars.selections, 1, 'highscores')
		table.insert(vars.text, 1, text('highscores'))
	end

	vars.game_modes = table.column(game_mode_presets, 'name')

	for i = #vars.game_modes, 1, -1 do
		table.insert(vars.selections, 1, vars.game_modes[i])

		if game_mode_presets[i] ~= nil and game_mode_presets[i].lang ~= nil and game_mode_presets[i].lang[save.lang] ~= nil and game_mode_presets[i].lang[save.lang].title ~= nil then
			table.insert(vars.text, 1, game_mode_presets[i].lang[save.lang].title)
		else
			table.insert(vars.text, 1, vars.game_modes[i] == 'custom' and text('custom_mode') or text(vars.game_modes[i]))
		end
	end

	if vars.animate then
		vars.anim_title = pd.timer.new(500, 200, 0, pd.easingFunctions.outBack)
	else
		vars.anim_title = pd.timer.new(0, 0, 0)
	end

	vars.anim_stars_small_x.repeats = true
	vars.anim_stars_small_y.repeats = true
	vars.anim_stars_large_x.repeats = true
	vars.anim_stars_large_y.repeats = true

	gfx.sprite.setBackgroundDrawingCallback(function(x, y, width, height)
		assets.title:draw(0, 0)
		assets.stars_small:draw(vars.anim_stars_small_x.value, vars.anim_stars_small_y.value)
		assets.stars_large:draw(vars.anim_stars_large_x.value, vars.anim_stars_large_y.value)
		gfx.setDitherPattern(0.25, gfx.image.kDitherTypeBayer2x2)
		gfx.fillRect(250 + vars.anim_title.value, 12 + (catalog and 20 or 40), 200, 250)
		assets.logo:draw(0, 0)
		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)

		local offsetY = 230 - ((#vars.selections + 1) * 20)
		local font_style

		for i = 1, #vars.selections do
			local selected = vars.selections[vars.selection]

			if i == vars.selection then
				font_style = 'full_circle'

				if selected == 'dailyrun' then
					gfx.setImageDrawMode(gfx.kDrawModeCopy)
					assets.timer:draw(206 + vars.anim_title.value, offsetY + (i * 20) - 8)
					gfx.setImageDrawMode(gfx.kDrawModeFillWhite)

					local dailyrunicon = (vars.dailyrunnable and '⏰') or '🔒'
					local dailyruntext

					if pd.getGMTTime().hour < 23 then
						dailyruntext = (24 - pd.getGMTTime().hour) .. text('hrs')
					elseif pd.getGMTTime().minute < 59 then
						dailyruntext = (60 - pd.getGMTTime().minute) .. text('mins')
					else
						dailyruntext = (60 - pd.getGMTTime().second) .. text('secs')
					end

					assets.half_circle:drawTextAligned(
						dailyrunicon .. ' ' .. dailyruntext,
						238 + vars.anim_title.value,
						offsetY + (i * 20),
						kTextAlignment.center
					)
				end
			else
				font_style = 'half_circle'
			end

			assets[font_style]:drawTextAligned(vars.text[i], 385 + vars.anim_title.value, offsetY + (i * 20), kTextAlignment.right)
		end

		if vars.game_mode_index > 0 then
			local subtitle_text = ''
			local selected_game_mode = game_mode_presets[vars.game_mode_index]

			if type(selected_game_mode.missions) == 'table' and (save[selected_game_mode.save_progress_to] or 1) > 1 then
				subtitle_text = text('missions_completed') .. text('divvy') .. commalize(save[selected_game_mode.save_progress_to] - 1)
			elseif selected_game_mode.variations ~= nil then
				local selected_variation = selected_game_mode.variations[vars.game_mode_variation] or {}
				local selected_variation_name = selected_variation.name or ''
				local selected_variation_title = selected_game_mode.lang ~= nil and selected_game_mode.lang[save.lang] ~= nil and selected_game_mode.lang[save.lang]['title_variation_' .. selected_variation_name] or text(selected_variation.name)

				if selected_game_mode.is_daily then
					if save.lbs_lastmode == selected_game_mode.name and save.lastdaily.score ~= 0 then
						subtitle_text = text('todaysscore') .. text('divvy') .. commalize(save.lastdaily.score)

						if save.lastdaily.mode == 'harddailyrun' then
							subtitle_text = subtitle_text .. ' ' .. text('hard')
						end
					else
						if selected_variation_name ~= 'default' then
							subtitle_text = subtitle_text .. ((subtitle_text ~= '' and ' ') or '') .. '(' .. selected_variation_title .. ')'
						end
					end
				else
					if selected_variation.save_score_to ~= nil then
						local highscore = save[selected_variation.save_score_to] or 0

						if highscore > 0 then
							subtitle_text = text('high') .. text('divvy') .. commalize(highscore)
						end
					end

					if selected_variation_name ~= 'default' then
						subtitle_text = subtitle_text .. ((subtitle_text ~= '' and ' ') or '') .. '(' .. selected_variation_title .. ')'
					end
				end
			end

			if subtitle_text ~= '' then
				assets.full_circle:drawText(subtitle_text, 10 - vars.anim_title.value, 205)
			end
		end

		assets.half_circle:drawText(text('move') .. ' ' .. text('select'), 10 - vars.anim_title.value, 220)
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
	end)

	self:add()
	newmusic('title', true)
end

function title:change_selection(direction)
	if direction ~= nil and (direction < 0 or direction > 0) then
		vars.selection += direction

		if vars.selection < 1 then
			vars.selection = #vars.selections
		elseif vars.selection > #vars.selections then
			vars.selection = 1
		end

		playsound(assets.sfx_move)
	end

	vars.game_mode_index = 0
	vars.game_mode_variation = 0

	for i = 1, #game_mode_presets do
		if game_mode_presets[i].name == vars.selections[vars.selection] then
			vars.game_mode_index = i
			vars.game_mode_variation = (game_mode_presets[i].variations and type(game_mode_presets[i].missions) ~= 'table' and 1) or 0
		end
	end
end

function title:toggle_mode_variation(direction)
	local selection = vars.selections[vars.selection] or ''
	local selected_game_mode = game_mode_presets[vars.game_mode_index] or nil

	if selected_game_mode == nil then return end

	local can_toggle = true

	if (selected_game_mode.is_daily and not vars.dailyrunnable) or selected_game_mode.variations == nil or type(selected_game_mode.missions) == 'table' then
		shakies()
		playsound(assets.sfx_bonk)
	else
		vars.keytimer = pd.timer.keyRepeatTimerWithDelay(150, 75, function()
			playsound(assets.sfx_move)

			vars.game_mode_variation += direction

			if vars.game_mode_variation < 1 then
				vars.game_mode_variation = #selected_game_mode.variations
			elseif vars.game_mode_variation > #selected_game_mode.variations then
				vars.game_mode_variation = 1
			end

			save.hardmode = (selected_game_mode.variations[vars.game_mode_variation] and selected_game_mode.variations[vars.game_mode_variation].name == 'hard') or nil
		end)
	end
end

function title:update()
	if save.lastdaily.year == pd.getGMTTime().year and save.lastdaily.month == pd.getGMTTime().month and save.lastdaily.day == pd.getGMTTime().day then
		vars.dailyrunnable = false
	else
		vars.dailyrunnable = true
	end
	local ticks = pd.getCrankTicks(8)
	if ticks ~= 0 and vars.selection > 0 then
		self:change_selection(ticks)
	end
end
