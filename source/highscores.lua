-- Setting up consts
local pd <const> = playdate
local gfx <const> = pd.graphics
local smp <const> = pd.sound.sampleplayer
local text <const> = getLocalizedText

class('highscores').extends(gfx.sprite) -- Create the scene's class
function highscores:init(...)
	highscores.super.init(self)
	local args = {...} -- Arguments passed in through the scene management will arrive here
	gfx.sprite.setAlwaysRedraw(true)

	function pd.gameWillPause() -- When the game's paused...
		local menu = pd.getSystemMenu()
		pauseimage()
		menu:removeAllMenuItems()
		if not scenemanager.transitioning then
			if not vars.loading then
				menu:addMenuItem(text('refresh'), function()
					self:refresh_selected_board()
				end)
			end
			menu:addMenuItem(text('goback'), function()
				scenemanager:transitionscene(title, false, 'highscores')
			end)
		end
	end

	assets = {
		stars_small = gfx.image.new('images/stars_small'),
		stars_large = gfx.image.new('images/stars_large'),
		full_circle = gfx.font.new('fonts/full-circle'),
		half_circle = gfx.font.new('fonts/full-circle-halved'),
		sfx_move = smp.new('audio/sfx/swap'),
		sfx_bonk = smp.new('audio/sfx/bonk'),
		sfx_back = smp.new('audio/sfx/back'),
		fg = gfx.image.new('images/fg'),
	}

	vars = {
		mode = args[1],
		variation = args[2],
		anim_stars_small_x = pd.timer.new(4000, 0, -399),
		anim_stars_small_y = pd.timer.new(2750, 0, -239),
		anim_stars_large_x = pd.timer.new(2500, 0, -399),
		anim_stars_large_y = pd.timer.new(1250, 0, -239),
		results = {},
		bests = {},
		loading = false,
	}

	vars.scoreboards, vars.index = self:get_scoreboards_from_game_mode_presets()

	if debugging then
		print('--- selected: ' .. vars.scoreboards[vars.index].mode .. ' - ' .. vars.scoreboards[vars.index].variation .. ' ---')
	end

	vars.highscoresHandlers = {
		AButtonDown = function()
			self:refresh_selected_board()
		end,

		leftButtonDown = function()
			self:change_scoreboard(-1)

			if vars.results[vars.index] == nil then
				self:refresh_selected_board()
			end
		end,

		rightButtonDown = function()
			self:change_scoreboard(1)

			if vars.results[vars.index] == nil then
				self:refresh_selected_board()
			end
		end,

		BButtonDown = function()
			if vars.loading then
				playsound(assets.sfx_bonk)
				shakies()
				return
			end

			playsound(assets.sfx_back)
			scenemanager:transitionscene(title, false, 'highscores')
		end
	}

	pd.timer.performAfterDelay(scenemanager.transitiontime, function()
		pd.inputHandlers.push(vars.highscoresHandlers)
	end)

	self:refresh_selected_board()

	vars.anim_stars_small_x.repeats = true
	vars.anim_stars_small_y.repeats = true
	vars.anim_stars_large_x.repeats = true
	vars.anim_stars_large_y.repeats = true

	if pd.getReduceFlashing() then
		vars.blink = {}
		vars.blink.value = 1
	else
		vars.blink = pd.timer.new(1000, 1.99, 0.5)
		vars.blink.repeats = true
	end

	gfx.sprite.setBackgroundDrawingCallback(function(x, y, width, height)
		assets.stars_small:draw(vars.anim_stars_small_x.value, vars.anim_stars_small_y.value)
		assets.stars_large:draw(vars.anim_stars_large_x.value, vars.anim_stars_large_y.value)
		gfx.setDitherPattern(0.25, gfx.image.kDitherTypeBayer2x2)
		gfx.fillRect(0, 0, 400, 240)
		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)

		local scoreboard = vars.scoreboards[vars.index]

		assets.full_circle:drawTextAligned(text(scoreboard.mode), 200, 10, kTextAlignment.center)

		local subheading_text = (scoreboard.variation ~= 'default' and (' (' .. text(scoreboard.variation) .. ')') or '')

		if scoreboard.is_daily then
			subheading_text = text('todaysscores') .. subheading_text .. '   ⏰ '

			if pd.getGMTTime().hour < 23 then
				subheading_text = subheading_text .. (24 - pd.getGMTTime().hour) .. text('hrs')
			elseif pd.getGMTTime().minute < 59 then
				subheading_text = subheading_text .. (60 - pd.getGMTTime().minute) .. text('mins')
			else
				subheading_text = subheading_text .. (60 - pd.getGMTTime().second) .. text('secs')
			end
		else
			subheading_text = text('highscores') .. subheading_text
		end

		assets.half_circle:drawTextAligned(subheading_text, 200, 25, kTextAlignment.center)

		if vars.results[vars.index].scores ~= nil and next(vars.results[vars.index].scores) ~= nil and not vars.loading then
			for _, v in ipairs(vars.results[vars.index].scores) do
				if ((vars.bests[vars.index].player ~= nil and string.len(vars.bests[vars.index].player) == 16 and tonumber(vars.bests[vars.index].player)) and v.rank <= 8) or v.rank <= 9 then
					assets.half_circle:drawTextAligned(ordinal(v.rank), 80, 30 + (15 * v.rank), kTextAlignment.right)
					assets.full_circle:drawText(v.player, 90, 30 + (15 * v.rank))
					assets.half_circle:drawTextAligned(commalize(v.value), 340, 30 + (15 * v.rank), kTextAlignment.right)
				end
			end
		elseif vars.results[vars.index] == "fail" then
			assets.half_circle:drawTextAligned(text('failedscores'), 200, 110, kTextAlignment.center)
		else
			if vars.loading then
				assets.half_circle:drawTextAligned(text('gettingscores'), 200, 110, kTextAlignment.center)
			else
				assets.half_circle:drawTextAligned(text('emptyscores_' .. (scoreboard.is_daily and 'dailyrun' or 'arcade')), 200, 110, kTextAlignment.center)
			end
		end

		if vars.bests[vars.index].rank ~= nil then
			if string.len(vars.bests[vars.index].player) == 16 and tonumber(vars.bests[vars.index].player) then
				if math.floor(vars.blink.value) == 1 then
					assets.full_circle:drawTextAligned(text('username'), 200, 170, kTextAlignment.center)
				end
			else
				assets.full_circle:drawTextAligned(text('lbscore1') .. commalize(vars.bests[vars.index].value) .. text('lbscore2') .. ordinal(vars.bests[vars.index].rank) .. text('lbscore3'), 200, 185, kTextAlignment.center)
			end
		end

		assets.half_circle:drawText(text('page'), 65, 205)
		assets.half_circle:drawText(text('refreshscores') .. ' ' .. text('back'), 70, 220)
		assets.half_circle:drawTextAligned(vars.index .. '/' .. #vars.scoreboards, 330, 220, kTextAlignment.right)

		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		assets.fg:draw(0, 0)
	end)

	self:add()
	newmusic('title', true)
	pd.datastore.write(save)
end

function highscores:refresh_selected_board()
	if vars.loading then
		playsound(assets.sfx_bonk)
		shakies()
		return
	end

	vars.results[vars.index] = {}
	vars.bests[vars.index] = {}
	vars.loading = true

	local selected = vars.scoreboards[vars.index]
	local can_post_to_scoreboard = false

	if catalog then
		if selected.save_score_to ~= nil then
			can_post_to_scoreboard = (save[selected.save_score_to] ~= 0)
		elseif selected.is_daily and selected.mode == save.lastdaily.mode and selected.variation == save.lastdaily.variation then
			can_post_to_scoreboard = (save.lastdaily.score ~= 0 and save.lastdaily.sent == false and save.lastdaily.year == pd.getGMTTime().year and save.lastdaily.month == pd.getGMTTime().month and save.lastdaily.day == pd.getGMTTime().day)
		end
	end

	if can_post_to_scoreboard then
		pd.scoreboards.addScore(selected.scoreboard, 0, function(status, result)
			if debugging then
				print('--- ' .. selected.scoreboard .. ' fake score check ---')
				printTable({
					status = status,
					result = result,
				})
			end
		end)
	end

	if debugging then
		pd.scoreboards.getScoreboards(function(status, result)
			print('--- All scoreboards ---')
			printTable({
				status = status,
				result = result,
			})
		end)
	end

	pd.scoreboards.getScores(selected.scoreboard, function(status, result)
		if debugging then
			print('--- ' .. selected.scoreboard .. ' scoreboard ---')
			printTable({
				status = status,
				result = result,
			})
		end

		if status.code == "OK" then
			vars.results[vars.index] = result

			pd.scoreboards.getPersonalBest(selected.scoreboard, function(status, result)
				vars.loading = false

				if debugging then
					print('--- ' .. selected.scoreboard .. ' personal best ---')
					printTable({
						status = status,
						result = result,
					})
				end

				if status.code == "OK" then
					vars.bests[vars.index] = result
				end
			end)
		else
			vars.results[vars.index] = "fail"
			vars.loading = false
		end
	end)
end

function highscores:update()
	local gmt = pd.getGMTTime()

	if gmt.hour == 0 and gmt.minute == 0 and gmt.second == 0 and not vars.loading and vars.scoreboards[vars.index].is_daily then
		self:refresh_selected_board()
	end
end

function highscores:get_scoreboards_from_game_mode_presets()
	local game_mode_preset_keys = table.column(game_mode_presets, 'name')
	local scoreboards = {}
	local index = 1

	for i = 1, #game_mode_preset_keys do
		if type(game_mode_presets[i].variations) == 'table' then
			for v = 1, #game_mode_presets[i].variations do
				if game_mode_presets[i].variations[v].scoreboard ~= nil then
					scoreboards[#scoreboards + 1] = {
						mode = game_mode_presets[i].name,
						variation = game_mode_presets[i].variations[v].name,
						scoreboard = game_mode_presets[i].variations[v].scoreboard,
						is_daily = game_mode_presets[i].is_daily or false,
						save_score_to = game_mode_presets[i].variations[v].save_score_to or game_mode_presets[i].save_score_to or nil,
					}

					if scoreboards[#scoreboards].mode == vars.mode and scoreboards[#scoreboards].variation == vars.variation then
						index = #scoreboards
					end
				end
			end
		end
	end

	if debugging then
		print('--- scoreboards (index: ' .. index .. ') ---')
		printTable(scoreboards)
	end

	return scoreboards, index
end

function highscores:change_scoreboard(direction)
	if not vars.loading and direction ~= nil and (direction < 0 or direction > 0) then
		vars.index += direction

		if vars.index < 1 then
			vars.index = #vars.scoreboards
		elseif vars.index > #vars.scoreboards then
			vars.index = 1
		end

		playsound(assets.sfx_move)
	else
		playsound(assets.sfx_bonk)
		shakies()
	end
end
