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
local text <const> = gfx.getLocalizedText

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
				menu:addMenuItem(text('highscores'), function()
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
	}
	vars.titleHandlers = {
		upButtonDown = function()
			if vars.selection ~= 0 then
				if vars.keytimer ~= nil then vars.keytimer:remove() end
				vars.keytimer = pd.timer.keyRepeatTimerWithDelay(150, 75, function()
					if vars.selection > 1 then
						vars.selection -= 1
					else
						vars.selection = #vars.selections
					end
					playsound(assets.sfx_move)
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
					if vars.selection < #vars.selections then
						vars.selection += 1
					else
						vars.selection = 1
					end
					playsound(assets.sfx_move)
				end)
			end
		end,

		downButtonUp = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
		end,

		AButtonDown = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
			if vars.selections[vars.selection] == "arcade" then
				scenemanager:transitionscene(game, "arcade")
				fademusic()
			elseif vars.selections[vars.selection] == "zen" then
				scenemanager:transitionscene(game, "zen")
				fademusic()
			elseif vars.selections[vars.selection] == "dailyrun" then
				if vars.dailyrunnable then
					scenemanager:transitionscene(game, "dailyrun")
					save.lastdaily.score = 0
					fademusic()
					pd.timer.performAfterDelay(500, function()
						save.lastdaily = pd.getGMTTime()
						save.lastdaily.score = 0
						save.lastdaily.sent = false
						pd.datastore.write(save)
					end)
				else
					shakies()
					playsound(assets.sfx_bonk)
				end
			elseif vars.selections[vars.selection] == "highscores" then
				scenemanager:transitionscene(highscores, save.lbs_lastmode)
			elseif vars.selections[vars.selection] == "missions" then
				scenemanager:transitionscene(missions)
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
				end
			end
		end
		if vars.selection == 0 then
			vars.selection = 1
		end
	end)

	if catalog then
		vars.selections = {'arcade', 'zen', 'dailyrun', 'missions', 'highscores', 'statistics', 'howtoplay', 'options', 'credits'}
	else
		vars.selections = {'arcade', 'zen', 'dailyrun', 'missions', 'statistics', 'howtoplay', 'options', 'credits'}
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
		if catalog then
			gfx.fillRect(250 + vars.anim_title.value, 32, 200, 250)
			gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
			if pd.getGMTTime().hour < 23 then
				assets.half_circle:drawText(((vars.dailyrunnable and '⏰ ') or '🔒 ') .. (24 - pd.getGMTTime().hour) .. text('hrs'), 265 + vars.anim_title.value, 90)
			elseif pd.getGMTTime().minute < 59 then
				assets.half_circle:drawText(((vars.dailyrunnable and '⏰ ') or '🔒 ') .. (60 - pd.getGMTTime().minute) .. text('mins'), 265 + vars.anim_title.value, 90)
			else
				assets.half_circle:drawText(((vars.dailyrunnable and '⏰ ') or '🔒 ') .. (60 - pd.getGMTTime().second) .. text('secs'), 265 + vars.anim_title.value, 90)
			end
			if vars.selections[vars.selection] ~= "arcade" then
				assets.half_circle:drawTextAligned(text('arcade'), 385 + vars.anim_title.value, 50, kTextAlignment.right)
			end
			if vars.selections[vars.selection] ~= "zen" then
				assets.half_circle:drawTextAligned(text('zen'), 385 + vars.anim_title.value, 70, kTextAlignment.right)
			end
			if vars.selections[vars.selection] ~= "dailyrun" then
				assets.half_circle:drawTextAligned(text('dailyrun'), 385 + vars.anim_title.value, 90, kTextAlignment.right)
			end
			if vars.selections[vars.selection] ~= "missions" then
				assets.half_circle:drawTextAligned(text('missions'), 385 + vars.anim_title.value, 110, kTextAlignment.right)
			end
			if vars.selections[vars.selection] ~= "highscores" then
				assets.half_circle:drawTextAligned(text('highscores'), 385 + vars.anim_title.value, 130, kTextAlignment.right)
			end
			if vars.selections[vars.selection] ~= "statistics" then
				assets.half_circle:drawTextAligned(text('statistics'), 385 + vars.anim_title.value, 150, kTextAlignment.right)
			end
			if vars.selections[vars.selection] ~= "howtoplay" then
				assets.half_circle:drawTextAligned(text('howtoplay'), 385 + vars.anim_title.value, 170, kTextAlignment.right)
			end
			if vars.selections[vars.selection] ~= "options" then
				assets.half_circle:drawTextAligned(text('options'), 385 + vars.anim_title.value, 190, kTextAlignment.right)
			end
			if vars.selections[vars.selection] ~= "credits" then
				assets.half_circle:drawTextAligned(text('credits'), 385 + vars.anim_title.value, 210, kTextAlignment.right)
			end
			assets.full_circle:drawTextAligned((vars.selection > 0 and text(vars.selections[vars.selection])) or (' '), 385 + vars.anim_title.value, 30 + (20 * vars.selection), kTextAlignment.right)
		else
			gfx.fillRect(250 + vars.anim_title.value, 52, 200, 250)
			gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
			if pd.getGMTTime().hour < 23 then
				assets.half_circle:drawText(((vars.dailyrunnable and '⏰ ') or '🔒 ') .. (24 - pd.getGMTTime().hour) .. text('hrs'), 265 + vars.anim_title.value, 110)
			else
				if pd.getGMTTime().minute < 59 then
					assets.half_circle:drawText(((vars.dailyrunnable and '⏰ ') or '🔒 ') .. (60 - pd.getGMTTime().minute) .. text('mins'), 265 + vars.anim_title.value, 110)
				else
					assets.half_circle:drawText(((vars.dailyrunnable and '⏰ ') or '🔒 ') .. (60 - pd.getGMTTime().second) .. text('secs'), 265 + vars.anim_title.value, 110)
				end
			end
			if vars.selections[vars.selection] ~= "arcade" then
				assets.half_circle:drawTextAligned(text('arcade'), 385 + vars.anim_title.value, 70, kTextAlignment.right)
			end
			if vars.selections[vars.selection] ~= "zen" then
				assets.half_circle:drawTextAligned(text('zen'), 385 + vars.anim_title.value, 90, kTextAlignment.right)
			end
			if vars.selections[vars.selection] ~= "dailyrun" then
				assets.half_circle:drawTextAligned(text('dailyrun'), 385 + vars.anim_title.value, 110, kTextAlignment.right)
			end
			if vars.selections[vars.selection] ~= "missions" then
				assets.half_circle:drawTextAligned(text('missions'), 385 + vars.anim_title.value, 130, kTextAlignment.right)
			end
			if vars.selections[vars.selection] ~= "statistics" then
				assets.half_circle:drawTextAligned(text('statistics'), 385 + vars.anim_title.value, 150, kTextAlignment.right)
			end
			if vars.selections[vars.selection] ~= "howtoplay" then
				assets.half_circle:drawTextAligned(text('howtoplay'), 385 + vars.anim_title.value, 170, kTextAlignment.right)
			end
			if vars.selections[vars.selection] ~= "options" then
				assets.half_circle:drawTextAligned(text('options'), 385 + vars.anim_title.value, 190, kTextAlignment.right)
			end
			if vars.selections[vars.selection] ~= "credits" then
				assets.half_circle:drawTextAligned(text('credits'), 385 + vars.anim_title.value, 210, kTextAlignment.right)
			end
			assets.full_circle:drawTextAligned((vars.selection > 0 and text(vars.selections[vars.selection])) or (' '), 385 + vars.anim_title.value, 50 + (20 * vars.selection), kTextAlignment.right)
		end
		if vars.selections[vars.selection] == "arcade" then
			if save.hardmode then
				if save.hard_score ~= 0 then
					assets.full_circle:drawText(text('high') .. text('divvy') .. commalize(save.hard_score), 10 - vars.anim_title.value, 205)
				end
			else
				if save.score ~= 0 then
					assets.full_circle:drawText(text('high') .. text('divvy') .. commalize(save.score), 10 - vars.anim_title.value, 205)
				end
			end
		elseif vars.selections[vars.selection] == "dailyrun" then
			if save.lastdaily.score ~= 0 then
				assets.full_circle:drawText(text('todaysscore') .. text('divvy') .. commalize(save.lastdaily.score), 10 - vars.anim_title.value, 205)
			end
		elseif vars.selections[vars.selection] == "missions" then
			if save.highest_mission > 1 then
				assets.full_circle:drawText(text('missions_completed') .. text('divvy') .. commalize(save.highest_mission - 1), 10 - vars.anim_title.value, 205)
			end
		end
		assets.half_circle:drawText(text('move') .. ' ' .. text('select'), 10 - vars.anim_title.value, 220)
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		assets.logo:draw(0, 0)
	end)

	self:add()
	newmusic('audio/music/title', true)
end

function title:update()
	if save.lastdaily.year == pd.getGMTTime().year and save.lastdaily.month == pd.getGMTTime().month and save.lastdaily.day == pd.getGMTTime().day then
		vars.dailyrunnable = false
	else
		vars.dailyrunnable = true
	end
	local ticks = pd.getCrankTicks(8)
	if ticks ~= 0 and vars.selection > 0 then
		playsound(assets.sfx_move)
		vars.selection += ticks
		if vars.selection < 1 then
			vars.selection = #vars.selections
		elseif vars.selection > #vars.selections then
			vars.selection = 1
		end
	end
end