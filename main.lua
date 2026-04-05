function _G.log(...)
	local texts = {...}
	local file = fs.open("log.txt", "a")
	for i, v in ipairs(texts) do
		if type(v) == "table" and type(v) ~= "thread" then
			v = textutils.serialise(v)
		else
			v = tostring(v)
		end
		file.write(v.."; ")
	end
	file.write("\n")
	file.close()
end

package.path = package.path .. ";/Data/?" .. ";/Data/?.lua"


local UI = require "UI"
local blittle = require "blittle_extended"
local speaker = require "Speaker"
local Chess = require "Chess"
local inspector = require "inspector"

local userSettings = 'Data/user.json'
local file, user

if fs.exists(userSettings) then
	file = fs.open(userSettings, 'r')
	user = file.readAll()
else
	local data = '{"Volume":15,"Nickname":"Unknown","OutputDevice":""}'
	file = fs.open(userSettings, 'w')
	file.write(data)
	user = data
end
file.close()
file = nil
user = textutils.unserialiseJSON(user)

local function saveUserSettings()
	local file = fs.open('Data/user.json', 'w')
	file.write(textutils.serialiseJSON(user))
	file.close()
end

local ret, newOut = speaker.setOutput(user.OutputDevice)
if not ret then
	user.OutputDevice = newOut
	saveUserSettings()
end

local root = UI.Root()
local surface = UI.Box{ x = 1, y = 1, w = root.w, h = root.h, bc = colors.black }
root:addChild(surface)

local CELL_W = 3
local BOARD_W = 26 -- 1 left rank + 8*3 board + 1 right rank
local BOARD_H = 10 -- top files + 8 ranks + bottom files
local BOARD_BG_A = colors.orange
local BOARD_BG_B = colors.brown
local CAPTURE_BG = colors.red
local SEL_BG = colors.green
local BOARD_ORIENTATION = false
local sounds = {
	['move'] = 'Data/sounds/chess_move',
	['capture'] = 'Data/sounds/chess_capture',
	['checkmate'] = 'Data/sounds/chess_checkmate',
}
local VOLUMES = {}
for i = 0, 14 do
	VOLUMES[i + 1] = i/14*3
end

local were, web

local function send(to, message)
	if type(message) == 'table' then
		to.send(textutils.serialiseJSON(message))
	elseif type(message) == 'string' then
		to.send(message)
	end
end

local function settingsMenu()
	local settings = UI.Box{x = 1, y = 1, w = root.w, h = root.h, bc = surface.bc}
	surface:addChild(settings)

	local Settings_Label = UI.Label{x = math.floor((root.w - 8)/2) + 1, y = 2, w = 8, h = 1, text = 'SETTINGS', bc = settings.bc, fc = colors.white}
	settings:addChild(Settings_Label)

	local Sound_Label = UI.Label{x = 6, y = 4, w = 5, h = 1, text = 'Sound', bc = settings.bc, fc = colors.white}
	settings:addChild(Sound_Label)

	local VOutput_Label = UI.Label{x = 6, y = Sound_Label.y + 2, w = 13, h = 1, text = 'Output device', bc = settings.bc, fc = colors.lightGray}
	settings:addChild(VOutput_Label)

	local VOutput_Dropdown = UI.Dropdown{x = VOutput_Label.x + VOutput_Label.w + 1, y = VOutput_Label.y, bc = colors.white, fc = colors.black, array = speaker.getOutputs(), defaultValue = (user.OutputDevice ~= "") and user.OutputDevice or nil}
	settings:addChild(VOutput_Dropdown)
	VOutput_Dropdown.pressed = function (self, element)
		user.OutputDevice = element
		saveUserSettings()
	end

	local Volume_Label = UI.Label{x = 6, y = VOutput_Label.y + 2, w = 6, h = 1, text = 'Volume', bc = settings.bc, fc = colors.lightGray}
	settings:addChild(Volume_Label)

	local Volume_Slider = UI.Slider{x = Volume_Label.x + Volume_Label.w + 8, y = Volume_Label.y, w = 15, bc = settings.bc, fc = colors.white, fc_alt = colors.blue, bc_alt = colors.lightGray, fc_cl = colors.gray, arr = VOLUMES, slidePosition = user.Volume}
	settings:addChild(Volume_Slider)
	Volume_Slider.pressed = function (self)
		user.Volume = self.slidePosition
		saveUserSettings()
		speaker.setVolume(self.arr[self.slidePosition])
	end

	local Interface_Label = UI.Label{x = 6, y = Volume_Label.y + 3, w = 9, h = 1, text = 'Interface', bc = settings.bc, fc = colors.white}
	settings:addChild(Interface_Label)

	local Scheme_Label = UI.Label{x = 6, y = Interface_Label.y + 2, w = 12, h = 1, text = 'Color Scheme', bc = settings.bc, fc = colors.lightGray}
	settings:addChild(Scheme_Label)

	local Piece_Label = UI.Label{x = 6, y = Scheme_Label.y + 2, w = 12, h = 1, text = 'Piece Scheme', bc = settings.bc, fc = colors.lightGray}
	settings:addChild(Piece_Label)

	local BTN_Exit = UI.Button{x = 2, y = 2, w = 3, h = 1, text = '\27', bc = colors.gray, fc = colors.white}
	settings:addChild(BTN_Exit)
	BTN_Exit.pressed = function (self)
		surface:removeChild(settings)
		surface:removeChild(Settings_Label)
		surface:removeChild(Sound_Label)
		surface:removeChild(VOutput_Label)
		surface:removeChild(VOutput_Dropdown)
		surface:removeChild(Volume_Label)
		surface:removeChild(Interface_Label)
		surface:removeChild(Scheme_Label)
		surface:removeChild(Piece_Label)
		surface:removeChild(self)
		surface:onLayout()
	end
	local oldOnResize = surface.onResize
	surface.onResize = function (width, height)
		oldOnResize(width, height)
		settings.w, settings.h = width, height
		Settings_Label.local_x = math.floor((root.w - 8)/2) + 1
	end
end

local function aboutMenu()
	local about = UI.Box{x = 1, y = 1, w = root.w, h = root.h, bc = surface.bc}
	surface:addChild(about)

	local About_Label = UI.Label{x = math.floor((root.w - 8)/2) + 1, y = 2, w = 8, h = 1, text = 'ABOUT', bc = about.bc, fc = colors.white}
	about:addChild(About_Label)

	local BTN_Exit = UI.Button{x = 2, y = 2, w = 3, h = 1, text = '\27', bc = colors.gray, fc = colors.white}
	surface:addChild(BTN_Exit)
	BTN_Exit.pressed = function (self)
		surface:removeChild(about)
		surface:removeChild(About_Label)
		surface:removeChild(self)
		surface:onLayout()
	end
end

local mainMenu = function () end

local function startGame(team, FEN)
	were = 'InGame'
	surface:removeChild(true)
	local opponent = web and web.nickname
	if web and web.server then
		for _,v in pairs(web.clients) do
			opponent = v.nickname
		end
	end

	local list, msgLabel

	local boardUI = Chess.Board{ x = math.floor((root.w - 16 - BOARD_W)/2) + 1, y = math.floor((root.h - BOARD_H)/2) + 1, w = BOARD_W, h = BOARD_H, bc = colors.black, fc = colors.lightGray, bc_alt = colors.orange }
	surface:addChild(boardUI)
	boardUI.pressed = function (self, from, to)
		list:onMouseScroll(math.max(0, #list.array - list.h))
		list.dirty = true
		if not web then return end
		local message = {type = 'chess_move', from = from, to = to}
		if web.server then
			for _,v in pairs(web.clients) do
				send(v, message)
			end
		else
			send(web, message)
		end
	end
	boardUI.rotate = (team == 'w')

	local game = Chess.Game(boardUI.board)
	game.team = web and team
	if FEN ~= '' then game:loadFEN(FEN)
	else game:setDefaultPieces() end
	game:updateGameEnd()
	boardUI.game = game
	game.playSound = function (self, status)
		speaker.playFile(sounds[status])
	end
	game.refreshStatus = function(self)
		msgLabel:setText(self.message)
	end

	local BTN_Exit = UI.Button{x = 2, y = 2, w = 3, h = 1, text = '\27', bc = colors.gray, fc = colors.white}
	surface:addChild(BTN_Exit)
	BTN_Exit.pressed = function (self)
		if not web then return mainMenu() end
		if web.server then
			for _, v in pairs(web.clients) do
				v.close()
			end
			mainMenu()
		end
		web.close()
	end

	local BTN_Settings = UI.Button{x = BTN_Exit.x + BTN_Exit.w + 1, y = BTN_Exit.y, w = 3, h = 1, text = '\164', bc = colors.gray, fc = colors.white}
	surface:addChild(BTN_Settings)
	BTN_Settings.pressed = function (self)
		settingsMenu()
	end

	msgLabel = UI.Label{x = BTN_Settings.x + BTN_Settings.w + 1, y = BTN_Settings.y, w = root.w - (BTN_Settings.x + BTN_Settings.w + 1), h = 1, fc = colors.lightGray, bc = surface.bc, align = 'right'}
	surface:addChild(msgLabel)

	local panel = UI.Box{x = root.w - 15, y = math.floor((root.h - 9)/2), w = 16, h = 9, bc = colors.gray, fc = colors.white}
	surface:addChild(panel)

	local player1 = UI.Label{x = 1, y = 1, w = panel.w, h = 1, bc = panel.bc, fc = panel.fc, text = "\4 "..user.Nickname, align = "left"}
	panel:addChild(player1)

	local player2 = UI.Label{x = 1, y = panel.h, w = panel.w, h = 1, bc = panel.bc, fc = panel.fc, text = opponent and "\4 ".. opponent or "\4 Unknown", align = "left"}
	panel:addChild(player2)

	list = UI.List{x = 1, y = 2, w = panel.w, h = panel.h - 2, bc = colors.gray, fc = colors.lightGray, array = game.history}
	panel:addChild(list)
	list.onMouseDown = function(self, btn, x, y) end

	local rev = UI.Button{x = panel.x, y = panel.y + panel.h, w = 3, h = 1, text = '\18', fc = colors.white, bc = colors.gray}
	surface:addChild(rev)
	rev.pressed = function()
		boardUI.rotate = not boardUI.rotate
		boardUI.dirty = true
		-- surface:onLayout()
	end

	local offerdraw = UI.Button{x = rev.x + rev.w, y = rev.y, w = 3, h = 1, bc = colors.lightGray, fc = panel.fc, text = "\189", align = "center"}
	surface:addChild(offerdraw)
	offerdraw.pressed = function (self)
		if not web then return end
		local message = {type = 'game_offerdraw', team = web.team}
		if web.server then
			for _,v in pairs(web.clients) do
				send(v, message)
			end
		else
			send(web, message)
		end
	end

	local resign = UI.Button{x = offerdraw.x + offerdraw.w, y = offerdraw.y, w = 10, h = 1, bc = colors.gray, fc = panel.fc, text = web and "Resign" or 'Restart', align = "center"}
	surface:addChild(resign)
	resign.pressed = function (self)
		if game.over then return end
		if not web then
			game:restartGame()
			list:updateArr(game.history)
			surface:onLayout()
			return
		end

		local message = {type = 'game_resign'}
		if web.server then
			for _,v in pairs(web.clients) do
				send(v, message)
			end
		else
			send(web, message)
		end
		game.message = (team == 'w') and 'Black wins by resignation' or 'White wins by resignation'
		game.over = true
		-- game:updateMessage()
	end

	local FEN_textfield, FEN_Btn
	if not web then
		FEN_textfield = UI.Textfield{x = 2, y = surface.h - 1, w = surface.w - 6, h = 1, hint = "Type FEN", fc = colors.white, bc = colors.gray}
		surface:addChild(FEN_textfield)

		FEN_Btn = UI.Button{x = root.w - 3, y = FEN_textfield.y, w = 3, h = 1, text = ">", fc = colors.white, bc = colors.gray}
		surface:addChild(FEN_Btn)
		FEN_Btn.pressed = function (self)
			if FEN_textfield.text then
				game:loadFEN(FEN_textfield.text)
				boardUI.dirty = true
			end
		end
	else
		web.moveFromTo = function (from, to)
			-- log('popali')
			local fx = math.floor(from / 10)
			local fy = from % 10

			local tx = math.floor(to / 10)
			local ty = to % 10

			boardUI:selectSquare(fx, fy)
			game:moveSelectedTo(tx, ty, boardUI.selected)
			boardUI.selected = nil
			list:onMouseScroll(math.max(0, #list.array - list.h))
			list.dirty = true
		end
		web.game = game
	end

	-- local opponent, list
	-- if ws or client then
	-- 	opponent = ws or client
	-- end
	-- if type(userReady) == 'boolean' then userReady = nil end
	game:refreshStatus()

	surface.onResize = function(width, height)
		surface.w, surface.h = width, height
		boardUI.local_y = math.floor((height - 10) / 2) + 1
		boardUI.local_x = math.floor((width - 16 - 26)/2) + 1
		panel.local_x = width - 15
		panel.local_y = math.floor((height - 9)/2)
		if not web then
			FEN_textfield.local_y, FEN_textfield.w = height - 1, width - 6
			FEN_Btn.local_x, FEN_Btn.local_y = width - 3, height - 1
		end
		rev.local_x, rev.local_y = panel.local_x, panel.local_y + panel.h
		offerdraw.local_x, offerdraw.local_y = rev.local_x + rev.w, rev.local_y
		resign.local_x, resign.local_y = offerdraw.local_x + offerdraw.w, offerdraw.local_y
		msgLabel.w = width - (BTN_Settings.local_x + BTN_Settings.w + 1)
	end

	surface:onLayout()
	-- updateGameEnd()
	-- restartGame()
	-- list:updateArr(state.history)

end

local function toArr(json)
	return textutils.unserialiseJSON(json)
end

local function Lobby()
	were = 'Lobby'
	surface:removeChild(true)

	local BTN_Exit = UI.Button{x = 2, y = 2, w = 3, h = 1, bc = colors.gray, fc = colors.white, text = '\27'}
	surface:addChild(BTN_Exit)
	BTN_Exit.pressed = function (self)
		if web.server then
			for _, v in pairs(web.clients) do
				v.close()
			end
			mainMenu()
		end
		web.close()
	end

	local BTN_Settings = UI.Button{x = root.w - 3, y = BTN_Exit.y, w = 3, h = 1, text = '\164', bc = colors.gray, fc = colors.white}
	surface:addChild(BTN_Settings)
	BTN_Settings.pressed = function (self)
		settingsMenu()
	end

	local Lobby_Label = UI.Label{x = 2 + 4, y = 2, w = 5, h = 1, bc = surface.bc, fc = colors.white, text = 'Lobby'}
	surface:addChild(Lobby_Label)

	local player1 = UI.Label{x = 8, y = math.floor((root.h - 1)/2) + 1, w = 20, h = 1, text = user.Nickname, bc = colors.gray, fc = colors.white, align = "left"}
	surface:addChild(player1)

	local Label_Team = UI.Label{x = 6, y = player1.y, w = 2, h = 1, text = '\7', bc = player1.bc, fc = colors.white, align = 'left'}
	surface:addChild(Label_Team)

	local Radio_Team = UI.RadioButton{x = root.w - 7, y = player1.y, bc = surface.bc, fc = colors.white, text = {'White', 'Black'}}
	surface:addChild(Radio_Team)
	local oldMouseUp = Radio_Team.onMouseUp
	Radio_Team.onMouseUp = function (self, btn, x, y)
		if web.ready then return true end
		return oldMouseUp(self, btn, x, y)
	end

	local BTN_Ready = UI.Button{x = root.w - 9, y = root.h - 2, w = 9, h = 1, bc = colors.gray, fc = colors.white, text = "Ready"}
	surface:addChild(BTN_Ready)

	local BTN_Play, Label_Fen, TF_Fen

	if web.server then
		BTN_Play = UI.Button{x = BTN_Ready.x - 4, y = BTN_Ready.y, w = 3, h = 1, bc = colors.gray, fc = colors.white, text = "\16"}
		surface:addChild(BTN_Play)
		BTN_Play.pressed = function (self)
			local count = 0
			for _, v in pairs(web.clients) do
				count = count + 1
			end
			if count == 0 then return end
			if not web.ready then return end
			for _, v in pairs(web.clients) do
				if not v.ready then return end
				if v.team == web.team then return end
			end
			local message = {type = 'start_game', fen = TF_Fen.text}
			for _, v in pairs(web.clients) do
				send(v, message)
			end
			startGame(web.team, TF_Fen.text)
		end

		Label_Fen = UI.Label{x = root.w - 20, y = 4, w = 4, h = 1, text = 'FEN:', bc = surface.bc, fc = colors.white, align = 'left'}
		surface:addChild(Label_Fen)

		TF_Fen = UI.Textfield{x = Label_Fen.x + Label_Fen.w + 1, y = 4, w = 15, h = 1, bc = colors.gray, fc = colors.white, hint = 'FEN'}
		surface:addChild(TF_Fen)
	end

	Radio_Team.pressed = function (self, i)
		if web.ready then return end

		if i == 'White' then Label_Team.fc = colors.white
		elseif i == 'Black' then Label_Team.fc = colors.black
		end
		web.team = i == 'White' and 'w' or 'b'
		Label_Team.dirty = true
		local message = {type = 'lobby_update', ready = web.ready, team = web.team, nickname = user.Nickname}
		if web.server then
			for _, v in pairs(web.clients) do
				send(v, message)
			end
		else
			send(web, message)
		end
	end

	BTN_Ready.pressed = function (self)
		web.ready = not web.ready
		if web.ready then
			self:setText('Unready')
			player1.bc = colors.green
			Label_Team.bc = colors.green
		else
			self:setText('Ready')
			player1.bc = colors.gray
			Label_Team.bc = colors.gray
		end
		player1.dirty = true
		Label_Team.dirty = true
		-- surface:onLayout()
		local message = {type = 'lobby_update', ready = web.ready, team = web.team, nickname = user.Nickname}
		if web.server then
			for _, v in pairs(web.clients) do
				send(v, message)
			end
		else
			send(web, message)
		end
	end

	surface.onResize = function (width, height)
		surface.w, surface.h = width, height
		Label_Team.local_x = 6
		player1.local_x = 8
		Radio_Team.local_x = width - 7
		-- Radio_Team.local_y = player1.local_y
		BTN_Ready.local_x = width - 9
		BTN_Ready.local_y = height - 2
		BTN_Settings.local_x, BTN_Settings.local_y = width - 3,BTN_Exit.local_y
		if BTN_Play then
			Label_Fen.local_x = width - 20
			TF_Fen.local_x = Label_Fen.local_x + Label_Fen.w + 1
			BTN_Play.local_x = BTN_Ready.local_x - 4
			BTN_Play.local_y = BTN_Ready.local_y
		end
	end
	-- if host then


	surface:onLayout()
end

local function JoinMenu()
	were = 'JoinMenu'
	surface:removeChild(true)
	local IP_TextField

	local BTN_Exit = UI.Button{x = 2, y = 2, w = 3, h = 1, bc = colors.gray, fc = colors.white, text = '\27'}
	surface:addChild(BTN_Exit)

	BTN_Exit.pressed = function (self)
		mainMenu()
	end
	local BTN_L = UI.Button{x = 6, y = 2, w = 1, h = 1, bc = colors.gray, fc = colors.white, text = 'L'}
	surface:addChild(BTN_L)
	BTN_L.pressed = function (self)
		IP_TextField.text = 'localhost'
		IP_TextField.dirty = true
	end

	local BTN_V = UI.Button{x = 8, y = 2, w = 1, h = 1, bc = colors.gray, fc = colors.white, text = 'V'}
	surface:addChild(BTN_V)
	BTN_V.pressed = function (self)
		IP_TextField.text = '192.168.191.153'
		IP_TextField.dirty = true
	end

	local BTN_A = UI.Button{x = 10, y = 2, w = 1, h = 1, bc = colors.gray, fc = colors.white, text = 'A'}
	surface:addChild(BTN_A)
	BTN_A.pressed = function (self)
		IP_TextField.text = '192.168.191.87'
		IP_TextField.dirty = true
	end

	local IP_Label = UI.Label{x = math.floor((root.w - 26)/2) + 1, y = math.floor((root.h - 2)/2) + 1, h = 1, w = 10, text = 'IP Adress:', bc = surface.bc, fc = colors.white}
	surface:addChild(IP_Label)

	local Error_Label = UI.Label{x = 1, y = IP_Label.y - 2, h = 1, w = root.w, text = '', bc = surface.bc, fc = colors.white}
	surface:addChild(Error_Label)

	IP_TextField = UI.Textfield{x = IP_Label.x + IP_Label.w + 1, y = IP_Label.y, w = 16, h = 1, hint = "Type server ip", bc = colors.gray, fc = colors.white}
	IP_TextField.text = '192.168.191.153'
	surface:addChild(IP_TextField)

	local BTN_Connect = UI.Button{x = math.floor((root.w - 7)/2) + 1, y = IP_Label.y + 2, w = 9, h = 1, bc = colors.gray, fc = colors.white, text = 'Connect'}
	surface:addChild(BTN_Connect)

	BTN_Connect.pressed = function (self)
		local err
		web, err = http.websocket("ws://"..IP_TextField.text..":22856")
		if not web then
			Error_Label.fc = colors.red
			Error_Label:setText(err)
			return
		end
		web.team = 'w'
		web.ready = false
		send(web, {type = 'lobby_join', nickname = user.Nickname, ready = false, team = web.team})
		Lobby()
	end

	surface.onResize = function(width, height)
		surface.w, surface.h = width, height
		IP_Label.local_x, IP_Label.local_y = math.floor((width - 26)/2) + 1, math.floor((height - 2)/2) + 1
		IP_TextField.local_x, IP_TextField.local_y = IP_Label.local_x + IP_Label.w + 1, IP_Label.local_y
		BTN_Connect.local_x, BTN_Connect.local_y = math.floor((root.w - 7)/2) + 1, IP_Label.local_y + 2
	end

	surface:onLayout()
end

function mainMenu()
	were = 'MainMenu'
	surface:removeChild(true)

	local logo_img = blittle.load("Data/logo.ico")

	local logo = UI.Box{x = math.floor((root.w - 6)/2) + 1, y = 3, w = 6, h = 5, bc = colors.black}
	surface:addChild(logo)

	logo.draw = function (self)
		blittle.draw(logo_img, self.x, self.y)
	end

	local Nickname_L = UI.Label{x = 1, y = 1, w = 10, h = 1, bc = surface.bc, fc = colors.white, text = "Nickname: "}
	surface:addChild(Nickname_L)

	local Nickname = UI.Textfield{x = Nickname_L.x + Nickname_L.w, y = 1, w = 10, h = 1, bc = colors.gray, fc = colors.white}
	Nickname.text = user.Nickname
	local oldCharType = Nickname.onCharTyped
	Nickname.onCharTyped = function (self, char)
		local ret = oldCharType(self, char)
		user.Nickname = self.text
		saveUserSettings()
		return ret
	end
	surface:addChild(Nickname)

	local center = math.floor((root.w - 14)/2)+1
	local BTN_Create = UI.Button{x = center, y = logo.y + logo.h + 1, w = 8, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Create"}
	surface:addChild(BTN_Create)
	BTN_Create.pressed = function ()
		web = http.websocketServer(22856)
		web.server = true
		web.clients = {}
		web.team = 'w'
		Lobby()
	end

	local BTN_Join = UI.Button{x = center + 9, y = logo.y + logo.h + 1, w = 6, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Join", bc_hc = colors.lightGray, fc_hc = colors.black}
	surface:addChild(BTN_Join)
	BTN_Join.pressed = function ()
		JoinMenu()
	end

	local BTN_LocalGame = UI.Button{x = center, y = logo.y + logo.h + 3, w = 15, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Local Game", bc_hc = colors.lightGray, fc_hc = colors.black}
	surface:addChild(BTN_LocalGame)
	BTN_LocalGame.pressed = function (self)
		startGame('w', '')
	end

	local BTN_Settings = UI.Button{x = center, y = BTN_LocalGame.y + 2, w = 15, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Settings", bc_hc = colors.lightGray, fc_hc = colors.black}
	surface:addChild(BTN_Settings)
	BTN_Settings.pressed = function (self)
		settingsMenu()
	end

	local BTN_Quit = UI.Button{x = center, y = BTN_Settings.y + 2, w = 15, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Quit", bc_hc = colors.lightGray, fc_hc = colors.black}
	surface:addChild(BTN_Quit)
	BTN_Quit.pressed = function (self)
		os.queueEvent('terminate')
	end

	local Version_Label = UI.Label{x = 1, y = root.h, w = root.w, h = 1, bc = surface.bc, fc = colors.gray, text = "Ver. 26W05.7", align = "left"}
	surface:addChild(Version_Label)

	local BTN_About = UI.Button{x = root.w - 3, y = 2, w = 3, h = 1, bc = colors.gray, fc = colors.white, text = "?"}
	surface:addChild(BTN_About)
	BTN_About.pressed = function (self)
		aboutMenu()
	end

	surface.onResize = function(width, height)
		surface.w, surface.h = width, height
		local cenetr = math.floor((width - 14)/2) + 1
		logo.local_x = math.floor((width - 6)/2) + 1
		BTN_Create.local_x = cenetr
		BTN_Join.local_x = cenetr + 9
		BTN_Quit.local_x = cenetr
		BTN_LocalGame.local_x, BTN_LocalGame.local_y = cenetr, logo.local_y + logo.h + 3
		BTN_Settings.local_x, BTN_Settings.local_y = cenetr, BTN_LocalGame.local_y + 2
		Version_Label.local_y, Version_Label.w = height, width
		BTN_About.local_x = width - 3
	end

	surface:onLayout()
end

function root.custom_handlers.websocket_server_connect(port, arr)
	web.clients[arr.clientID] = arr

	-- log(inspector.returnArr(web))
	return true
end
function root.custom_handlers.websocket_server_message(userdata, string, bool)
	local client = web.clients[userdata]
	local recieve = toArr(string)
	local Type = recieve.type

	if Type == 'lobby_join' and were == 'Lobby' then
		if not client.player then
			local bc = recieve.ready and colors.green or colors.gray
			client.player = UI.Label{x = 8, y = math.floor((root.h - 1)/2) + 3, w = 20, h = 1, text = recieve.nickname, bc = bc, fc = colors.white, align = "left"}
			surface:addChild(client.player)
			client.label_team = UI.Label{x = 6, y = client.player.y, w = 2, h = 1, text = '\7', bc = client.player.bc, fc = colors.white, align = 'left'}
			surface:addChild(client.label_team)
			surface:onLayout()
		end
		send(client, {type = 'lobby_update', nickname = user.Nickname, ready = web.ready, team = web.team})
	elseif Type == 'lobby_update' and were == 'Lobby' then
		if recieve.team == 'w' then
			client.label_team.fc = colors.white
		elseif recieve.team == 'b' then
			client.label_team.fc = colors.black
		end
		if recieve.ready then
			client.player.bc = colors.green
			client.label_team.bc = colors.green
		else
			client.player.bc = colors.gray
			client.label_team.bc = colors.gray
		end
		client.team = recieve.team
		client.ready = recieve.ready
		client.nickname = recieve.nickname
		client.player.dirty = true
		client.label_team.dirty = true
	elseif Type == 'chess_move' then
		web.moveFromTo(recieve.from, recieve.to)
	elseif Type == 'game_resign' then
		web.game.message = (client.team == 'w') and 'Black wins by resignation' or 'White wins by resignation'
		web.game.over = true
		-- web.game:updateMessage()
	elseif Type == 'game_offerdraw' then
		if recieve.message then
			web.game.message = 'Draw.'
			web.game.over = true
			-- web.game:updateMessage()
			return
		end
		local msgLabel, Yes, No
		local team = web.team == 'w' and 'White' or 'Black'
		msgLabel = UI.Label{x = math.floor((root.w - 25)/2) + 1, y = root.h - 1, w = 17, h = 1, text = team .. ' offers draw', bc = surface.bc, fc = colors.white}
		surface:addChild(msgLabel)
		Yes = UI.Button{x = msgLabel.x + msgLabel.w + 1, y = root.h - 1, w = 3, h = 1, text = 'Y', bc = colors.green, fc = colors.white}
		surface:addChild(Yes)
		Yes.pressed = function (self)
			surface:removeChild(msgLabel)
			surface:removeChild(No)
			surface:removeChild(self)
			surface:onLayout()
			web.game.message = 'Draw.'
			web.game.over = true
			-- web.game:updateMessage()
			local message = {type = 'game_offerdraw', message = 'Yes', team = web.team}
			for _, v in pairs(web.clients) do
				send(v, message)
			end
		end
		No = UI.Button{x = Yes.x + Yes.w + 1, y = root.h - 1, w = 3, h = 1, text = 'N', bc = colors.red, fc = colors.white}
		surface:addChild(No)
		No.pressed = function (self)
			surface:removeChild(msgLabel)
			surface:removeChild(Yes)
			surface:removeChild(self)
			surface:onLayout()
		end
	end

	return true
end
function root.custom_handlers.websocket_server_closed(userdata)
	local client = web.clients[userdata]
	web.clients[userdata] = nil
	surface:removeChild(client.player)
	surface:removeChild(client.label_team)
	surface:onLayout()
	if were ~= 'InGame' then mainMenu() end
	return true
end
function root.custom_handlers.websocket_message(ip, message, bool)
	local recieve = toArr(message)
	local Type = recieve.type

	if Type == 'lobby_update' and were == 'Lobby' then
		if not web.player then
			local bc = recieve.ready and colors.green or colors.gray
			web.player = UI.Label{x = 8, y = math.floor((root.h - 1)/2) + 3, w = 20, h = 1, text = recieve.nickname, bc = bc, fc = colors.white, align = "left"}
			surface:addChild(web.player)
			web.label_team = UI.Label{x = 6, y = web.player.y, w = 2, h = 1, text = '\7', bc = web.player.bc, fc = colors.white, align = 'left'}
			surface:addChild(web.label_team)
			surface:onLayout()
		end
		if recieve.team == 'w' then
			web.label_team.fc = colors.white
		elseif recieve.team == 'b' then
			web.label_team.fc = colors.black
		end
		if recieve.ready then
			web.player.bc = colors.green
			web.label_team.bc = colors.green
		else
			web.player.bc = colors.gray
			web.label_team.bc = colors.gray
		end
		web.serverTeam = recieve.team
		web.ready = recieve.ready
		web.nickname = recieve.nickname
		web.player.dirty = true
		web.label_team.dirty = true
	elseif Type == 'start_game' then
		startGame(web.team, recieve.fen)
	elseif Type == 'chess_move' then
		web.moveFromTo(recieve.from, recieve.to)
	elseif Type == 'game_resign' then
		web.game.message = (web.team == 'w') and 'Black wins by resignation' or 'White wins by resignation'
		web.game.over = true
		-- web.game:updateMessage()
	elseif Type == 'game_offerdraw' then
		if recieve.message then
			web.game.message = 'Draw.'
			web.game.over = true
			-- web.game:updateMessage()
			return
		end
		local msgLabel, Yes, No
		local team = web.team == 'w' and 'White' or 'Black'
		msgLabel = UI.Label{x = math.floor((root.w - 25)/2) + 1, y = root.h - 1, w = 17, h = 1, text = team .. ' offers draw', bc = surface.bc, fc = colors.white}
		surface:addChild(msgLabel)
		Yes = UI.Button{x = msgLabel.x + msgLabel.w + 1, y = root.h - 1, w = 3, h = 1, text = 'Y', bc = colors.green, fc = colors.white}
		surface:addChild(Yes)
		Yes.pressed = function (self)
			surface:removeChild(msgLabel)
			surface:removeChild(No)
			surface:removeChild(self)
			surface:onLayout()
			web.game.message = 'Draw.'
			web.game.over = true
			-- web.game:updateMessage()
			send(web, {type = 'game_offerdraw', message = 'Yes', team = web.team})
		end
		No = UI.Button{x = Yes.x + Yes.w + 1, y = root.h - 1, w = 3, h = 1, text = 'N', bc = colors.red, fc = colors.white}
		surface:addChild(No)
		No.pressed = function (self)
			surface:removeChild(msgLabel)
			surface:removeChild(Yes)
			surface:removeChild(self)
			surface:onLayout()
		end
	end

	return true
end
function root.custom_handlers.websocket_closed(ip, message, key)
	surface:removeChild(web.player)
	surface:removeChild(web.label_team)
	web = nil
	if were ~= 'InGame' then mainMenu() end
	return true
end

mainMenu()

root:show()
while true do
	local evt = {coroutine.yield()}
	if evt[1] == "terminate" then
		-- if web then
		-- 	if web.server then
		-- 		for _, v in pairs(web.clients) do
		-- 			v.close()
		-- 		end
		-- 		mainMenu()
		-- 	end
		-- 	web.close()
		-- end
		term.setBackgroundColor(colors.black)
		term.setTextColor(colors.white)
		term.setCursorPos(1,1)
		term.clear()
		break
	end
	root:onEvent(evt)
end
