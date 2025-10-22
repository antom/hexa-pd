-- Setting up consts
local pd <const> = playdate
local gfx <const> = pd.graphics
local smp <const> = pd.sound.sampleplayer
local text <const> = getLocalizedText

class('options').extends(gfx.sprite) -- Create the scene's class
function options:init(...)
	options.super.init(self)
	local args = {...} -- Arguments passed in through the scene management will arrive here
	gfx.sprite.setAlwaysRedraw(true)

	function pd.gameWillPause() -- When the game's paused...
		local menu = pd.getSystemMenu()
		pauseimage()
		menu:removeAllMenuItems()
		if not scenemanager.transitioning and vars.selection > 0 then
			menu:addMenuItem(text('goback'), function()
				scenemanager:transitionscene(title, false, 'options')
				vars.selection = 0
			end)
		end
	end

	assets = {
		stars_small = gfx.image.new('images/stars_small'),
		stars_large = gfx.image.new('images/stars_large'),
		full_circle = gfx.font.new('fonts/full-circle'),
		half_circle = gfx.font.new('fonts/full-circle-halved'),
		sfx_move = smp.new('audio/sfx/swap'),
		sfx_select = smp.new('audio/sfx/select'),
		sfx_back = smp.new('audio/sfx/back'),
		sfx_boom = smp.new('audio/sfx/boom'),
		fg = gfx.image.new('images/fg'),
		fg_hexa_1 = gfx.image.new('images/fg_hexa_1'),
		fg_hexa_2 = gfx.image.new('images/fg_hexa_2'),
	}

	vars = {
		anim_stars_small_x = pd.timer.new(4000, 0, -399),
		anim_stars_small_y = pd.timer.new(2750, 0, -239),
		anim_stars_large_x = pd.timer.new(2500, 0, -399),
		anim_stars_large_y = pd.timer.new(1250, 0, -239),
		anim_fg_hexa = pd.timer.new(3000, 0, 7, pd.easingFunctions.inOutSine),
		selections = {'lang', 'music', 'sfx', 'flip', 'crank', 'skipfanfare', 'hardmode', 'flashing', 'olddelay', 'reset'},
		selection = 0,
		resetprogress = 1,
		flashing_text = {text('flashing_auto'), text(true), text(false)},
		olddelay_text = {text(false), text(true)},
	}
	vars.optionsHandlers = {
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
					if vars.resetprogress < 4 then
						vars.resetprogress = 1
					end
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
					if vars.resetprogress < 4 then
						vars.resetprogress = 1
					end
				end)
			end
		end,

		downButtonUp = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
		end,

		leftButtonDown = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
			if vars.selections[vars.selection] == "music" then
				save.music -= 1
				if save.music < 0 then
					save.music = 5
				end
				if save.music > 0 then
					if music ~= nil then
						music:setVolume(save.music / 5)
					else
						newmusic('audio/music/title', true)
					end
				else
					fademusic(1)
				end
				playsound(assets.sfx_select)
			elseif vars.selections[vars.selection] == "sfx" then
				save.sfx -= 1
				if save.sfx < 0 then
					save.sfx = 5
				end
				playsound(assets.sfx_select)
			elseif vars.selections[vars.selection] == "lang" then
				if save.lang == "en" then
					save.lang = "fr"
				elseif save.lang == "fr" then
					save.lang = "en"
				end
				playsound(assets.sfx_select)
			elseif vars.selections[vars.selection] == "flip" then
				save.flip = not save.flip
				playsound(assets.sfx_select)
			elseif vars.selections[vars.selection] == "crank" then
				if save.sensitivity == 2 then
					save.sensitivity = 0
					save.crank = false
				elseif save.sensitivity == 1 then
					save.sensitivity = 2
					save.crank = true
				elseif save.sensitivity == 0 then
					save.sensitivity = 1
					save.crank = true
				end
				playsound(assets.sfx_select)
			elseif vars.selections[vars.selection] == "skipfanfare" then
				save.skipfanfare = not save.skipfanfare
				playsound(assets.sfx_select)
			elseif vars.selections[vars.selection] == "hardmode" then
				save.hardmode = not save.hardmode
				playsound(assets.sfx_select)
			elseif vars.selections[vars.selection] == "flashing" then
				save.flashing -= 1
				if save.flashing < 1 then
					save.flashing = 3
				end
				playsound(assets.sfx_select)
			elseif vars.selections[vars.selection] == "olddelay" then
				save.flash_int -= 1
				if save.flash_int < 1 then
					save.flash_int = 2
				end
				playsound(assets.sfx_select)
			end
		end,

		rightButtonDown = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
			if vars.selections[vars.selection] == "music" then
				save.music += 1
				if save.music > 5 then
					save.music = 0
				end
				if save.music > 0 then
					if music ~= nil then
						music:setVolume(save.music / 5)
					else
						newmusic('audio/music/title', true)
					end
				else
					fademusic(1)
				end
				playsound(assets.sfx_select)
			elseif vars.selections[vars.selection] == "sfx" then
				save.sfx += 1
				if save.sfx > 5 then
					save.sfx = 0
				end
				playsound(assets.sfx_select)
			elseif vars.selections[vars.selection] == "lang" then
				if save.lang == "en" then
					save.lang = "fr"
				elseif save.lang == "fr" then
					save.lang = "en"
				end
				playsound(assets.sfx_select)
			elseif vars.selections[vars.selection] == "flip" then
				save.flip = not save.flip
				playsound(assets.sfx_select)
			elseif vars.selections[vars.selection] == "crank" then
				if save.sensitivity == 2 then
					save.sensitivity = 1
					save.crank = true
				elseif save.sensitivity == 1 then
					save.sensitivity = 0
					save.crank = false
				elseif save.sensitivity == 0 then
					save.sensitivity = 2
					save.crank = true
				end
				playsound(assets.sfx_select)
			elseif vars.selections[vars.selection] == "skipfanfare" then
				save.skipfanfare = not save.skipfanfare
				playsound(assets.sfx_select)
			elseif vars.selections[vars.selection] == "hardmode" then
				save.hardmode = not save.hardmode
				playsound(assets.sfx_select)
			elseif vars.selections[vars.selection] == "flashing" then
				save.flashing += 1
				if save.flashing > 3 then
					save.flashing = 1
				end
				playsound(assets.sfx_select)
			elseif vars.selections[vars.selection] == "olddelay" then
				save.flash_int += 1
				if save.flash_int > 2 then
					save.flash_int = 1
				end
				playsound(assets.sfx_select)
			end
		end,

		BButtonDown = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
			playsound(assets.sfx_back)
			scenemanager:transitionscene(title, false, 'options')
			vars.selection = 0
		end,

		AButtonDown = function()
			if vars.keytimer ~= nil then vars.keytimer:remove() end
			if vars.selections[vars.selection] == "music" then
				save.music += 1
				if save.music > 5 then
					save.music = 0
				end
				if save.music > 0 then
					if music ~= nil then
						music:setVolume(save.music / 5)
					else
						newmusic('audio/music/title', true)
					end
				else
					fademusic(1)
				end
			elseif vars.selections[vars.selection] == "sfx" then
				save.sfx += 1
				if save.sfx > 5 then
					save.sfx = 0
				end
			elseif vars.selections[vars.selection] == "lang" then
				if save.lang == "en" then
					save.lang = "fr"
				elseif save.lang == "fr" then
					save.lang = "en"
				end
			elseif vars.selections[vars.selection] == "flip" then
				save.flip = not save.flip
			elseif vars.selections[vars.selection] == "crank" then
				if save.sensitivity == 2 then
					save.sensitivity = 1
					save.crank = true
				elseif save.sensitivity == 1 then
					save.sensitivity = 0
					save.crank = false
				elseif save.sensitivity == 0 then
					save.sensitivity = 2
					save.crank = true
				end
			elseif vars.selections[vars.selection] == "skipfanfare" then
				save.skipfanfare = not save.skipfanfare
			elseif vars.selections[vars.selection] == "hardmode" then
				save.hardmode = not save.hardmode
			elseif vars.selections[vars.selection] == "reset" then
				if vars.resetprogress < 3 then
					vars.resetprogress += 1
				elseif vars.resetprogress == 3 then
					playsound(assets.sfx_boom)
					vars.resetprogress += 1
					save.score = 0
					save.hard_score = 0
					save.swaps = 0
					save.hexas = 0
					save.mission_bests = {}
					save.highest_mission = 1
					for i = 1, #save.mission_bests do
						save.mission_bests[i] = save.mission_bests[i] or 0
					end
					for i = 1, 50 do
						if save.mission_bests['mission' .. i] == nil then
							save.mission_bests['mission' .. i] = 0
						end
					end
					save.author_name = ''
					save.exported_mission = false
					updatecheevos()
				end
			elseif vars.selections[vars.selection] == "flashing" then
				save.flashing += 1
				if save.flashing > 3 then
					save.flashing = 1
				end
				playsound(assets.sfx_select)
			elseif vars.selections[vars.selection] == "olddelay" then
				save.flash_int += 1
				if save.flash_int > 2 then
					save.flash_int = 1
				end
				playsound(assets.sfx_select)
			end
			playsound(assets.sfx_select)
		end,
	}
	pd.timer.performAfterDelay(scenemanager.transitiontime, function()
		pd.inputHandlers.push(vars.optionsHandlers)
		vars.selection = 1
	end)

	vars.anim_stars_small_x.repeats = true
	vars.anim_stars_small_y.repeats = true
	vars.anim_stars_large_x.repeats = true
	vars.anim_stars_large_y.repeats = true
	vars.anim_fg_hexa.reverses = true
	vars.anim_fg_hexa.repeats = true

	gfx.sprite.setBackgroundDrawingCallback(function(x, y, width, height)
		assets.stars_small:draw(vars.anim_stars_small_x.value, vars.anim_stars_small_y.value)
		assets.stars_large:draw(vars.anim_stars_large_x.value, vars.anim_stars_large_y.value)
		gfx.setDitherPattern(0.25, gfx.image.kDitherTypeBayer2x2)
		gfx.fillRect(0, 0, 400, 240)
		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)

		local offsetY = math.floor((12 - #vars.selections) / 2)

		for i = 1, #vars.selections do
			if i == vars.selection then
				font_style = 'full_circle'
			else
				font_style = 'half_circle'
			end

			assets[font_style]:drawTextAligned(
				options:selectionText(vars.selections[i]),
				190,
				((offsetY + (i - 1)) * 20) - 10,
				kTextAlignment.center
			)
		end

		assets.half_circle:drawText('v' .. pd.metadata.version, 65, 205)
		assets.half_circle:drawText(text('move') .. ' ' .. text('toggle'), 70, 220)
		gfx.setImageDrawMode(gfx.kDrawModeCopy)
		assets.fg:draw(0, 0)
		assets.fg_hexa_1:draw(0, vars.anim_fg_hexa.value)
		assets.fg_hexa_2:draw(0, vars.anim_fg_hexa.value * 1.2)
	end)

	self:add()
end

function options:selectionText(selection)
	if selection == 'lang' then
		return text('options_lang') .. text(save.lang)
	elseif selection == 'music' then
		return text('options_music') .. tostring(save.music)
	elseif selection == 'sfx' then
		return text('options_sfx') .. tostring(save.sfx)
	elseif selection == "flip" then
		return text('options_flip') .. text(tostring(save.flip))
	elseif selection == "crank" then
		return text('options_crank') .. text(tostring(save.sensitivity))
	elseif selection == "skipfanfare" then
		return text('options_skipfanfare') .. text(tostring(save.skipfanfare))
	elseif selection == "hardmode" then
		return text('options_hardmode') .. text(tostring(save.hardmode))
	elseif selection == "flashing" then
		return text('options_flashing') .. text(tostring(vars.flashing_text[save.flashing]))
	elseif selection == "olddelay" then
		return text('options_olddelay') .. text(tostring(vars.olddelay_text[save.flash_int]))
	elseif selection == "reset" then
		return text('options_reset_' .. vars.resetprogress)
	end
end

function options:update()
	local ticks = pd.getCrankTicks(6)
	if ticks ~= 0 and vars.selection > 0 then
		if vars.resetprogress > 1 then
			vars.resetprogress = 1
		end
		playsound(assets.sfx_move)
		vars.selection += ticks
		if vars.selection < 1 then
			vars.selection = #vars.selections
		elseif vars.selection > #vars.selections then
			vars.selection = 1
		end
	end
end
