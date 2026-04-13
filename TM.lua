local UI = require "UI"
local blittle = require "blittle_extended"
local speaker = require "Speaker"
local Screen = require "ScreenManager"
local Chess = require "Chess"
local network = require "Network"
local inspector = require "inspector"
local sha = require "sha2"

local port = 22856
local userSettings = 'Data/user.json'
local file, user

if fs.exists(userSettings) then
	file = fs.open(userSettings, 'r')
	user = file.readAll()
else
	local data = '{"Volume":15,"Nickname":"Unknown","OutputDevice":"","Language":"eng","ColorScheme":"Default","ServerType":"Rednet"}'
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

if http and not http.websocketServer then
	user.ServerType = 'Rednet'
end

local PIECE_SCHEME = {
	Letters = function()
		Chess.pieceGlyph.tr = 'R'
		Chess.pieceGlyph.tk = 'K'
		Chess.pieceGlyph.tn = 'N'
		Chess.pieceGlyph.tq = 'Q'
		Chess.pieceGlyph.tp = 'P'
		Chess.pieceGlyph.tb = 'B'
	end,
	Symbols = function()
		Chess.pieceGlyph.tr = "\207"
		Chess.pieceGlyph.tk = "\214"
		Chess.pieceGlyph.tn = "\163"
		Chess.pieceGlyph.tq = "\5"
		Chess.pieceGlyph.tp = "\105"
		Chess.pieceGlyph.tb = "1"
	end,
}

local BOARD_BG = {
	Default = function()
		Chess.BOARD_BG_A = colors.orange
		Chess.BOARD_BG_B = colors.brown
		Chess.BOARD_FG_A = colors.white
		Chess.BOARD_FG_B = colors.black
		Chess.BOARD_BG_S = colors.green
		Chess.BOARD_BG_T = colors.red
	end,

	Ocean = function()
		Chess.BOARD_BG_A = colors.lightBlue
		Chess.BOARD_BG_B = colors.lightGray
		Chess.BOARD_FG_A = colors.white
		Chess.BOARD_FG_B = colors.black
		Chess.BOARD_BG_S = colors.blue
		Chess.BOARD_BG_T = colors.red
	end,

	Forest = function()
		Chess.BOARD_BG_A = colors.lime
		Chess.BOARD_BG_B = colors.green
		Chess.BOARD_FG_A = colors.white
		Chess.BOARD_FG_B = colors.black
		Chess.BOARD_BG_S = colors.yellow
		Chess.BOARD_BG_T = colors.red
	end,

	Desert = function()
		Chess.BOARD_BG_A = colors.yellow
		Chess.BOARD_BG_B = colors.orange
		Chess.BOARD_FG_A = colors.white
		Chess.BOARD_FG_B = colors.black
		Chess.BOARD_BG_S = colors.lightBlue
		Chess.BOARD_BG_T = colors.red
	end,

	Royal = function()
		Chess.BOARD_BG_A = colors.purple
		Chess.BOARD_BG_B = colors.magenta
		Chess.BOARD_FG_A = colors.white
		Chess.BOARD_FG_B = colors.black
		Chess.BOARD_BG_S = colors.cyan
		Chess.BOARD_BG_T = colors.red
	end,

	Night = function()
		Chess.BOARD_BG_A = colors.gray
		Chess.BOARD_BG_B = colors.black
		Chess.BOARD_FG_A = colors.white
		Chess.BOARD_FG_B = colors.lightGray
		Chess.BOARD_BG_S = colors.blue
		Chess.BOARD_BG_T = colors.red
	end,

	Candy = function()
		Chess.BOARD_BG_A = colors.pink
		Chess.BOARD_BG_B = colors.lightBlue
		Chess.BOARD_FG_A = colors.white
		Chess.BOARD_FG_B = colors.black
		Chess.BOARD_BG_S = colors.lime
		Chess.BOARD_BG_T = colors.red
	end,

	Volcano = function()
		Chess.BOARD_BG_A = colors.orange
		Chess.BOARD_BG_B = colors.red
		Chess.BOARD_FG_A = colors.white
		Chess.BOARD_FG_B = colors.black
		Chess.BOARD_BG_S = colors.yellow
		Chess.BOARD_BG_T = colors.lightGray
	end,

	Ice = function()
		Chess.BOARD_BG_A = colors.white
		Chess.BOARD_BG_B = colors.lightBlue
		Chess.BOARD_FG_A = colors.black
		Chess.BOARD_FG_B = colors.black
		Chess.BOARD_BG_S = colors.cyan
		Chess.BOARD_BG_T = colors.red
	end,

	Rust = function()
		Chess.BOARD_BG_A = colors.brown
		Chess.BOARD_BG_B = colors.orange
		Chess.BOARD_FG_A = colors.white
		Chess.BOARD_FG_B = colors.black
		Chess.BOARD_BG_S = colors.lime
		Chess.BOARD_BG_T = colors.red
	end,
}

Chess.CELL_W = 3
Chess.CELL_H = 1
Chess.T_DELTA_W = 1
Chess.T_DELTA_H = 1
Chess.BOARD_W = Chess.T_DELTA_W * 2 + 8 * Chess.CELL_W
Chess.BOARD_H = Chess.T_DELTA_H * 2 + 8 * Chess.CELL_H
BOARD_BG[user.ColorScheme]()
PIECE_SCHEME[user.PieceScheme]()

local root = UI.Root()
Screen.surface = root

local sounds = {
	['move'] = 'Data/sounds/chess_move',
	['capture'] = 'Data/sounds/chess_capture',
	['checkmate'] = 'Data/sounds/chess_checkmate',
}
local VOLUMES = {}
for i = 0, 14 do
	VOLUMES[i + 1] = i/14*3
end


local exeption = {
	['rom'] = true,
	['.git'] = true,
	['Data/user.json'] = true
}

local function write_file(path, data)
	-- local file = fs.open(path, 'w')
	-- file.write(data)
	-- file.close()
end

local function listAllFiles(path, array)
	local files = fs.list(path)
	
	for _, file in ipairs(files) do
		local fullPath = fs.combine(path, file)
		
		if fs.isDir(fullPath) then
			if not exeption[fullPath] then listAllFiles(fullPath, array) end
		else
			if not exeption[fullPath] then
				local file = fs.open(fullPath, 'r')
				array[fullPath] = sha.sha256(file.readAll())
				file.close()
				-- log(fullPath)
			end
		end
	end
end

local function userFiles()
	local files = {}
	listAllFiles('', files)

	return files
end

local function checkUpdates(shaSum)
	local ret = false
	local filesToUpdate = {}
	local userList = userFiles()
	local hashList = {}
	for line in shaSum:gmatch('([^\n]+)\n?') do
		local hash = line:sub(1, 64)
		local path = line:sub(66)
		hashList[path] = hash
	end
	for path, hash in pairs(userList) do
		if not hashList[path] then
			-- log('deletE:' .. path)
			-- fs.delete(path)
			ret = true
		end
	end
	for path, hash in pairs(hashList) do
		if not userList[path] or userList[path] ~= hash then
			table.insert(filesToUpdate, path)
		end
	end
	return ret, filesToUpdate
end

local SettingsMenu = {}
function SettingsMenu.new()
	local page = {}

	page.surface = UI.Box{x = 1, y = 1, w = root.w, h = root.h, bc = colors.black}
	root:addChild(page.surface)

	page.btnExit = UI.Button{x = 2, y = 2, w = 3, h = 1, text = '\27', bc = colors.gray, fc = colors.white}
	page.surface:addChild(page.btnExit)
	page.btnExit.pressed = function (self)
		saveUserSettings()
		Screen:closeModal()
	end

	page.labelSettings = UI.Label{x = math.floor((root.w - 8)/2) + 1, y = 2, w = 8, h = 1, text = 'SETTINGS', bc = page.surface.bc, fc = colors.white}
	page.surface:addChild(page.labelSettings)

	page.scrollBox = UI.ScrollBox{x = 1, y = 4, w = root.w - 1, h = root.h - 3, bc = page.surface.bc, fc = colors.white}
	page.surface:addChild(page.scrollBox)
	local scrollbar_v = UI.Scrollbar(page.scrollBox)
	page.surface:addChild(scrollbar_v)

	page.labelSound = UI.Label{x = 6, y = 1, w = 5, h = 1, text = 'Sound', bc = page.scrollBox.bc, fc = colors.white}
	page.scrollBox:addChild(page.labelSound)

	page.labelOutput = UI.Label{x = 6, y = page.labelSound.y + 2, w = 13, h = 1, text = 'Output device', bc = page.scrollBox.bc, fc = colors.lightGray}
	page.scrollBox:addChild(page.labelOutput)

	page.dropdownOutput = UI.Dropdown{x = page.labelOutput.x + page.labelOutput.w + 1, y = page.labelOutput.y, bc = colors.white, fc = colors.black, array = speaker.getOutputs(), defaultValue = (user.OutputDevice ~= "") and user.OutputDevice or nil}
	page.scrollBox:addChild(page.dropdownOutput)
	page.dropdownOutput.pressed = function (self, element)
		user.OutputDevice = element
	end

	page.labelVolume = UI.Label{x = 6, y = page.labelOutput.y + 2, w = 6, h = 1, text = 'Volume', bc = page.scrollBox.bc, fc = colors.lightGray}
	page.scrollBox:addChild(page.labelVolume)

	page.sliderVolume = UI.Slider{x = page.labelVolume.x + page.labelVolume.w + 8, y = page.labelVolume.y, w = 15, bc = page.scrollBox.bc, fc = colors.white, fc_alt = colors.blue, bc_alt = colors.lightGray, fc_cl = colors.gray, arr = VOLUMES, slidePosition = user.Volume}
	page.scrollBox:addChild(page.sliderVolume)
	page.sliderVolume.pressed = function (self)
		user.Volume = self.slidePosition
		speaker.setVolume(self.arr[self.slidePosition])
	end

	page.labelInterface = UI.Label{x = 6, y = page.labelVolume.y + 3, w = 9, h = 1, text = 'Interface', bc = page.scrollBox.bc, fc = colors.white}
	page.scrollBox:addChild(page.labelInterface)

	page.labelScheme = UI.Label{x = 6, y = page.labelInterface.y + 2, w = 12, h = 1, text = 'Color Scheme', bc = page.scrollBox.bc, fc = colors.lightGray}
	page.scrollBox:addChild(page.labelScheme)

	local schemes = {}
	for k,_ in pairs(BOARD_BG) do
		table.insert(schemes, k)
	end
	page.dropdownScheme = UI.Dropdown{x = page.labelScheme.x + page.labelScheme.w + 1, y = page.labelScheme.y, h = 1, bc = colors.white, fc = colors.black, array = schemes, defaultValue = user.ColorScheme}
	page.scrollBox:addChild(page.dropdownScheme)
	page.dropdownScheme.pressed = function (self, element)
		BOARD_BG[element]()
		user.ColorScheme = element
	end

	page.boxColor = UI.Box{x = page.dropdownScheme.x + page.dropdownScheme.w + 1, y = page.dropdownScheme.y, w = 42, h = 28, bc = colors.red}
	page.scrollBox:addChild(page.boxColor)
	page.boxColor.draw = function (self)
		local glyph = {'tp', 'tq', 'tn', 'tb', 'tk', 'tr'}
		local count = 1
		for y = 1, 2 do
			for x = 1, 9, 3 do
				term.setCursorPos(self.x + x - 1, self.y + y - 1)
				term.setTextColor(y == 1 and Chess.BOARD_FG_A or Chess.BOARD_FG_B)
				term.setBackgroundColor(((x + y) % 2 == 0) and Chess.BOARD_BG_A or Chess.BOARD_BG_B)
				term.write(' '..Chess.pieceGlyph[glyph[count]]..' ')
				count = count + 1
			end
		end
	end

	page.labelPiece = UI.Label{x = 6, y = page.labelScheme.y + 2, w = 12, h = 1, text = 'Piece Scheme', bc = page.scrollBox.bc, fc = colors.lightGray}
	page.scrollBox:addChild(page.labelPiece)

	page.dropdownPiece = UI.Dropdown{x = page.labelPiece.x + page.labelPiece.w + 1, y = page.labelPiece.y, h = 1, bc = colors.white, fc = colors.black, array = {'Symbols', 'Letters'}, defaultValue = user.PieceScheme}
	page.scrollBox:addChild(page.dropdownPiece)
	page.dropdownPiece.pressed = function (self, element)
		PIECE_SCHEME[element]()
		user.PieceScheme = element
	end

	if http then
		page.labelNetwork = UI.Label{x = page.labelPiece.x, y = page.labelPiece.y + 3, w = 7, h = 1, bc = page.scrollBox.bc, fc = colors.white, text = 'Network'}
		page.scrollBox:addChild(page.labelNetwork)

		page.labelServerType = UI.Label{x = page.labelNetwork.x, y = page.labelNetwork.y + 2, w = 15, h = 1, bc = page.scrollBox.bc, fc = colors.lightGray, text = 'Connection Type'}
		page.scrollBox:addChild(page.labelServerType)

		local arr = http.websocketServer and {'Rednet','WebSocket'} or {'Rednet'}

		page.dropdownServer =  UI.Dropdown{x = page.labelServerType.x + page.labelServerType.w + 1, y = page.labelServerType.y, radius = 2, bc = colors.white, fc = colors.black, array = arr, defaultValue = user.ServerType}
		page.scrollBox:addChild(page.dropdownServer)
		page.dropdownServer.pressed = function (self, element)
			user.ServerType = element
		end
	end

	page.surface.onResize = function (width, height)
		page.surface.w, page.surface.h = width, height
		page.scrollBox.w, page.scrollBox.h = width, height
		page.labelSettings.local_x = math.floor((width - 8)/2) + 1
	end

	return page
end
Screen:register('settingsMenu', SettingsMenu)

local AboutMenu = {}
function AboutMenu.new()
	local page = {}

	page.surface = UI.Box{x = 1, y = 1, w = root.w, h = root.h, bc = colors.black}
	root:addChild(page.surface)

	page.btnExit = UI.Button{x = 2, y = 2, w = 3, h = 1, text = '\27', bc = colors.gray, fc = colors.white}
	page.surface:addChild(page.btnExit)
	page.btnExit.pressed = function (self)
		Screen:closeModal()
	end

	page.labelAbout = UI.Label{x = math.floor((root.w - 8)/2) + 1, y = 2, w = 8, h = 1, text = 'ABOUT', bc = page.surface.bc, fc = colors.white}
	page.surface:addChild(page.labelAbout)

	page.surface.onResize = function (width, height)
		page.surface.w, page.surface.h = width, height
		page.labelAbout.local_x = math.floor((width - 8)/2) + 1
	end

	return page
end
Screen:register('aboutMenu', AboutMenu)

local StartGame = {}
function StartGame.new(self, team, FEN, time, nickname, increment)
	local page = {}

	page.surface = UI.Box{x = 1, y = 1, w = root.w, h = root.h, bc = colors.black}
	root:addChild(page.surface)

	page.boardUI = Chess.Board{ x = math.floor((root.w - 16 - 26)/2) + 1, y = math.floor((root.h - 10)/2) + 1, w = 26, h = 10, bc = colors.black, fc = colors.lightGray, bc_alt = colors.orange }
	page.surface:addChild(page.boardUI)
	page.boardUI.pressed = function (self, from, to)
		page.list:onMouseScroll(math.max(0, #page.list.array * 10 - page.list.h))
		page.list.dirty = true
		if not self.game.over and time then
			if self.game.turn == 'b' then
				page.timerW:addTime(increment)
				page.timerW:pause()
				page.timerB:unPause()
			else
				page.timerB:addTime(increment)
				page.timerB:pause()
				page.timerW:unPause()
			end
		end
		if not network.running then return end
		local message = {type = 'chess_move', from = from, to = to}
		if network.server and time then
			message.remainig_w = page.timerW:getRemainingMs()
			message.remainig_b = page.timerB:getRemainingMs()
		end
		if network.server then network:broadcast(message)
		else network:sendTo(message)
		end
	end
	page.boardUI.rotate = (team == 'w')

	page.game = Chess.Game(page.boardUI.board)
	page.game.team = network.running and team
	if FEN ~= '' then page.game:loadFEN(FEN)
	else page.game:setDefaultPieces() end
	page.game:updateGameEnd()
	page.boardUI.game = page.game
	page.game.playSound = function (self, status)
		speaker.playFile(sounds[status])
	end
	page.game.refreshStatus = function(self)
		page.labelMessage:setText(self.message)
	end
	page.game.overed = function(self)
		page.timerB:pause()
		page.timerW:pause()
		page.boardUI.selected = nil
		page.boardUI.dirty = true
	end

	page.btnExit = UI.Button{x = 2, y = 2, w = 3, h = 1, text = '\27', bc = colors.gray, fc = colors.white}
	page.surface:addChild(page.btnExit)
	page.btnExit.pressed = function (self)
		if network.running then
			if network.server then network:stopServer()
			else network:disconnectFromServer()
			end
		end
		Screen:switch('mainMenu')
	end

	page.btnSettings = UI.Button{x = page.btnExit.x + page.btnExit.w + 1, y = page.btnExit.y, w = 3, h = 1, text = '\164', bc = colors.gray, fc = colors.white}
	page.surface:addChild(page.btnSettings)
	page.btnSettings.pressed = function (self)
		Screen:openModal('settingsMenu')
	end

	page.btnRotate = UI.Button{x = page.btnSettings.x + page.btnSettings.w + 1, y = page.btnSettings.y, w = 3, h = 1, text = '\18', fc = colors.white, bc = colors.gray}
	page.surface:addChild(page.btnRotate)
	page.btnRotate.pressed = function()
		page.boardUI.rotate = not page.boardUI.rotate
		--players
		if ((team == 'w' and page.boardUI.rotate) or (team == 'b' and not page.boardUI.rotate)) then
			page.labelPlayer1.local_y = page.boxPanel.h
			page.labelPlayer2.local_y = 1
		else
			page.labelPlayer1.local_y = 1
			page.labelPlayer2.local_y = page.boxPanel.h
		end
		--timers
		page.timerW.local_y = page.boardUI.rotate and page.boxPanel.y + page.boxPanel.h or page.boxPanel.y - 1
		page.timerB.local_y = page.boardUI.rotate and page.boxPanel.y - 1 or page.boxPanel.y + page.boxPanel.h

		page.surface:onLayout()
	end

	page.labelMessage = UI.Label{x = page.btnRotate.x + page.btnRotate.w + 1, y = page.btnRotate.y, w = root.w - 26, h = 1, fc = colors.lightGray, bc = page.surface.bc, align = 'center'}
	page.surface:addChild(page.labelMessage)

	if network.running then
		page.btnResign = UI.Button{x = root.w - 8, y = page.btnRotate.y, w = 8, h = 1, bc = colors.gray, fc = colors.white, text = "Resign", align = "center"}
		page.surface:addChild(page.btnResign)
		local rOldDraw = page.btnResign.draw
		page.btnResign.pressed = function (self)
			if page.game.over then return end
			local message = {type = 'game_resign'}
			if network.server then network:broadcast(message)
			else network:sendTo(message)
			end
			page.game:gameOver((team == 'w') and 'Black wins by resignation' or 'White wins by resignation')
		end
		-- ПРОДОЛЖИТЬ ТУТ
		page.btnOfferdraw = UI.Button{x = page.btnResign.x - 4, y = page.btnRotate.y, w = 3, h = 1, bc = colors.lightGray, fc = colors.white, text = "\189", align = "center"}
		page.surface:addChild(page.btnOfferdraw)
		page.btnOfferdraw.pressed = function (self)
			if page.game.over then return end
			local message = {type = 'game_offerdraw', team = Team}
			if network.server then network:broadcast(message)
			else network:sendTo(message)
			end
		end
	else
		page.btnRestart = UI.Button{x = root.w - 12, y = page.btnRotate.y, w = 12, h = 1, bc = colors.gray, fc = colors.white, text = 'Restart', align = "center"}
		page.surface:addChild(page.btnRestart)
		page.btnRestart.pressed = function (self)
			page.game:restartGame()
			page.list:updateArr(page.game.history)
			page.surface:onLayout()
			page.timerB:setTime(time)
			page.timerB:pause()
			page.timerW:setTime(time)
			page.timerW:pause()
		end
	end

	page.boxPanel = UI.Box{x = root.w - 15, y = math.floor((root.h - 9)/2) + 1, w = 16, h = 9, bc = colors.gray, fc = colors.white}
	page.surface:addChild(page.boxPanel)

	page.labelPlayer1 = UI.Label{x = 1, y = ((team == 'w' and page.btnRotate.rotate) or (team == 'b' and not page.btnRotate.rotate)) and page.boxPanel.h or 1, w = page.boxPanel.w, h = 1, bc = page.boxPanel.bc, fc = page.boxPanel.fc, text = nickname and "\4 "..user.Nickname or "\4 Player1", align = "left"}
	page.boxPanel:addChild(page.labelPlayer1)

	page.labelPlayer2 = UI.Label{x = 1, y = ((team == 'w' and page.btnRotate.rotate) or (team == 'b' and not page.btnRotate.rotate)) and 1 or page.boxPanel.h, w = page.boxPanel.w, h = 1, bc = page.boxPanel.bc, fc = page.boxPanel.fc, text = nickname and "\4 ".. nickname or "\4 Player2", align = "left"}
	page.boxPanel:addChild(page.labelPlayer2)

	page.list = UI.List{x = 1, y = 2, w = page.boxPanel.w, h = page.boxPanel.h - 2, bc = colors.gray, fc = colors.lightGray, array = page.game.history}
	page.boxPanel:addChild(page.list)
	page.list.onMouseDown = function(self, btn, x, y) end

	page.timerW = UI.Timer{x = page.boxPanel.x, y = page.btnRotate.rotate and page.boxPanel.y + page.boxPanel.h or page.boxPanel.y - 1, bc = colors.gray, fc = colors.white, time = time}
	page.surface:addChild(page.timerW)
	local timer_draw = page.timerW.draw
	page.timerW.draw = function (self)
		if Screen.modal then return end
		return timer_draw(self)
	end
	page.timerW.pressed = function (self)
		page.game:gameOver('White out of time')
	end

	page.timerB = UI.Timer{x = page.boxPanel.x, y = page.btnRotate.rotate and page.boxPanel.y - 1 or page.boxPanel.y + page.boxPanel.h, bc = colors.gray, fc = colors.white, time = time}
	page.surface:addChild(page.timerB)
	page.timerB.draw = page.timerW.draw
	page.timerB.pressed = function (self)
		page.game:gameOver('Black out of time')
	end

	if not network.running then
		page.tfFEN = UI.Textfield{x = 2, y = page.surface.h - 1, w = page.surface.w - 6, h = 1, hint = "Type FEN", fc = colors.white, bc = colors.gray}
		page.surface:addChild(page.tfFEN)

		page.btnFEN = UI.Button{x = root.w - 3, y = page.tfFEN.y, w = 3, h = 1, text = ">", fc = colors.white, bc = colors.gray}
		page.surface:addChild(page.btnFEN)
		page.btnFEN.pressed = function (self)
			if page.tfFEN.text then
				page.game:loadFEN(page.tfFEN.text)
				page.boardUI.dirty = true
			end
		end
	end

	page.moveFromTo = function (from, to)
		local fx = math.floor(from / 10)
		local fy = from % 10

		local tx = math.floor(to / 10)
		local ty = to % 10

		page.boardUI:selectSquare(fx, fy)
		page.game:moveSelectedTo(tx, ty, page.boardUI.selected)
		page.boardUI.selected = nil
		page.list:onMouseScroll(math.max(0, #page.list.array * 10 - page.list.h))
		page.list.dirty = true
		if not page.game.over and time then
			if page.game.turn == 'b' then
				page.timerW:pause()
				page.timerW:addTime(increment)
				page.timerB:unPause()
			else
				page.timerB:pause()
				page.timerB:addTime(increment)
				page.timerW:unPause()
			end
		end
		if Screen.modal then Screen.modal.surface:onLayout() end
	end

	page.game:refreshStatus()

	page.surface.onResize = function(width, height)
		page.surface.w, page.surface.h = width, height
		page.boardUI.local_x = math.floor((width - 16 - 26)/2) + 1
		page.boardUI.local_y = math.floor((height - 10)/2) + 1
		page.boxPanel.local_x = width - 15
		page.boxPanel.local_y = math.floor((height - 9)/2) + 1
		if not network.running then
			page.tfFEN.local_y, page.tfFEN.w = height - 1, width - 7
			page.btnFEN.local_x, page.btnFEN.local_y = width - 4, page.tfFEN.local_y
			page.btnRestart.local_x = width - 12
		else
			page.btnResign.local_x = width - 8
			page.btnOfferdraw.local_x = page.btnResign.local_x - 4
		end
		page.labelMessage.w = width - 26
		page.timerW.local_x, page.timerW.local_y = page.boxPanel.local_x, page.btnRotate.rotate and page.boxPanel.local_y + page.boxPanel.h or page.boxPanel.local_y - 1
		page.timerB.local_x, page.timerB.local_y = page.boxPanel.local_x, page.btnRotate.rotate and page.boxPanel.local_y - 1 or page.boxPanel.local_y + page.boxPanel.h
		if page.labelOfferdraw then
			page.labelOfferdraw.local_x, page.labelOfferdraw.local_y = math.floor((width - 25)/2) + 1, height - 1
			page.btnYes.local_x, page.btnYes.local_y = page.labelOfferdraw.local_x + page.labelOfferdraw.w + 1, page.labelOfferdraw.local_y
			page.btnNo.local_x, page.btnNo.local_y = page.btnYes.local_x + page.btnYes.w + 1, page.labelOfferdraw.local_y
		end
	end
	if network.running then
		network.closeHandler = function ()
			local teem = page.game.team == 'w' and 'Black' or 'White'
			page.game:gameOver(teem..' disconnected')
		end
		network.connectHandler = function (_, client)
			client.close()
		end
		network.messageHandler = function (userdata, message, bool)
			local recieve = textutils.unserialiseJSON(message)
			local Type = recieve.type

			if Type == 'sync' then
				page.timerW:setTime(recieve.remainig_w / 1000)
				page.timerB:setTime(recieve.remainig_b / 1000)
			elseif Type == 'chess_move' then
				page.moveFromTo(recieve.from, recieve.to)
				if not recieve.remainig_w and time then
					network:broadcast({type = 'sync', remainig_w = page.timerW:getRemainingMs(), remainig_b = page.timerB:getRemainingMs()})
				elseif time then
					page.timerW:setTime(recieve.remainig_w / 1000)
					page.timerB:setTime(recieve.remainig_b / 1000)
				end
			elseif Type == 'game_resign' then
				page.game:gameOver((page.game.team == 'b') and 'Black wins by resignation' or 'White wins by resignation')
			elseif Type == 'game_offerdraw' then
				if recieve.message then
					page.game:gameOver('Draw.')
					return
				end
				if page.labelOfferdraw then return end
				local team = team == 'w' and 'Black' or 'White'
				page.labelOfferdraw = UI.Label{x = math.floor((root.w - 25)/2) + 1, y = root.h - 1, w = 17, h = 1, text = team .. ' offers draw', bc = page.surface.bc, fc = colors.white}
				page.surface:addChild(page.labelOfferdraw)
				page.btnYes = UI.Button{x = page.labelOfferdraw.x + page.labelOfferdraw.w + 1, y = page.labelOfferdraw.y, w = 3, h = 1, text = 'Y', bc = colors.green, fc = colors.white}
				page.surface:addChild(page.btnYes)
				page.btnYes.pressed = function (self)
					page.surface:removeChild(page.labelOfferdraw)
					page.surface:removeChild(page.btnNo)
					page.surface:removeChild(self)
					page.surface:onLayout()
					page.labelOfferdraw = nil
					page.btnNo = nil
					page.btnYes = nil
					page.game:gameOver('Draw.')
					local message = {type = 'game_offerdraw', message = 'Yes'}
					if network.server then network:broadcast(message)
					else network:sendTo(message)
					end
				end
				page.btnNo = UI.Button{x = page.btnYes.x + page.btnYes.w + 1, y = root.h - 1, w = 3, h = 1, text = 'N', bc = colors.red, fc = colors.white}
				page.surface:addChild(page.btnNo)
				page.btnNo.pressed = function (self)
					page.surface:removeChild(page.labelOfferdraw)
					page.surface:removeChild(page.btnYes)
					page.surface:removeChild(self)
					page.surface:onLayout()
					page.labelOfferdraw = nil
					page.btnNo = nil
					page.btnYes = nil
				end
			end
		end
	end

	return page
end
Screen:register('startGame', StartGame)

local LobbyMenu = {}
function LobbyMenu.new()
	local page = {}

	page.surface = UI.Box{x = 1, y = 1, w = root.w, h = root.h, bc = colors.black}
	root:addChild(page.surface)

	page.btnExit = UI.Button{x = 2, y = 2, w = 3, h = 1, bc = colors.gray, fc = colors.white, text = '\27'}
	page.surface:addChild(page.btnExit)
	page.btnExit.pressed = function (self)
		if network.running then
			if network.server then network:stopServer()
			else network:disconnectFromServer()
			end
		end
		Screen:switch('mainMenu')
	end

	page.btnSettings = UI.Button{x = page.btnExit.x + page.btnExit.w + 1, y = page.btnExit.y, w = 3, h = 1, text = '\164', bc = colors.gray, fc = colors.white}
	page.surface:addChild(page.btnSettings)
	page.btnSettings.pressed = function (self)
		Screen:openModal('settingsMenu')
	end

	page.labelLobby = UI.Label{x = page.btnSettings.x + page.btnSettings.w + 1, y = 2, w = 5, h = 1, bc = page.surface.bc, fc = colors.white, text = 'Lobby'}
	page.surface:addChild(page.labelLobby)

	page.rbtnTeam = UI.RadioButton{x = root.w - 7, y = 4, bc = page.surface.bc, fc = colors.white, text = {'White', 'Black'}}
	page.surface:addChild(page.rbtnTeam)
	page.rbtnTeam.pressed = function (self, i)
		if page.btnReady.ready then return end
		page.labelPlayer1.dirty = true
		page.labelPlayer1.team = (i == 'White') and 'w' or 'b'
		local message = {type = 'lobby_update', ready = page.btnReady.ready, team = page.labelPlayer1.team, nickname = user.Nickname}
		if network.server then network:broadcast(message)
		else network:sendTo(message)
		end
	end

	page.labelTime = UI.Label{x = root.w - 9, y = page.rbtnTeam.y + page.rbtnTeam.h + 1, w = 9, h = 1, text = 'Time Mode', fc = colors.white, bc = colors.black}
	page.surface:addChild(page.labelTime)

	page.dropdownTime = UI.Dropdown{x = page.labelTime.x + 1, y = page.labelTime.y + 1, fc = colors.black, bc = colors.white, array = {'Off', '1+0', '2+1', '3+2', '5+3', '10+5', '30+20', 'custom'}, defaultValue = '5+3', radius = 2, disabled = not network.server}
	page.surface:addChild(page.dropdownTime)
	page.dropdownTime.pressed = function (self, element)
		if element == 'custom' then
			page.tfCustom = UI.Textfield{x = self.x-1, y = self.y + 2, w = self.w+2, h = 10, bc = colors.gray, fc = colors.white, hint = '10+5'}
			page.surface:addChild(page.tfCustom)
		else
			if page.tfCustom then
				page.surface:removeChild(page.tfCustom)
				page.tfCustom = nil
			end
		end
		network:broadcast({type = 'lobby_update', team = page.labelPlayer1.team, ready = page.labelPlayer1.ready, nickname = user.Nickname, time = page.dropdownTime.item_index})
	end

	-- local y = network.server and page.btnExit.y + page.btnExit.h + 15 or page.btnExit.y + page.btnExit.h + 15 + 20 + 5

	page.labelPlayer1 = UI.Label{x = 4, y = 4, w = 20, h = 1, text = '\7'..user.Nickname, bc = colors.gray, fc = colors.white, align = "left"}
	page.labelPlayer1.team = 'w'
	page.labelPlayer1.ready = false
	local player1Draw = page.labelPlayer1.draw
	page.labelPlayer1.draw = function (self)
		self.bc = self.ready and colors.green or colors.gray
		player1Draw(self)
		local fc = (self.team == 'w') and colors.white or colors.black
		term.setCursorPos(self.x, self.y)
		term.setBackgroundColor(self.bc)
		term.setTextColor(fc)
		term.write('\7')
	end
	page.surface:addChild(page.labelPlayer1)

	page.btnReady = UI.Button{x = root.w - 9, y = root.h - 1, w = 9, h = 1, bc = colors.gray, fc = colors.white, text = "Ready"}
	page.surface:addChild(page.btnReady)
	page.btnReady.pressed = function (self)
		page.labelPlayer1.ready = not page.labelPlayer1.ready
		if page.labelPlayer1.ready then
			page.rbtnTeam:setDisabled(true)
			page.dropdownTime:setDisabled(true)
			self:setText('Unready')
		else
			page.rbtnTeam:setDisabled()
			if network.server then
				page.dropdownTime:setDisabled()
			end
			self:setText('Ready')
		end
		page.labelPlayer1.dirty = true
		local message = {type = 'lobby_update', ready = page.labelPlayer1.ready, team = page.labelPlayer1.team, nickname = user.Nickname}
		if network.server then network:broadcast(message)
		else network:sendTo(message)
		end
	end

	if network.server then
		page.btnPlay = UI.Button{x = page.btnReady.x - 4, y = page.btnReady.y, w = 3, h = 1, bc = colors.gray, fc = colors.white, text = "\16"}
		page.surface:addChild(page.btnPlay)
		page.btnPlay.pressed = function (self)
			if not page.labelPlayer1.ready or (not page.labelPlayer2) then return end
			if not page.labelPlayer2.ready then return end
			if page.labelPlayer1.team == page.labelPlayer2.team then return end
			local function getTime(str)
				str = tostring(str)
				local plus = str:find('+')
				if not plus then return error('Incorrect time format: ' .. str, 2) end
				local time, increment
				time = tonumber(str:sub(1, plus - 1))
				increment = tonumber(str:sub(plus + 1, -1))
				if (not time) or (not increment) then return error('Incorrect time format: ' .. str, 2) end
				return time * 60, increment
			end
			local time, increment
			local element = page.dropdownTime.array[page.dropdownTime.item_index]
			if element == 'custom' then
				time, increment = getTime(page.tfCustom.text)
			elseif element == 'Off' then
			else
				time, increment = getTime(element)
			end
			network:broadcast({type = 'start_game', fen = page.tfFEN.text, time = time, increment = increment})
			Screen:switch('startGame', page.labelPlayer1.team, page.tfFEN.text, time, page.labelPlayer2.nickname, increment)
		end

		page.tfFEN = UI.Textfield{x = 2, y = root.h - 1, w = 30, h = 1, bc = colors.gray, fc = colors.white, hint = 'FEN'}
		page.surface:addChild(page.tfFEN)
	end

	page.surface.onResize = function (width, height)
		page.surface.w, page.surface.h = width, height
		page.rbtnTeam.local_x = width - 7
		page.btnReady.local_x, page.btnReady.local_y = width - 9, height - 1
		page.labelTime.local_x = width - 9
		page.dropdownTime.local_x = page.labelTime.local_x + 1
		if page.btnPlay then
			page.btnPlay.local_x, page.btnPlay.local_y = page.btnReady.local_x - 4, page.btnReady.local_y
			page.tfFEN.local_y = height - 1
		end
		if page.tfCustom then
			page.tfCustom.local_x = page.dropdownTime.local_x - 1
		end
	end

	function page.createUI(recieve)
		local bc = recieve.ready and colors.green or colors.gray

		page.labelPlayer2 = UI.Label{x = page.labelPlayer1.x, y = page.labelPlayer1.y + 2, w = 20, h = 1, text = '\7'..recieve.nickname, bc = bc, fc = colors.white, align = "left"}
		page.labelPlayer2.team = recieve.team
		page.labelPlayer2.draw = page.labelPlayer1.draw
		page.surface:addChild(page.labelPlayer2)

		page.surface:onLayout()
	end

	network.connectHandler = function () end
	network.closeHandler = function ()
		if not network.server then
			Screen:switch('mainMenu')
		else
			page.surface:removeChild(page.labelPlayer2)
			page.surface:onLayout()
			page.labelPlayer2 = nil
		end
	end
	network.messageHandler = function (userdata, message, bool)
		local recieve = textutils.unserialiseJSON(message)
		local Type = recieve.type

		if Type == 'lobby_join' then
			if not page.labelPlayer2 then page.createUI(recieve) end
			network:broadcast({type = 'lobby_update', nickname = user.Nickname, ready = page.labelPlayer1.ready, team = page.labelPlayer2.team, time = page.dropdownTime.item_index})
		elseif Type == 'lobby_update' then
			if not page.labelPlayer2 then page.createUI(recieve) end
			page.labelPlayer2.ready = recieve.ready
			page.labelPlayer2.team = recieve.team
			page.labelPlayer2.nickname = recieve.nickname
			page.labelPlayer2.dirty = true
			if recieve.time then
				page.dropdownTime.item_index = recieve.time
				page.dropdownTime.dirty = true
			end
		elseif Type == 'start_game' then
			Screen:switch('startGame', page.labelPlayer1.team, recieve.fen, recieve.time, page.labelPlayer2.nickname, recieve.increment)
		end
	end

	return page
end
Screen:register('lobbyMenu', LobbyMenu)

local JoinMenu = {}
function JoinMenu.new()
	local page = {}
	page.surface = UI.Box{x = 1, y = 1, w = root.w, h = root.h, bc = colors.black}
	root:addChild(page.surface)

	page.btnExit = UI.Button{x = 2, y = 2, w = 3, h = 1, bc = colors.gray, fc = colors.white, text = '\27'}
	page.surface:addChild(page.btnExit)
	page.btnExit.pressed = function (self)
		Screen:switch('mainMenu')
	end

	page.btnL = UI.Button{x = 6, y = 2, w = 1, h = 1, bc = colors.gray, fc = colors.white, text = 'L'}
	page.surface:addChild(page.btnL)
	page.btnL.pressed = function (self)
		page.tfIP.text = 'localhost'
		page.tfIP.dirty = true
	end

	page.btnV = UI.Button{x = 8, y = 2, w = 1, h = 1, bc = colors.gray, fc = colors.white, text = 'V'}
	page.surface:addChild(page.btnV)
	page.btnV.pressed = function (self)
		page.tfIP.text = '192.168.191.153'
		page.tfIP.dirty = true
	end

	page.btnA = UI.Button{x = 10, y = 2, w = 1, h = 1, bc = colors.gray, fc = colors.white, text = 'A'}
	page.surface:addChild(page.btnA)
	page.btnA.pressed = function (self)
		page.tfIP.text = '192.168.191.87'
		page.tfIP.dirty = true
	end
	local text, hint
	if user.ServerType == 'Rednet' then
		text = 'Computer ID:'
		hint = '9'
	else
		text = 'IP Adress:'
		hint = '192.168.0.1'
	end

	page.labelIP = UI.Label{x = math.floor((root.w - 16 - #text)/2) + 1, y = math.floor((root.h - 2)/2) + 1, h = 1, w = #text, text = text, bc = page.surface.bc, fc = colors.white}
	page.surface:addChild(page.labelIP)

	page.labelError = UI.Label{x = 1, y = page.labelIP.y - 2, h = 1, w = root.w, text = '', bc = page.surface.bc, fc = colors.white}
	page.surface:addChild(page.labelError)

	page.tfIP = UI.Textfield{x = page.labelIP.x + page.labelIP.w + 1, y = page.labelIP.y, w = 16, h = 1, hint = hint, bc = colors.gray, fc = colors.white}
	page.surface:addChild(page.tfIP)

	page.btnConnect = UI.Button{x = math.floor((root.w - 7)/2) + 1, y = page.labelIP.y + 2, w = 9, h = 1, bc = colors.gray, fc = colors.white, text = 'Connect'}
	page.surface:addChild(page.btnConnect)

	page.btnConnect.pressed = function (self)
		local ret, err
		if user.ServerType == 'Rednet' then
			ret, err = network:connectToServer(page.tfIP.text)
		else
			ret, err = network:connectToServer(page.tfIP.text, 22856)
		end
		if not ret then
			page.labelError.fc = colors.red
			page.labelError:setText(err)
			return
		end
		network:sendTo({type = 'lobby_join', nickname = user.Nickname, ready = false, team = 'w'})
		Screen:switch('lobbyMenu')
	end

	page.surface.onResize = function(width, height)
		page.surface.w, page.surface.h = width, height
		page.labelIP.local_x, page.labelIP.local_y = math.floor((width - 26)/2) + 1, math.floor((height - 2)/2) + 1
		page.tfIP.local_x, page.tfIP.local_y = page.labelIP.local_x + page.labelIP.w + 1, page.labelIP.local_y
		page.btnConnect.local_x, page.btnConnect.local_y = math.floor((width - 7)/2) + 1, page.labelIP.local_y + 2
		page.labelError.local_y, page.labelError.w = page.labelIP.local_y - 2, width
	end

	return page
end
Screen:register('joinMenu', JoinMenu)

local MainMenu = {}
function MainMenu.new()
	local page = {}

	page.surface = UI.Box{x = 1, y = 1, w = root.w, h = root.h, bc = colors.black}
	root:addChild(page.surface)

	page.logo = UI.Box{x = math.floor((root.w - 6)/2) + 1, y = 3, w = 6, h = 5, bc = colors.black}
	page.surface:addChild(page.logo)
	page.logo.img = blittle.load("Data/logo.ico")
	page.logo.draw = function (self)
		blittle.draw(self.img, self.x, self.y)
	end

	page.labelNickname = UI.Label{x = 1, y = 1, w = 10, h = 1, bc = page.surface.bc, fc = colors.white, text = "Nickname: "}
	page.surface:addChild(page.labelNickname)

	page.nickname = UI.Textfield{x = page.labelNickname.x + page.labelNickname.w, y = 1, w = 10, h = 1, bc = colors.gray, fc = colors.white}
	page.surface:addChild(page.nickname)
	page.nickname.text = user.Nickname
	local oldFocus = page.nickname.onFocus
	page.nickname.onFocus = function (self, focused)
		if not focused then
			if self.text ~= user.Nickname then
				user.Nickname = self.text
				saveUserSettings()
			end
		end
		return oldFocus(self, focused)
	end

	local center = math.floor((root.w - 14)/2)+1
	page.btnCreate = UI.Button{x = center, y = page.logo.y + page.logo.h + 1, w = 8, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Create"}
	page.surface:addChild(page.btnCreate)
	page.btnCreate.pressed = function ()
		local ret, err
		if user.ServerType == 'Rednet' then
			ret, err = network:startServer()
		else
			network:startServer(22856)
		end
		if not ret then
			error(err)
		end
		Screen:switch('lobbyMenu')
	end

	page.btnJoin = UI.Button{x = center + 9, y = page.logo.y + page.logo.h + 1, w = 6, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Join", bc_hc = colors.lightGray, fc_hc = colors.black}
	page.surface:addChild(page.btnJoin)
	page.btnJoin.pressed = function ()
		Screen:switch('joinMenu')
	end

	page.btnLocalGame = UI.Button{x = center, y = page.logo.y + page.logo.h + 3, w = 15, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Local Game", bc_hc = colors.lightGray, fc_hc = colors.black}
	page.surface:addChild(page.btnLocalGame)
	page.btnLocalGame.pressed = function (self)
		Screen:switch('startGame', 'w', '', 600, _, 2)
	end

	page.btnSettings = UI.Button{x = center, y = page.btnLocalGame.y + 2, w = 15, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Settings", bc_hc = colors.lightGray, fc_hc = colors.black}
	page.surface:addChild(page.btnSettings)
	page.btnSettings.pressed = function (self)
		Screen:openModal('settingsMenu')
	end

	page.btnQuit = UI.Button{x = center, y = page.btnSettings.y + 2, w = 15, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Quit", bc_hc = colors.lightGray, fc_hc = colors.black}
	page.surface:addChild(page.btnQuit)
	page.btnQuit.pressed = function (self)
		os.queueEvent('terminate')
	end

	page.btnAbout = UI.Button{x = root.w - 3, y = 2, w = 3, h = 1, bc = colors.gray, fc = colors.white, text = "?"}
	page.surface:addChild(page.btnAbout)
	page.btnAbout.pressed = function (self)
		Screen:openModal('aboutMenu')
	end

	page.labelVersion = UI.Label{x = 1, y = root.h - 1, w = root.w, h = 1, bc = page.surface.bc, fc = colors.gray, text = 'Ver.:'.._G.ver, align = "left"}
	page.surface:addChild(page.labelVersion)

	page.btnUpdate = UI.Button{x = 1, y = root.h, w = 16, h = 1, radius = 5, text = 'Check for update', bc = colors.gray, fc = colors.white}
	page.btnUpdate.loading = 0
	page.btnUpdate.draw = function (self)
		local bc = self.bc
		local fc = self.fc
		if self.held and not (self.loading > 0) then
			bc = self.bc_cl or self.fc
			fc = self.fc_cl or self.bc
		end
		local text = ''
		term.setCursorPos(self.x, self.y)
		term.setBackgroundColor(bc)
		term.setTextColor(fc)
		if #self.text <= self.w then
			local p = math.floor((self.w - #self.text)/2) + 1
			text = (' '):rep(p-1)..self.text..(' '):rep(self.w-(#self.text + (p-1)))
		end
		term.write(text)
		term.setCursorPos(self.x, self.y)
		term.setBackgroundColor(colors.blue)
		term.write(text:sub(1, self.loading*self.w))
	end
	page.surface:addChild(page.btnUpdate)
	page.btnUpdate.pressed = function (self)
		local link = 'https://raw.githubusercontent.com/aTimmYm/Chess/refs/heads/dev/'
		local response, err = http.get(link .. 'sha256-sums')
		-- local response, err = fs.open('sha256-sums', 'r')
		if response then
			local shaSum = response.readAll()
			response.close()
			local ret, filesToUpdate = checkUpdates(shaSum)
			if ret then
				self:setText('Updating')
				for i, path in ipairs(filesToUpdate) do
					local request = http.get(link .. path)
					if request then
						-- log('Download: ' .. path)
						write_file(path, request.readAll())
						request.close()
						self.loading = i / #filesToUpdate
						self:draw()
					end
				end
				self:setText('Succes')
			else
				self:setText('No updates')
			end
		end
	end

	page.surface.onResize = function(width, height)
		page.surface.w, page.surface.h = width, height
		center = math.floor((width - 14)/2) + 1
		page.logo.local_x = math.floor((width - 6)/2) + 1
		page.btnCreate.local_x = center
		page.btnJoin.local_x = center + 9
		page.btnLocalGame.local_x, page.btnLocalGame.local_y = center, page.logo.local_y + page.logo.h + 3
		page.btnSettings.local_x, page.btnSettings.local_y = center, page.btnLocalGame.local_y + 2
		page.btnQuit.local_x = center
		page.btnAbout.local_x = width - 3
		page.labelVersion.local_y, page.labelVersion.w = height - 1, width
		page.btnUpdate.local_y = height
	end

	return page
end
Screen:register('mainMenu', MainMenu)

Screen:switch('mainMenu')

root:show()
while true do
	local evt = {coroutine.yield()}
	local event = evt[1]
	if event == "terminate" then
		network:stopServer()
		term.setBackgroundColor(colors.black)
		term.setTextColor(colors.white)
		term.setCursorPos(1,1)
		term.clear()
		break
	elseif event == "rednet_message" or event:match("^websocket") then
		network:eventHandler(evt)
	elseif event == 'peripheral' then
		speaker.updateOutputs()
		network:updateModems()
	end
	root:onEvent(evt)
end