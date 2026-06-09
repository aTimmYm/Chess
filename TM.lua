local UI = require "UI"
local blittle = require "blittle_extended"
local speaker = require "Speaker"
local Screen = require "ScreenManager"
local Chess = require "Chess"
local network = require "Network"
local user = require 'Settings'
local sha; if not jit then sha = require 'sha2' end

local port = 22856

local ret, newOut = speaker.setOutput(user.OutputDevice)
if not ret then
	user.OutputDevice = newOut
	user()
end

if http and not http.websocketServer then
	user.ServerType = 'Rednet'
	user()
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
		Chess.BOARD_FG_A = colors.lightGray
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

local TB = {
	about_textBlock1 = [[Goal:
	Win by checkmating the opponent's king. A king is in check if it is attacked by an enemy piece. If the king cannot escape the attack, the game ends immediately.
	]],

	about_textBlock2 = [[
	How pieces move:

	Pawn - moves forward 1 square; on its first move it may move 2 squares if both squares are empty. Pawns capture one square diagonally forward.
	Rook - moves any number of squares horizontally or vertically.
	Knight - moves in an "L" shape: 2 squares in one direction and 1 square perpendicular. Knights can jump over pieces.]],

	about_textBlock3 =
	[[Bishop - moves any number of squares diagonally.
	Queen - moves like a rook or bishop, any number of squares.
	King - moves 1 square in any direction.
	]],

	about_textBlock4 = [[
	Special rules:

	Castling - a special move involving the king and one rook. The king moves 2 squares toward the rook, and the rook jumps to the square next to the king. Castling is allowed only if neither piece has moved, the squares between them are empty, the king is not in check, and the king does not move through or onto an attacked square.
	En passant - if an enemy pawn moves 2 squares forward and lands next to your pawn, your pawn may capture it as if it had moved only 1 square, but only on the very next move.
	Promotion - if a pawn reaches the last rank, it is promoted to another piece, usually a queen.]],

	about_textBlock5 = [[
	End of the game:

	Checkmate - the king is in check and has no legal move to escape. This means the player loses.
	Stalemate - the player has no legal moves, but the king is not in check. This is a draw.
	A game can also end in a draw by repetition, the 50-move rule, or insufficient material.]]
}

local root = UI.Root()
Screen.surface = root

local sounds = {
	['move'] = APPDIR .. 'Data/sounds/chess_move',
	['capture'] = APPDIR .. 'Data/sounds/chess_capture',
	['checkmate'] = APPDIR .. 'Data/sounds/chess_checkmate',
}
local VOLUMES = {}
for i = 0, 14 do
	VOLUMES[i + 1] = i/14*3
end

local exeption = {
	['rom'] = true,
	['.git'] = true,
	[APPDIR .. 'Data/Settings/user.json'] = true,
	[APPDIR .. 'Data/user.json'] = true
}

local function notification(msg)
	-- box = UI.Box{x = 0, y = 15, w = 80, h = 25, bc = colors.green, fc = colors.white, radius = 2}
	-- root:addChild(box)
	local box = UI.Label{x = 1, y = 2, w = 15, h = 2, bc = colors.red, fc = colors.white, radius = 2, text = msg}
	function box:onMouseDown()
		root:removeChild(self)
		root:onLayout()
		os.cancelTimer(self.timer)
	end
	root:addChild(box)
	root:onLayout()
	box.oldEvent = box.onEvent
	function box:onEvent(evt)
		if evt[1] == 'timer' and evt[2] == self.timer then
			root:removeChild(self)
			root:onLayout()
			return true
		end
		return self:oldEvent(evt)
	end
	box.timer = os.startTimer(3)
end

local function write_file(path, data)
	local file = fs.open(path, 'w')
	file.write(data)
	file.close()
end

local function listAllFiles(path, array)
	local files = fs.list(path)

	for i = 1, #files do
		local file = files[i]
		local fullPath = fs.combine(path, file)

		if fs.isDir(fullPath) then
			if not exeption[fullPath] then listAllFiles(fullPath, array) end
		else
			if not exeption[fullPath] then
				local file = fs.open(fullPath, 'r')
				-- local hash = sha.digest(file.readAll())
				-- array[fullPath] = util.toHex(hash)
				array[fullPath] = sha.sha256(file.readAll())
				file.close()
				-- log(fullPath)
			end
		end
	end
end

local function userFiles()
	local files = {}
	listAllFiles(APPDIR:sub(1, -2), files)

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
		-- log('USER: '.. path .. ' | ' .. hash)
		if not hashList[path] then
			fs.delete(path)
			ret = true
		end
	end
	for path, hash in pairs(hashList) do
		-- log('SUMS: '.. path .. ' | ' .. hash)
		local absPath = APPDIR .. path
		if not userList[absPath] or userList[absPath] ~= hash then
			table.insert(filesToUpdate, path)
			ret = true
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
	function page.btnExit:pressed()
		user()
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
	function page.dropdownOutput:pressed(element)
		user.OutputDevice = element
	end

	page.labelVolume = UI.Label{x = 6, y = page.labelOutput.y + 2, w = 6, h = 1, text = 'Volume', bc = page.scrollBox.bc, fc = colors.lightGray}
	page.scrollBox:addChild(page.labelVolume)

	page.sliderVolume = UI.Slider{x = page.labelVolume.x + page.labelVolume.w + 8, y = page.labelVolume.y, w = 15, bc = page.scrollBox.bc, fc = colors.white, fc_alt = colors.blue, bc_alt = colors.lightGray, fc_cl = colors.gray, arr = VOLUMES, slidePosition = user.Volume}
	page.scrollBox:addChild(page.sliderVolume)
	function page.sliderVolume:pressed()
		user.Volume = self.slidePosition
		speaker.setVolume(self.arr[self.slidePosition])
	end

	page.labelInterface = UI.Label{x = 6, y = page.labelVolume.y + 3, w = 9, h = 1, text = 'Interface', bc = page.scrollBox.bc, fc = colors.white}
	page.scrollBox:addChild(page.labelInterface)

	page.labelScheme = UI.Label{x = 6, y = page.labelInterface.y + 2, w = 12, h = 1, text = 'Color Scheme', bc = page.scrollBox.bc, fc = colors.lightGray}
	page.scrollBox:addChild(page.labelScheme)

	local schemes = {}
	for k,_ in pairs(BOARD_BG) do table.insert(schemes, k) end
	table.sort(schemes)
	page.dropdownScheme = UI.Dropdown{x = page.labelScheme.x + page.labelScheme.w + 1, y = page.labelScheme.y, h = 1, bc = colors.white, fc = colors.black, array = schemes, defaultValue = user.ColorScheme}
	page.scrollBox:addChild(page.dropdownScheme)
	function page.dropdownScheme:pressed(element)
		BOARD_BG[element]()
		user.ColorScheme = element
	end

	page.boxColor = UI.Box{x = page.dropdownScheme.x + page.dropdownScheme.w + 1, y = page.dropdownScheme.y, w = 42, h = 28, bc = colors.red}
	page.scrollBox:addChild(page.boxColor)
	function page.boxColor:draw()
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
	function page.dropdownPiece:pressed(element)
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
		function page.dropdownServer:pressed(element)
			user.ServerType = element
		end
	end

	function page.surface:onResize(width, height)
		page.surface.w, page.surface.h = width, height
		page.scrollBox.w, page.scrollBox.h = width, height
		page.labelSettings.lX = math.floor((width - 8)/2) + 1
	end

	return page
end
Screen:register('settingsMenu', SettingsMenu)

local AboutMenu = {}
function AboutMenu.new()
	local page = {}

	page.surface = UI.Box{x = 1, y = 1, w = root.w, h = root.h, bc = colors.black}
	root:addChild(page.surface)

	page.labelAbout = UI.Label{x = math.floor((root.w - 8)/2) + 1, y = 2, w = 8, h = 1, text = 'ABOUT', bc = page.surface.bc, fc = colors.white}
	page.surface:addChild(page.labelAbout)

	page.btnExit = UI.Button{x = 2, y = 2, w = 3, h = 1, text = '\27', bc = colors.gray, fc = colors.white}
	page.surface:addChild(page.btnExit)
	function page.btnExit:pressed()
		Screen:closeModal()
	end

	page.scrollBox = UI.ScrollBox{x = 1, y = 4, w = page.surface.w - 1, h = page.surface.h - 3, bc = colors.black, fc = colors.white}
	page.surface:addChild(page.scrollBox)

	local scrollbar = UI.Scrollbar(page.scrollBox)
	page.surface:addChild(scrollbar)

	--==TEXT ABOUT==--
	local Height, w = 0, page.scrollBox.w - 4
	for i = 1, 5 do
		local t = TB['about_textBlock'..i]
		local h = (#(UI.wrap_text_to_width(t, w)))
		local l = UI.Label{text = t, x = 2, y = Height, w = w, h = h, bc = page.scrollBox.bc, fc = page.scrollBox.fc, align = 'lefttop'}
		page.scrollBox:addChild(l)
		Height = l.y + l.h
	end

	function page.scrollBox.onResize(width, height)
		Height, w = 0, width - 4
		for i = 1, #page.scrollBox.children do
			local child = page.scrollBox.children[i]
			local t = TB['about_textBlock'..i]
			local h = (#(UI.wrap_text_to_width(t, w)))
			child.w = w
			child.h = h
			child.lY = Height
			Height = child.lY + child.h
			child._layout_dirty = true
		end
	end

	function page.surface.onResize(width, height)
		page.surface.w, page.surface.h = width, height
		page.labelAbout.lX = math.floor((width - 8)/2) + 1
		page.scrollBox.w, page.scrollBox.h = page.surface.w - 1, page.surface.h - 3
		scrollbar.lX, scrollbar.h = width, page.scrollBox.h
		page.scrollBox.onResize(page.scrollBox.w, page.scrollBox.h)
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
	function page.boardUI:pressed(from, to, promo)
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
		local message = {type = 'chess_move', from = from, to = to, promo = promo}
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
	function page.game:playSound(status)
		speaker.playFile(sounds[status])
	end
	function page.boardUI:waitingPromo(toX, toY, selected)
		if page.game.pendingPromotion then return end
		page.game.pendingPromotion = true
		if page.tfFEN then
			page.tfFEN:setDisabled(true)
			page.btnFEN:setDisabled(true)
		end
		if page.btnRestart then
			page.btnRestart:setDisabled(true)
		else
			page.btnResign:setDisabled(true)
			page.btnOfferdraw:setDisabled(true)
		end

		local box = UI.Box{ x = 1, y = 2, w = 18, h = 2, bc = colors.green}
		root:addChild(box)
		local label = UI.Label{text = 'Choose promotion', x = 1, y = 1, w = box.w - 2, h = box.h, bc = box.bc, fc = colors.white, align = 'left_top'}
		box:addChild(label)
		local btnClose = UI.Button{x = box.w, y = 1, w = 1, h = 1, bc = box.bc, fc = colors.gray, text = 'x', bc_cl = box.bc, fc_cl = colors.lightGray}
		box:addChild(btnClose)
		function btnClose:pressed()
			page.game.pendingPromotion = nil
			page.boardUI.selected = nil
			page.boardUI.dirty = true
			root:removeChild(box)
			root:onLayout()
			if page.tfFEN then
				page.tfFEN:setDisabled()
				page.btnFEN:setDisabled()
			end
			if page.btnRestart then
				page.btnRestart:setDisabled()
			else
				page.btnResign:setDisabled()
				page.btnOfferdraw:setDisabled()
			end
		end
		local ddChoose = UI.Dropdown{x = 2, y = box.h, bc = colors.gray, fc = colors.white, array = {'Queen', 'Bishop', 'Rook', 'Knight'}}
		box:addChild(ddChoose)
		root:onLayout()
		function ddChoose:pressed(choice)
			choice = (choice == 'Knight') and choice:sub(2,2):lower() or choice:sub(1,1):lower()
			if page.game:moveSelectedTo(toX, toY, selected, choice) then
				page.boardUI.selected = nil
				page.boardUI.dirty = true
				page.boardUI:pressed(selected.x * 10 + selected.y, toX * 10 + toY, choice)
			end
			root:removeChild(box)
			root:onLayout()
			if page.tfFEN then
				page.tfFEN:setDisabled()
				page.btnFEN:setDisabled()
			end
			if page.btnRestart then
				page.btnRestart:setDisabled()
			else
				page.btnResign:setDisabled()
				page.btnOfferdraw:setDisabled()
			end
			page.game.pendingPromotion = nil
		end
	end
	function page.game:refreshStatus()
		page.labelMessage:setText(self.message)
		local mW, mB = self:getMaterial()
		page.labelMaterialW:setText(tostring(mW-mB))
		page.labelMaterialB:setText(tostring(mB-mW))
	end
	function page.game:overed()
		page.timerB:pause()
		page.timerW:pause()
		page.boardUI.selected = nil
		page.boardUI.dirty = true
	end

	page.btnExit = UI.Button{x = 2, y = 2, w = 3, h = 1, text = '\27', bc = colors.gray, fc = colors.white}
	page.surface:addChild(page.btnExit)
	function page.btnExit:pressed()
		if network.running then
			if network.server then network:stopServer()
			else network:disconnectFromServer()
			end
		end
		Screen:switch('mainMenu')
	end

	page.btnSettings = UI.Button{x = page.btnExit.x + page.btnExit.w + 1, y = page.btnExit.y, w = 3, h = 1, text = '\164', bc = colors.gray, fc = colors.white}
	page.surface:addChild(page.btnSettings)
	function page.btnSettings:pressed()
		Screen:openModal('settingsMenu')
	end

	page.btnRotate = UI.Button{x = page.btnSettings.x + page.btnSettings.w + 1, y = page.btnSettings.y, w = 3, h = 1, text = '\18', fc = colors.white, bc = colors.gray}
	page.surface:addChild(page.btnRotate)
	function page.btnRotate:pressed()
		page.boardUI.rotate = not page.boardUI.rotate
		--players
		if ((team == 'w' and page.boardUI.rotate) or (team == 'b' and not page.boardUI.rotate)) then
			page.Player1.lY = page.boxPanel.h
			page.Player2.lY = 1
		else
			page.Player1.lY = 1
			page.Player2.lY = page.boxPanel.h
		end
		--timers
		page.timerW.lY = page.boardUI.rotate and page.boxPanel.y + page.boxPanel.h or page.boxPanel.y - 1
		page.timerB.lY = page.boardUI.rotate and page.boxPanel.y - 1 or page.boxPanel.y + page.boxPanel.h
		page.labelMaterialW.lY = page.timerW.lY
		page.labelMaterialB.lY = page.timerB.lY

		page.surface:onLayout()
	end

	page.labelMessage = UI.Label{x = page.btnRotate.x + page.btnRotate.w + 1, y = page.btnRotate.y, w = root.w - 26, h = 1, fc = colors.lightGray, bc = page.surface.bc, align = 'center'}
	page.surface:addChild(page.labelMessage)

	if network.running then
		page.btnResign = UI.Button{x = root.w - 8, y = page.btnRotate.y, w = 8, h = 1, bc = colors.gray, fc = colors.white, text = "Resign", align = "center"}
		page.surface:addChild(page.btnResign)
		function page.btnResign:pressed()
			if page.game.over then return end
			local message = {type = 'game_resign'}
			if network.server then network:broadcast(message)
			else network:sendTo(message)
			end
			page.game:gameOver((team == 'w') and 'Black wins by resignation' or 'White wins by resignation')
		end

		page.btnOfferdraw = UI.Button{x = page.btnResign.x - 4, y = page.btnRotate.y, w = 3, h = 1, bc = colors.lightGray, fc = colors.white, text = "\189", align = "center"}
		page.surface:addChild(page.btnOfferdraw)
		function page.btnOfferdraw:pressed()
			if page.game.over then return end
			local message = {type = 'game_offerdraw', team = Team}
			if network.server then network:broadcast(message)
			else network:sendTo(message)
			end
		end
	else
		page.btnRestart = UI.Button{x = root.w - 12, y = page.btnRotate.y, w = 12, h = 1, bc = colors.gray, fc = colors.white, text = 'Restart', align = "center"}
		page.surface:addChild(page.btnRestart)
		function page.btnRestart:pressed()
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

	page.Player1 = UI.Label{x = 1, y = ((team == 'w' and page.btnRotate.rotate) or (team == 'b' and not page.btnRotate.rotate)) and page.boxPanel.h or 1, w = page.boxPanel.w, h = 1, bc = page.boxPanel.bc, fc = page.boxPanel.fc, text = nickname and "\4 "..user.Nickname or "\4 Player1", align = "left"}
	page.boxPanel:addChild(page.Player1)

	page.Player2 = UI.Label{x = 1, y = ((team == 'w' and page.btnRotate.rotate) or (team == 'b' and not page.btnRotate.rotate)) and 1 or page.boxPanel.h, w = page.boxPanel.w, h = 1, bc = page.boxPanel.bc, fc = page.boxPanel.fc, text = nickname and "\4 ".. nickname or "\4 Player2", align = "left"}
	page.boxPanel:addChild(page.Player2)

	page.list = UI.List{x = 1, y = 2, w = page.boxPanel.w, h = page.boxPanel.h - 2, bc = colors.gray, fc = colors.lightGray, array = page.game.history}
	page.boxPanel:addChild(page.list)
	function page.list:onMouseDown() end

	page.timerW = UI.Timer{x = page.boxPanel.x, y = page.btnRotate.rotate and page.boxPanel.y + page.boxPanel.h or page.boxPanel.y - 1, bc = colors.gray, fc = colors.white, time = time}
	page.surface:addChild(page.timerW)
	page.timerW.oldDraw = page.timerW.draw
	function page.timerW:draw()
		if Screen.modal then return end
		return self:oldDraw()
	end
	function page.timerW:pressed()
		page.game:gameOver('White out of time')
	end

	page.timerB = UI.Timer{x = page.boxPanel.x, y = page.btnRotate.rotate and page.boxPanel.y - 1 or page.boxPanel.y + page.boxPanel.h, bc = colors.gray, fc = colors.white, time = time}
	page.surface:addChild(page.timerB)
	page.timerB.oldDraw = page.timerB.draw
	page.timerB.draw = page.timerW.draw
	function page.timerB:pressed()
		page.game:gameOver('Black out of time')
	end

	local mW, mB = page.game:getMaterial()

	page.labelMaterialW = UI.Label{text = tostring(mW - mB), x = root.w - 4, y = page.timerW.y, w = 4, h = 1, bc = page.surface.bc, fc = colors.gray, align = 'right'}
	page.surface:addChild(page.labelMaterialW)

	page.labelMaterialB = UI.Label{text = tostring(mB - mW), x = root.w - 4, y = page.timerB.y, w = 4, h = 1, bc = page.surface.bc, fc = colors.gray, align = 'right'}
	page.surface:addChild(page.labelMaterialB)

	if not network.running then
		page.tfFEN = UI.Textfield{x = 2, y = page.surface.h - 1, w = page.surface.w - 6, h = 1, hint = "Type FEN", fc = colors.white, bc = colors.gray}
		page.surface:addChild(page.tfFEN)

		page.btnFEN = UI.Button{x = root.w - 3, y = page.tfFEN.y, w = 3, h = 1, text = ">", fc = colors.white, bc = colors.gray}
		page.surface:addChild(page.btnFEN)
		function page.btnFEN:pressed()
			if page.tfFEN.text ~= '' then
				page.game:loadFEN(page.tfFEN.text)
				page.list:updateArr(page.game.history)
				page.boardUI.dirty = true
				page.timerB:setTime(time)
				page.timerB:pause()
				page.timerW:setTime(time)
				page.timerW:pause()
			end
		end
	end

	function page.moveFromTo(from, to, promo)
		local fx = math.floor(from / 10)
		local fy = from % 10

		local tx = math.floor(to / 10)
		local ty = to % 10

		page.boardUI:selectSquare(fx, fy)
		page.game:moveSelectedTo(tx, ty, page.boardUI.selected, promo)
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

	function page.surface.onResize(width, height)
		page.surface.w, page.surface.h = width, height
		page.boardUI.lX = math.floor((width - 16 - 26)/2) + 1
		page.boardUI.lY = math.floor((height - 10)/2) + 1
		page.boxPanel.lX = width - 15
		page.boxPanel.lY = math.floor((height - 9)/2) + 1
		if not network.running then
			page.tfFEN.lY, page.tfFEN.w = height - 1, width - 7
			page.btnFEN.lX, page.btnFEN.lY = width - 4, page.tfFEN.lY
			page.btnRestart.lX = width - 12
		else
			page.btnResign.lX = width - 8
			page.btnOfferdraw.lX = page.btnResign.lX - 4
		end
		page.labelMessage.w = width - 26
		page.timerW.lX, page.timerW.lY = page.boxPanel.lX, page.btnRotate.rotate and page.boxPanel.lY + page.boxPanel.h or page.boxPanel.lY - 1
		page.timerB.lX, page.timerB.lY = page.boxPanel.lX, page.btnRotate.rotate and page.boxPanel.lY - 1 or page.boxPanel.lY + page.boxPanel.h
		page.labelMaterialW.lX, page.labelMaterialW.lY = width - 4, page.timerW.lY
		page.labelMaterialB.lX, page.labelMaterialB.lY = width - 4, page.timerB.lY
		if page.labelOfferdraw then
			page.labelOfferdraw.lX, page.labelOfferdraw.lY = math.floor((width - 25)/2) + 1, height - 1
			page.btnYes.lX, page.btnYes.lY = page.labelOfferdraw.lX + page.labelOfferdraw.w + 1, page.labelOfferdraw.lY
			page.btnNo.lX, page.btnNo.lY = page.btnYes.lX + page.btnYes.w + 1, page.labelOfferdraw.lY
		end
	end
	if network.running then
		function network.closeHandler()
			local teem = page.game.team == 'w' and 'Black' or 'White'
			page.game:gameOver(teem..' disconnected')
		end
		function network.connectHandler(_, client)
			network:closeClient(client.clientID)
		end
		function network.messageHandler(userdata, message, bool)
			local recieve = textutils.unserialiseJSON(message)
			local Type = recieve.type

			if Type == 'sync' then
				page.timerW:setTime(recieve.remainig_w / 1000)
				page.timerB:setTime(recieve.remainig_b / 1000)
			elseif Type == 'chess_move' then
				page.moveFromTo(recieve.from, recieve.to, recieve.promo)
				if not recieve.remainig_w and time then
					network:broadcast{type = 'sync', remainig_w = page.timerW:getRemainingMs(), remainig_b = page.timerB:getRemainingMs()}
				elseif time then
					page.timerW:setTime(recieve.remainig_w / 1000)
					page.timerB:setTime(recieve.remainig_b / 1000)
				end
			elseif Type == 'game_resign' then
				page.game:gameOver((page.game.team == 'b') and 'Black wins by resignation' or 'White wins by resignation')
			elseif Type == 'game_offerdraw' then
				if recieve.message then
					return page.game:gameOver('Draw.')
				end
				if page.labelOfferdraw then return end
				local team = (team == 'w') and 'Black' or 'White'
				page.labelOfferdraw = UI.Label{x = math.floor((root.w - 25)/2) + 1, y = root.h - 1, w = 17, h = 1, text = team .. ' offers draw', bc = page.surface.bc, fc = colors.white}
				page.surface:addChild(page.labelOfferdraw)

				page.btnYes = UI.Button{x = page.labelOfferdraw.x + page.labelOfferdraw.w + 1, y = page.labelOfferdraw.y, w = 3, h = 1, text = 'Y', bc = colors.green, fc = colors.white}
				page.surface:addChild(page.btnYes)
				function page.btnYes:pressed()
					page.surface:removeChild(page.labelOfferdraw)
					page.surface:removeChild(page.btnNo)
					page.surface:removeChild(self)
					page.surface:onLayout()
					page.labelOfferdraw = nil
					page.btnNo = nil
					page.btnYes = nil
					if page.game.over then return end
					page.game:gameOver('Draw.')
					local message = {type = 'game_offerdraw', message = 'Yes'}
					if network.server then network:broadcast(message)
					else network:sendTo(message)
					end
				end
				page.btnNo = UI.Button{x = page.btnYes.x + page.btnYes.w + 1, y = root.h - 1, w = 3, h = 1, text = 'N', bc = colors.red, fc = colors.white}
				page.surface:addChild(page.btnNo)
				function page.btnNo:pressed()
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
	function page.btnExit:pressed()
		if network.running then
			if network.server then network:stopServer()
			else network:disconnectFromServer()
			end
		end
		Screen:switch('mainMenu')
	end

	page.btnSettings = UI.Button{x = page.btnExit.x + page.btnExit.w + 1, y = page.btnExit.y, w = 3, h = 1, text = '\164', bc = colors.gray, fc = colors.white}
	page.surface:addChild(page.btnSettings)
	function page.btnSettings:pressed()
		Screen:openModal('settingsMenu')
	end

	page.labelLobby = UI.Label{x = page.btnSettings.x + page.btnSettings.w + 1, y = 2, w = 5, h = 1, bc = page.surface.bc, fc = colors.white, text = 'Lobby'}
	page.surface:addChild(page.labelLobby)

	page.rbtnTeam = UI.RadioButton{x = root.w - 7, y = 4, bc = page.surface.bc, fc = colors.white, text = {'White', 'Black'}}
	page.surface:addChild(page.rbtnTeam)
	function page.rbtnTeam:pressed(i)
		page.Player1.dirty = true
		page.Player1.team = (i == 'White') and 'w' or 'b'
		local message = {type = 'lobby_update', ready = page.btnReady.ready, team = page.Player1.team, nickname = user.Nickname}
		if network.server then network:broadcast(message)
		else network:sendTo(message)
		end
	end

	page.labelTime = UI.Label{x = root.w - 9, y = page.rbtnTeam.y + page.rbtnTeam.h + 1, w = 9, h = 1, text = 'Time Mode', fc = colors.white, bc = colors.black}
	page.surface:addChild(page.labelTime)

	page.dropdownTime = UI.Dropdown{x = page.labelTime.x + 1, y = page.labelTime.y + 1, fc = colors.black, bc = colors.white, array = {'Off', '1+0', '2+1', '3+2', '5+3', '10+5', '30+20', 'custom'}, defaultValue = '5+3', radius = 2, disabled = not network.server}
	page.surface:addChild(page.dropdownTime)
	function page.dropdownTime:pressed(element)
		if element == 'custom' then
			page.tfCustom = UI.Textfield{x = self.x-1, y = self.y + 2, w = self.w+2, h = 10, bc = colors.gray, fc = colors.white, hint = '10+5'}
			page.surface:addChild(page.tfCustom)
		else
			if page.tfCustom then
				page.surface:removeChild(page.tfCustom)
				page.tfCustom = nil
			end
		end
		network:broadcast{type = 'lobby_update', team = page.Player1.team, ready = page.Player1.ready, nickname = user.Nickname, time = page.dropdownTime.item_index}
	end

	-- local y = network.server and page.btnExit.y + page.btnExit.h + 15 or page.btnExit.y + page.btnExit.h + 15 + 20 + 5

	page.Player1 = UI.Box{x = math.floor((root.w - 12 - 10)/2) + 1, y = math.floor((root.h - 9)/2) + 1, w = 10, h = 9, bc = colors.gray, fc = colors.white}
	page.Player1.team = 'w'
	page.Player1.ready = false
	page.Player1.nickname = user.Nickname
	page.Player1.img = blittle.load(APPDIR .. 'Data/ChessProfile.ico')
	page.Player1.oldDraw = page.Player1.draw
	function page.Player1:draw()
		self.bc = self.ready and colors.green or colors.gray
		self:oldDraw()
		blittle.draw(self.img, self.x + 1, self.y + 1)
		term.setCursorPos(self.x + math.floor((self.w - #self.nickname)/2), self.y + self.h - 2)
		term.setBackgroundColor(self.bc)
		term.setTextColor(self.fc)
		term.write(self.nickname)
		term.setCursorPos(4 + self.x, self.y + self.h - 1)
		term.setBackgroundColor(self.bc)
		term.setTextColor((self.team == 'w') and colors.white or colors.black)
		term.write('\7')
	end
	page.surface:addChild(page.Player1)

	page.btnReady = UI.Button{x = root.w - 9, y = root.h - 1, w = 9, h = 1, bc = colors.gray, fc = colors.white, text = "Ready"}
	page.surface:addChild(page.btnReady)
	function page.btnReady:pressed()
		page.Player1.ready = not page.Player1.ready
		if page.Player1.ready then
			page.rbtnTeam:setDisabled(true)
			page.dropdownTime:setDisabled(true)
			if page.tfCustom then page.tfCustom:setDisabled(true) end
			if page.tfFEN then page.tfFEN:setDisabled(true) end
			self:setText('Unready')
		else
			page.rbtnTeam:setDisabled()
			if network.server then
				if page.tfCustom then page.tfCustom:setDisabled() end
				if page.tfFEN then page.tfFEN:setDisabled(true) end
				page.dropdownTime:setDisabled()
			end
			self:setText('Ready')
		end
		page.Player1.dirty = true
		local message = {type = 'lobby_update', ready = page.Player1.ready, team = page.Player1.team, nickname = user.Nickname}
		if network.server then network:broadcast(message)
		else network:sendTo(message)
		end
	end

	if network.server then
		page.btnPlay = UI.Button{x = page.btnReady.x - 4, y = page.btnReady.y, w = 3, h = 1, bc = colors.gray, fc = colors.white, text = "\16"}
		page.surface:addChild(page.btnPlay)
		function page.btnPlay:pressed()
			if not page.Player1.ready or (not page.Player2) then return end
			if not page.Player2.ready then return end
			if page.Player1.team == page.Player2.team then return end
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
			network:broadcast{type = 'start_game', fen = page.tfFEN.text, time = time, increment = increment}
			Screen:switch('startGame', page.Player1.team, page.tfFEN.text, time, page.Player2.nickname, increment)
		end

		page.tfFEN = UI.Textfield{x = 2, y = root.h - 1, w = 30, h = 1, bc = colors.gray, fc = colors.white, hint = 'FEN'}
		page.surface:addChild(page.tfFEN)
	end

	function page.surface.onResize(width, height)
		page.surface.w, page.surface.h = width, height
		page.rbtnTeam.lX = width - 7
		local P1Y = math.floor((root.h - page.Player1.h)/2) + 1
		local P1X = page.Player2 and math.floor((root.w - 12 - page.Player1.w*2)/2) + 1 or math.floor((root.w - 12 - page.Player1.w)/2) + 1
		page.Player1.lX, page.Player1.lY = P1X, P1Y < 4 and 4 or P1Y
		page.btnReady.lX, page.btnReady.lY = width - 9, height - 1
		page.labelTime.lX = width - 9
		page.dropdownTime.lX = page.labelTime.lX + 1
		if page.btnPlay then
			page.btnPlay.lX, page.btnPlay.lY = page.btnReady.lX - 4, page.btnReady.lY
			page.tfFEN.lY = height - 1
		end
		if page.tfCustom then
			page.tfCustom.lX = page.dropdownTime.lX - 1
		end
		if page.Player2 then
			page.Player2.lY, page.Player2.lX = P1Y < 4 and 4 or P1Y, page.Player1.lX + page.Player1.w + 1
		end
	end

	function page.createUI(recieve)
		page.Player1.lX = math.floor((root.w - 12 - 21)/2) + 1

		page.Player2 = UI.Box{x = page.Player1.lX + page.Player1.w + 1, y = page.Player1.y, w = page.Player1.w, h = page.Player1.h, bc = colors.gray, fc = colors.white}
		page.Player2.nickname = recieve.nickname
		page.Player2.img = page.Player1.img
		page.Player2.oldDraw = page.Player2.draw
		page.Player2.draw = page.Player1.draw
		page.surface:addChild(page.Player2)

		if network.server then
			page.btnKick.lX = page.Player2.x + 3
			page.btnKick.lY = page.Player2.y + page.Player2.h + 1
		end

		page.surface:onLayout()
	end

	function network.connectHandler(_, client)
		if page.Player2 then
			return network:closeClient(client.clientID)
		end
		page.btnKick = UI.Button{text = 'Kick', x = 0, y = 0, w = #('Kick'), h = 1, bc = colors.red, fc = colors.white}
		function page.btnKick:pressed() client.close() end
		page.surface:addChild(page.btnKick)
	end
	function network.closeHandler()
		if not network.server then
			Screen:switch('mainMenu')
		else
			page.Player1.lX = math.floor((root.w - 12 - page.Player1.w)/2) + 1
			page.surface:removeChild(page.Player2)
			page.surface:removeChild(page.btnKick)
			page.surface:onLayout()
			page.Player2 = nil
			page.btnKick = nil
		end
	end
	function network.messageHandler(userdata, message, bool)
		local recieve = textutils.unserialiseJSON(message)
		local Type = recieve.type

		if Type == 'lobby_join' and not page.Player2 then
			page.createUI(recieve)
			page.Player2.team = recieve.team
			network:broadcast{type = 'lobby_update', nickname = user.Nickname, ready = page.Player1.ready, team = page.Player1.team, time = page.dropdownTime.item_index}
		elseif Type == 'lobby_update' then
			if not page.Player2 then page.createUI(recieve) end
			page.Player2.ready = recieve.ready
			page.Player2.team = recieve.team
			page.Player2.dirty = true
			if recieve.time then
				page.dropdownTime.item_index = recieve.time
				page.dropdownTime.dirty = true
			end
		elseif Type == 'start_game' then
			Screen:switch('startGame', page.Player1.team, recieve.fen, recieve.time, page.Player2.nickname, recieve.increment)
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
	function page.btnExit:pressed()
		Screen:switch('mainMenu')
	end

	-- page.btnL = UI.Button{x = 6, y = 2, w = 1, h = 1, bc = colors.gray, fc = colors.white, text = 'L'}
	-- page.surface:addChild(page.btnL)
	-- function page.btnL:pressed()
	-- 	page.tfIP.text = 'localhost'
	-- 	page.tfIP.dirty = true
	-- end

	-- page.btnV = UI.Button{x = 8, y = 2, w = 1, h = 1, bc = colors.gray, fc = colors.white, text = 'V'}
	-- page.surface:addChild(page.btnV)
	-- function page.btnV:pressed()
	-- 	page.tfIP.text = '192.168.191.153'
	-- 	page.tfIP.dirty = true
	-- end

	-- page.btnA = UI.Button{x = 10, y = 2, w = 1, h = 1, bc = colors.gray, fc = colors.white, text = 'A'}
	-- page.surface:addChild(page.btnA)
	-- function page.btnA:pressed()
	-- 	page.tfIP.text = '192.168.191.87'
	-- 	page.tfIP.dirty = true
	-- end

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

	function page.btnConnect:pressed()
		local ret, err
		if user.ServerType == 'Rednet' then
			ret, err = network:connectToServer(page.tfIP.text)
		else
			ret, err = network:connectToServer(page.tfIP.text, port)
		end
		if not ret then
			page.labelError.fc = colors.red
			page.labelError:setText(err)
			return
		end
		network:sendTo{type = 'lobby_join', nickname = user.Nickname, ready = false, team = 'w'}
		Screen:switch('lobbyMenu')
	end

	function page.surface.onResize(width, height)
		page.surface.w, page.surface.h = width, height
		page.labelIP.lX, page.labelIP.lY = math.floor((width - 26)/2) + 1, math.floor((height - 2)/2) + 1
		page.tfIP.lX, page.tfIP.lY = page.labelIP.lX + page.labelIP.w + 1, page.labelIP.lY
		page.btnConnect.lX, page.btnConnect.lY = math.floor((width - 7)/2) + 1, page.labelIP.lY + 2
		page.labelError.lY, page.labelError.w = page.labelIP.lY - 2, width
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
	page.logo.img = blittle.load(APPDIR .. 'Data/logo.ico')
	function page.logo:draw()
		blittle.draw(self.img, self.x, self.y)
	end

	page.labelNickname = UI.Label{x = 1, y = 1, w = 10, h = 1, bc = page.surface.bc, fc = colors.white, text = "Nickname: "}
	page.surface:addChild(page.labelNickname)

	page.nickname = UI.Textfield{x = page.labelNickname.x + page.labelNickname.w, y = 1, w = 10, h = 1, bc = colors.gray, fc = colors.white}
	page.surface:addChild(page.nickname)
	page.nickname.text = user.Nickname
	page.nickname.oldFocus = page.nickname.onFocus
	function page.nickname:onFocus(focused)
		if not focused and self.text ~= user.Nickname then
			user.Nickname = self.text
			user()
		end
		return self:oldFocus(focused)
	end

	local center = math.floor((root.w - 14)/2)+1
	page.btnCreate = UI.Button{x = center, y = page.logo.y + page.logo.h + 1, w = 8, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Create"}
	page.surface:addChild(page.btnCreate)
	function page.btnCreate:pressed()
		local ret, err
		if user.ServerType == 'Rednet' then
			ret, err = network:startServer()
		else
			ret, err = network:startServer(port)
		end
		if not ret then
			return notification(err)
		end
		Screen:switch('lobbyMenu')
	end

	page.btnJoin = UI.Button{x = center + 9, y = page.logo.y + page.logo.h + 1, w = 6, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Join", bc_hc = colors.lightGray, fc_hc = colors.black}
	page.surface:addChild(page.btnJoin)
	function page.btnJoin:pressed()
		Screen:switch('joinMenu')
	end

	page.btnLocalGame = UI.Button{x = center, y = page.logo.y + page.logo.h + 3, w = 15, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Local Game", bc_hc = colors.lightGray, fc_hc = colors.black}
	page.surface:addChild(page.btnLocalGame)
	function page.btnLocalGame:pressed()
		Screen:switch('startGame', 'w', '')
	end

	page.btnSettings = UI.Button{x = center, y = page.btnLocalGame.y + 2, w = 15, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Settings", bc_hc = colors.lightGray, fc_hc = colors.black}
	page.surface:addChild(page.btnSettings)
	function page.btnSettings:pressed()
		Screen:openModal('settingsMenu')
	end

	page.btnQuit = UI.Button{x = center, y = page.btnSettings.y + 2, w = 15, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Quit", bc_hc = colors.lightGray, fc_hc = colors.black}
	page.surface:addChild(page.btnQuit)
	function page.btnQuit:pressed()
		os.queueEvent('terminate')
	end

	page.btnAbout = UI.Button{x = root.w - 3, y = 2, w = 3, h = 1, bc = colors.gray, fc = colors.white, text = "?"}
	page.surface:addChild(page.btnAbout)
	function page.btnAbout:pressed()
		Screen:openModal('aboutMenu')
	end

	page.labelVersion = UI.Label{x = 1, y = root.h - 1, w = #('Ver.:' .. APPVERSION), h = 1, bc = page.surface.bc, fc = colors.gray, text = 'Ver.:' .. APPVERSION, align = "left"}
	page.surface:addChild(page.labelVersion)

	page.btnUpdate = UI.Button{x = 1, y = root.h, w = 16, h = 1, radius = 5, text = 'Check for update', bc = colors.gray, fc = colors.white}
	page.btnUpdate.loading = 0
	function page.btnUpdate:draw()
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
	function page.btnUpdate:pressed()
		if jit then
			return notification('Dont use Jit for updates')
		end
		local link = 'https://raw.githubusercontent.com/aTimmYm/Chess/refs/heads/dev/'
		local response, err = http.get(link .. 'sha256-sums')
		if response then
			local shaSum = response.readAll()
			response.close()
			local ret, filesToUpdate = checkUpdates(shaSum)
			if ret then
				self:setText('Updating')
				for i = 1, #filesToUpdate do
					local path = filesToUpdate[i]
					local request = http.get(link .. path)
					if request then
						-- log('UPDATE: ' .. APPDIR .. path)
						write_file(APPDIR .. path, request.readAll())
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

	function page.surface.onResize(width, height)
		page.surface.w, page.surface.h = width, height
		center = math.floor((width - 14)/2) + 1
		page.logo.lX = math.floor((width - 6)/2) + 1
		page.btnCreate.lX = center
		page.btnJoin.lX = center + 9
		page.btnLocalGame.lX, page.btnLocalGame.lY = center, page.logo.lY + page.logo.h + 3
		page.btnSettings.lX, page.btnSettings.lY = center, page.btnLocalGame.lY + 2
		page.btnQuit.lX = center
		page.btnAbout.lX = width - 3
		page.labelVersion.lY = height - 1
		page.btnUpdate.lY = height
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
	elseif event == 'peripheral' or event == 'peripheral_detach' then
		speaker:updateOutputs()
		network:updateModems()
	end
	root:onEvent(evt)
end