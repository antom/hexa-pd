-- Setting up consts
local pd <const> = playdate
local gfx <const> = pd.graphics
local smp <const> = pd.sound.sampleplayer
local text <const> = getLocalizedText

class('statistics').extends(gfx.sprite) -- Create the scene's class
function statistics:init(...)
	statistics.super.init(self)
	local args = {...} -- Arguments passed in through the scene management will arrive here
	gfx.sprite.setAlwaysRedraw(true)

	function pd.gameWillPause() -- When the game's paused...
		local menu = pd.getSystemMenu()
		pauseimage()
		menu:removeAllMenuItems()
		if not scenemanager.transitioning then
			menu:addMenuItem(text('goback'), function()
				scenemanager:transitionscene(title, false, 'statistics')
			end)
		end
	end

	assets = {
		stars_small = gfx.image.new('images/stars_small'),
		stars_large = gfx.image.new('images/stars_large'),
		full_circle = gfx.font.new('fonts/full-circle'),
		half_circle = gfx.font.new('fonts/full-circle-halved'),
		sfx_back = smp.new('audio/sfx/back'),
		fg = gfx.image.new('images/fg'),
	}

	vars = {
		anim_stars_small_x = pd.timer.new(4000, 0, -399),
		anim_stars_small_y = pd.timer.new(2750, 0, -239),
		anim_stars_large_x = pd.timer.new(2500, 0, -399),
		anim_stars_large_y = pd.timer.new(1250, 0, -239),
		values = {
			{text('totalswaps'), commalize(save.swaps)},
			{text('totalhexas'), commalize(save.hexas)},
			{text('swapshexas'), ratiotext(save.swaps, save.hexas) or text('unavailable')},
			{text('highscore'), commalize(save.score)},
			{text('highscorehardmode'), commalize(save.hard_score)},
			{text('playtime'), self:get_playtime()},
			{text('gametime'), self:get_gametime()},
			{text('totalscore'), commalize(save.total_score)},
			{text('hexablack'), commalize(save.black_match)},
			{text('hexagray'), commalize(save.gray_match)},
			{text('hexawhite'), commalize(save.white_match)},
			{text('hexadouble'), commalize(save.double_match)},
			{text('kerplosion'), commalize(save.bomb_match)},
			{text('hexawild'), commalize(save.wild_match)},
		}
	}
	vars.statisticsHandlers = {
		BButtonDown = function()
			playsound(assets.sfx_back)
			scenemanager:transitionscene(title, false, 'statistics')
		end
	}
	pd.timer.performAfterDelay(scenemanager.transitiontime, function()
		pd.inputHandlers.push(vars.statisticsHandlers)
	end)

	vars.anim_stars_small_x.repeats = true
	vars.anim_stars_small_y.repeats = true
	vars.anim_stars_large_x.repeats = true
	vars.anim_stars_large_y.repeats = true

	gfx.sprite.setBackgroundDrawingCallback(function(x, y, width, height)
		assets.stars_small:draw(vars.anim_stars_small_x.value, vars.anim_stars_small_y.value)
		assets.stars_large:draw(vars.anim_stars_large_x.value, vars.anim_stars_large_y.value)
		gfx.setDitherPattern(0.25, gfx.image.kDitherTypeBayer2x2)
		gfx.fillRect(0, 0, 400, 240)
		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)

		vars.values[6][2] = self:get_playtime()

		local offset_y = 5

		for i = 1, #vars.values do
			assets.half_circle:drawTextAligned(vars.values[i][1] .. text('divvy'), 240, offset_y, kTextAlignment.right)
			assets.full_circle:drawText(vars.values[i][2], 250, offset_y)
			offset_y += 15
		end

		assets.half_circle:drawText(text('back'), 70, 220)
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		assets.fg:draw(0, 0)
	end)

	self:add()
end

function statistics:get_playtime()
	local playhours, playmins, playsecs = timecalchour(save.playtime)
	return playhours .. 'h ' .. playmins .. 'm ' .. playsecs .. 's'
end

function statistics:get_gametime()
	local gamehours, gamemins, gamesecs = timecalchour(save.gametime)
	return gamehours .. 'h ' .. gamemins .. 'm ' .. gamesecs .. 's'
end
