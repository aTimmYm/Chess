local UI = require "UIGM"
local font = require "Font"
local speaker = require "Speaker"
local Screen = require "ScreenManager"
local Chess = require "Chess"
local network = require "Network"
local user = require 'Settings'
local localization = dofile(Chess.path .. 'Data/localization.lua')
local g = require 'geometry'
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

local LC = localization[user.Language]

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

Chess.CELL_W = 14
Chess.CELL_H = 14
Chess.T_DELTA_W = 6
Chess.T_DELTA_H = 9
Chess.BOARD_W = Chess.T_DELTA_W * 2 + 8 * Chess.CELL_W
Chess.BOARD_H = Chess.T_DELTA_H * 2 + 8 * Chess.CELL_H
BOARD_BG[user.ColorScheme]()

local root = UI.Root()
Screen.surface = root

local sounds = {
	['move'] = Chess.path .. 'Data/sounds/chess_move',
	['capture'] = Chess.path .. 'Data/sounds/chess_capture',
	['checkmate'] = Chess.path .. 'Data/sounds/chess_checkmate',
}
local VOLUMES = {}
for i = 0, 14 do
	VOLUMES[i + 1] = i/14*3
end

local exeption = {
	['rom'] = true,
	['.git'] = true,
	[Chess.path .. 'Data/Settings/user.json'] = true
}

local function notification(msg)
	-- box = UI.Box{x = 0, y = 15, w = 80, h = 25, bc = colors.green, fc = colors.white, radius = 2}
	-- root:addChild(box)
	local box = UI.Label{x = -1, y = 5, w = 80, h = 22, bc = colors.red, fc = colors.white, radius = 2, text = msg}
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

	for _, file in ipairs(files) do
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
	listAllFiles(Chess.path, files)

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
		log('USER: '.. path .. ' | ' .. hash)
		if not hashList[path] then
			-- fs.delete(path)
			ret = true
		end
	end
	for path, hash in pairs(hashList) do
		log('SUMS: '.. path .. ' | ' .. hash)
		local absPath = Chess.path .. path
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

	page.surface = UI.Box{x = 0, y = 0, w = root.w, h = root.h, bc = colors.black}
	root:addChild(page.surface)

	page.btnExit = UI.Button{x = 5, y = 5, w = 20, h = 10, radius = 5, bc = colors.gray, fc = colors.white, text = '←'}
	page.surface:addChild(page.btnExit)
	function page.btnExit:pressed()
		user()
		Screen:closeModal()
	end

	page.labelSettings = UI.Label{x = math.floor((root.w - font.calcWidth(font.upper(LC.settings)))/2) + 1, y = 5, w = font.calcWidth(font.upper(LC.settings)), h = 10, text = font.upper(LC.settings), bc = page.surface.bc, fc = colors.white}
	page.surface:addChild(page.labelSettings)

	page.scrollBox = UI.ScrollBox{x = 0, y = 20, w = root.w - 4, h = root.h - 20, bc = page.surface.bc, fc = colors.white}
	page.surface:addChild(page.scrollBox)
	local scrollbar_v = UI.Scrollbar(page.scrollBox)
	page.surface:addChild(scrollbar_v)

	page.labelSound = UI.Label{x = 30, y = 10, w = font.calcWidth(LC.sound), h = 8, text = LC.sound, bc = page.scrollBox.bc, fc = colors.white}
	page.scrollBox:addChild(page.labelSound)

	page.labelOutput = UI.Label{x = page.labelSound.x, y = page.labelSound.y + page.labelSound.h + 5, w = font.calcWidth(LC.output_device), h = 8, text = LC.output_device, bc = page.scrollBox.bc, fc = colors.lightGray}
	page.scrollBox:addChild(page.labelOutput)

	page.dropdownOutput = UI.Dropdown{x = page.labelOutput.x + page.labelOutput.w + 10, y = page.labelOutput.y, w = 50, h = 10, radius = 2, bc = colors.white, fc = colors.black, array = speaker.getOutputs(), defaultValue = (user.OutputDevice ~= "") and user.OutputDevice}
	page.scrollBox:addChild(page.dropdownOutput)
	function page.dropdownOutput:pressed(element)
		user.OutputDevice = element
	end

	page.labelVolume = UI.Label{x = page.labelOutput.x, y = page.labelOutput.y + page.labelOutput.h + 5, w = font.calcWidth(LC.volume), h = 8, text = LC.volume, bc = page.scrollBox.bc, fc = colors.lightGray}
	page.scrollBox:addChild(page.labelVolume)

	page.sliderVolume = UI.Slider{x = page.labelVolume.x + page.labelVolume.w + 10, y = page.labelVolume.y + 2, w = 50, h = 6, bc = page.scrollBox.bc, fc = colors.white, fc_alt = colors.blue, bc_alt = colors.lightGray, fc_cl = colors.gray, arr = VOLUMES, slidePosition = user.Volume}
	page.scrollBox:addChild(page.sliderVolume)
	function page.sliderVolume:pressed()
		user.Volume = self.slidePosition
		speaker.setVolume(self.arr[self.slidePosition])
	end

	page.labelInterface = UI.Label{x = page.labelSound.x, y = page.labelVolume.y + page.labelVolume.h + 10, w = font.calcWidth(LC.interface), h = 8, text = LC.interface, bc = page.scrollBox.bc, fc = colors.white}
	page.scrollBox:addChild(page.labelInterface)

	page.labelScheme = UI.Label{x = page.labelInterface.x, y = page.labelInterface.y + page.labelInterface.h + 5, w = font.calcWidth(LC.color_scheme), h = 8, text = LC.color_scheme, bc = page.scrollBox.bc, fc = colors.lightGray}
	page.scrollBox:addChild(page.labelScheme)

	local schemes = {}
	for k,_ in pairs(BOARD_BG) do table.insert(schemes, k) end
	table.sort(schemes)
	page.dropdownScheme = UI.Dropdown{x = page.labelScheme.x + page.labelScheme.w + 10, y = page.labelScheme.y, w = 60, h = 10, radius = 2, bc = colors.white, fc = colors.black, array = schemes, defaultValue = user.ColorScheme}
	page.scrollBox:addChild(page.dropdownScheme)
	function page.dropdownScheme:pressed(element)
		BOARD_BG[element]()
		Chess.cacheGlyphs(Chess.BOARD_FG_A, Chess.BOARD_FG_B)
		user.ColorScheme = element
		local cS = Screen:getCurrent()
		if cS and cS.boardUI then
			cS.boardUI.cachedBG = nil
		end
	end

	page.boxColor = UI.Box{x = page.dropdownScheme.x + page.dropdownScheme.w + 50, y = page.labelScheme.y, w = 42, h = 28, bc = colors.red}
	page.scrollBox:addChild(page.boxColor)
	function page.boxColor:draw()
		local glyph = {'wp', 'wq', 'wn', 'bb', 'bk', 'br'}
		local count = 1
		for y = 0, 1 do
			for x = 0, 2 do
				local bc = ((x + y) % 2 == 0) and Chess.BOARD_BG_A or Chess.BOARD_BG_B
				local dX, dY = self.x + x * 14, self.y + y * 14
				term.drawPixels(dX, dY, bc, 14, 14)
				Chess.drawPiece(dX, dY, Chess.cacheGlyph[glyph[count]], Chess.CELL_W, Chess.CELL_H)
				count = count + 1
			end
		end
	end

	page.labelLanguage = UI.Label{x = page.labelScheme.x, y = page.labelScheme.y + page.labelScheme.h + 5, w = font.calcWidth(LC.language), h = 10, text = LC.language, bc = page.scrollBox.bc, fc = colors.lightGray}
	page.scrollBox:addChild(page.labelLanguage)

	page.dropdownLanguage = UI.Dropdown{x = page.labelLanguage.x + page.labelLanguage.w + 10, y = page.labelLanguage.y, w = 60, h = 10, radius = 2, bc = colors.white, fc = colors.black, array = {'eng','ukr','rus'}, defaultValue = user.Language}
	page.scrollBox:addChild(page.dropdownLanguage)
	function page.dropdownLanguage:pressed(element)
		LC = localization[element]
		user.Language = element
	end

	if http then
		page.labelNetwork = UI.Label{x = page.labelInterface.x, y = page.labelLanguage.y + page.labelLanguage.h + 10, w = font.calcWidth(LC.network), h = 10, bc = page.scrollBox.bc, fc = colors.white, text = LC.network}
		page.scrollBox:addChild(page.labelNetwork)

		page.labelServerType = UI.Label{x = page.labelInterface.x, y = page.labelNetwork.y + page.labelNetwork.h + 5, w = font.calcWidth(LC.connection_type), h = 10, bc = page.scrollBox.bc, fc = colors.lightGray, text = LC.connection_type}
		page.scrollBox:addChild(page.labelServerType)

		local arr = http.websocketServer and {'Rednet','WebSocket'} or {'Rednet'}

		page.dropdownServer =  UI.Dropdown{x = page.labelServerType.x + page.labelServerType.w + 10, y = page.labelServerType.y, w = 65, h = 10, radius = 2, bc = colors.white, fc = colors.black, array = arr, defaultValue = user.ServerType}
		page.scrollBox:addChild(page.dropdownServer)
		function page.dropdownServer:pressed(element)
			user.ServerType = element
		end
	end

	function page.surface:onResize(width, height)
		page.surface.w, page.surface.h = width, height
		page.scrollBox.w, page.scrollBox.h = width - 4, height - 20
		page.labelSettings.local_x = math.floor((width - 48)/2) + 1
	end

	return page
end
Screen:register('settingsMenu', SettingsMenu)

local AboutMenu = {}
function AboutMenu.new()
	local page = {}

	page.surface = UI.Box{x = 0, y = 0, w = root.w, h = root.h, bc = colors.black}
	root:addChild(page.surface)

	page.labelAbout = UI.Label{x = math.floor((root.w - font.calcWidth(LC.about))/2) + 1, y = 5, w = font.calcWidth(LC.about), h = 10, text = LC.about, bc = page.surface.bc, fc = colors.white}
	page.surface:addChild(page.labelAbout)

	page.btnExit = UI.Button{x = 5, y = 5, w = 20, h = 10, radius = 5, bc = colors.gray, fc = colors.white, text = '←'}
	page.surface:addChild(page.btnExit)
	function page.btnExit:pressed()
		Screen:closeModal()
	end

	page.scrollBox = UI.ScrollBox{x = 0, y = page.btnExit.y + page.btnExit.h + 5, w = page.surface.w - 5, h = page.surface.h - (page.btnExit.y + page.btnExit.h + 5), bc = colors.black, fc = colors.white}
	page.surface:addChild(page.scrollBox)

	local scrollbar = UI.Scrollbar(page.scrollBox)
	page.surface:addChild(scrollbar)

	--==TEXT ABOUT==--
	local x, Height, w = 10, 0, page.scrollBox.w - 20
	for i = 1, 5 do
		local t = LC['about_textBlock'..i]
		local h = (#(UI.wrap_text_to_width(t, w))) * font.charHeight
		local l = UI.Label{text = t,x = x, y = Height, w = w, h = h, bc = page.scrollBox.bc, fc = page.scrollBox.fc, align = 'lefttop'}
		page.scrollBox:addChild(l)
		Height = l.y + l.h
	end

	function page.scrollBox.onResize(width, height)
		local Height, w = 0, width - 20
		for i, child in ipairs(page.scrollBox.children) do
			local t = LC['about_textBlock'..i]
			local h = (#(UI.wrap_text_to_width(t, w))) * font.charHeight
			child.w = w
			child.h = h
			child.local_y = Height
			Height = child.local_y + child.h
			child._layout_dirty = true
		end
	end

	function page.surface.onResize(width, height)
		page.surface.w, page.surface.h = width, height
		page.labelAbout.local_x = math.floor((root.w - font.calcWidth(LC.about))/2) + 1
		page.scrollBox.w, page.scrollBox.h = page.surface.w - 5, page.surface.h - (page.btnExit.y + page.btnExit.h + 5)
		scrollbar.local_x, scrollbar.h = page.scrollBox.x + page.scrollBox.w, page.scrollBox.h
		page.scrollBox.onResize(page.scrollBox.w, page.scrollBox.h)
	end

	return page
end
Screen:register('aboutMenu', AboutMenu)

local StartGame = {}
function StartGame.new(self, team, FEN, time, nickname, increment)
	local page = {}

	page.surface = UI.Box{ x = 0, y = 0, w = root.w, h = root.h, bc = colors.black }
	root:addChild(page.surface)

	page.boardUI = Chess.Board{ x = math.floor((root.w - 91 - Chess.BOARD_W)/2) + 1, y = math.floor((root.h - Chess.BOARD_H)/2) + 1, w = Chess.BOARD_W, h = Chess.BOARD_H, bc = colors.black, fc = colors.lightGray, bc_alt = colors.orange }
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

		local box = UI.Box{ x = -1, y = 5, w = 106, h = 23, radius = 2, bc = colors.green}
		root:addChild(box)
		local label = UI.Label{text = 'Choose promotion', x = 2, y = 0, w = box.w - 2, h = box.h, radius = 2, bc = box.bc, fc = colors.white, align = 'left_top'}
		box:addChild(label)
		local btnClose = UI.Button{x = box.w - 7, y = 0, w = 6, h = 9, bc = box.bc, fc = colors.gray, text = 'x', bc_cl = box.bc, fc_cl = colors.lightGray}
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
		local ddChoose = UI.Dropdown{x = 2, y = box.h - 11, w = 42, h = 10, radius = 2, bc = colors.gray, fc = colors.white, array = {'Queen', 'Bishop', 'Rook', 'Knight'}}
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

	page.btnExit = UI.Button{x = 5, y = 5, w = 20, h = 10, radius = 5, bc = colors.gray, fc = colors.white, text = '←'}
	page.surface:addChild(page.btnExit)
	function page.btnExit:pressed()
		if network.running then
			if network.server then network:stopServer()
			else network:disconnectFromServer()
			end
		end
		Screen:switch('mainMenu')
	end

	page.btnSettings = UI.Button{x = page.btnExit.x + page.btnExit.w + 5, y = page.btnExit.y, w = 10, h = 10, radius = 5, text = '', bc = colors.gray, fc = colors.white}
	page.surface:addChild(page.btnSettings)
	page.btnSettings.oldDraw = page.btnSettings.draw
	function page.btnSettings:draw()
		self:oldDraw()
		local fg = self.held and self.bc or self.fc
		local d = 2
		term.setPixel(self.x + d, self.y + d, fg)
		term.setPixel(self.x + d + 1, self.y + d + 1, fg)
		term.setPixel(self.x + d + 4, self.y + d + 4, fg)
		term.setPixel(self.x + d + 5, self.y + d + 5, fg)
		term.setPixel(self.x + d + 1, self.y + d + 4, fg)
		term.setPixel(self.x + d, self.y + d + 5, fg)
		term.setPixel(self.x + d + 4, self.y + d + 1, fg)
		term.setPixel(self.x + d + 5, self.y + d, fg)
		for i = 1, 3 do
			for j = 1, 3 do
				if (i + j) % 2 ~= 0 then
					term.drawPixels(self.x + i * 2, self.y + j * 2, fg, 2, 2)
				end
			end
		end
	end
	function page.btnSettings:pressed()
		Screen:openModal('settingsMenu')
	end

	page.btnRotate = UI.Button{x = page.btnSettings.x + page.btnSettings.w + 5, y = page.btnSettings.y, w = 10, h = 10, text = '↕', radius = 5, fc = colors.white, bc = colors.gray}
	page.surface:addChild(page.btnRotate)
	function page.btnRotate:pressed()
		page.boardUI.rotate = not page.boardUI.rotate
		--players
		if ((team == 'w' and page.boardUI.rotate) or (team == 'b' and not page.boardUI.rotate)) then
			page.Player1.local_y = page.boxPanel.h - 10
			page.Player2.local_y = 0
		else
			page.Player1.local_y = 0
			page.Player2.local_y = page.boxPanel.h - 10
		end
		--timers
		page.timerW.local_y = page.boardUI.rotate and page.boxPanel.y + page.boxPanel.h + 1 or page.boxPanel.y - 11
		page.timerB.local_y = page.boardUI.rotate and page.boxPanel.y - 11 or page.boxPanel.y + page.boxPanel.h + 1
		page.labelMaterialW.local_y = page.timerW.local_y
		page.labelMaterialB.local_y = page.timerB.local_y

		page.surface:onLayout()
	end

	page.labelMessage = UI.Label{x = page.btnRotate.x + page.btnRotate.w + 5, y = page.btnRotate.y, w = root.w - 133, h = 10, fc = colors.lightGray, bc = page.surface.bc, align = 'center'}
	page.surface:addChild(page.labelMessage)

	if network.running then
		page.btnResign = UI.Button{x = root.w - 35, y = page.btnRotate.y, w = 30, h = 10, radius = 5, bc = colors.gray, fc = colors.white, text = '', align = "center"}
		page.surface:addChild(page.btnResign)
		page.btnResign.oldDraw = page.btnResign.draw
		function page.btnResign:draw()
			self:oldDraw()
			local cX = math.floor((self.w - 6)/2)
			local fg = self.held and self.bc or self.fc
			term.drawPixels(self.x + cX, self.y + 3, fg, 2, 4)
			term.drawPixels(self.x + cX + 2, self.y + 2, fg, 4, 4)
			term.drawPixels(self.x + cX + 5, self.y + 6, fg, 1, 2)
		end
		function page.btnResign:pressed()
			if page.game.over then return end
			local message = {type = 'game_resign'}
			if network.server then network:broadcast(message)
			else network:sendTo(message)
			end
			page.game:gameOver((team == 'w') and 'Black wins by resignation' or 'White wins by resignation')
		end

		page.btnOfferdraw = UI.Button{x = page.btnResign.x - 35, y = page.btnResign.y, w = 30, h = 10, radius = 5, bc = colors.gray, fc = colors.white, text = "1/2", align = "center"}
		page.surface:addChild(page.btnOfferdraw)
		function page.btnOfferdraw:pressed()
			if page.game.over then return end
			local message = {type = 'game_offerdraw', team = Team}
			if network.server then network:broadcast(message)
			else network:sendTo(message)
			end
		end
	else
		page.btnRestart = UI.Button{x = root.w - 70, y = page.btnRotate.y, w = 65, h = 10, radius = 5, bc = colors.gray, fc = colors.white, text = LC.restart, align = "center"}
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

	page.boxPanel = UI.Box{x = root.w - 91, y = math.floor((root.h - 71)/2) + 1, w = 91, h = 71, radius = 2, bc = colors.gray, fc = colors.white}
	page.surface:addChild(page.boxPanel)

	page.Player1 = UI.Label{x = 1, y = ((team == 'w' and page.boardUI.rotate) or (team == 'b' and not page.boardUI.rotate)) and page.boxPanel.h - 10 or 0, w = page.boxPanel.w - 2, h = 10, bc = page.boxPanel.bc, fc = page.boxPanel.fc, text = nickname and "•".. user.Nickname or "•Player1", align = "left"}
	page.boxPanel:addChild(page.Player1)

	page.Player2 = UI.Label{x = 1, y = ((team == 'w' and page.boardUI.rotate) or (team == 'b' and not page.boardUI.rotate)) and 0 or page.boxPanel.h - 10, w = page.boxPanel.w - 2, h = 10, bc = page.boxPanel.bc, fc = page.boxPanel.fc, text = nickname and "•".. nickname or "•Player2", align = "left"}
	page.boxPanel:addChild(page.Player2)

	page.list = UI.List{x = 0, y = 10, w = page.boxPanel.w, h = page.boxPanel.h - 20, bc = page.boxPanel.bc, fc = colors.lightGray, array = page.game.history}
	page.boxPanel:addChild(page.list)
	function page.list:onMouseDown() end

	page.timerW = UI.Timer{x = page.boxPanel.x, y = page.boardUI.rotate and page.boxPanel.y + page.boxPanel.h + 1 or page.boxPanel.y - 11, w = 50, h = 10, radius = 5, bc = colors.gray, fc = colors.white, time = time}
	page.surface:addChild(page.timerW)
	page.timerW.oldDraw = page.timerW.draw
	function page.timerW:draw()
		if Screen.modal then return end
		return self:oldDraw()
	end
	function page.timerW:pressed()
		page.game:gameOver('White out of time')
	end

	page.timerB = UI.Timer{x = page.boxPanel.x, y = page.boardUI.rotate and page.boxPanel.y - 11 or page.boxPanel.y + page.boxPanel.h + 1, w = 50, h = 10, radius = 5, bc = colors.gray, fc = colors.white, time = time}
	page.surface:addChild(page.timerB)
	page.timerB.oldDraw = page.timerB.draw
	page.timerB.draw = page.timerW.draw
	function page.timerB:pressed()
		page.game:gameOver('Black out of time')
	end

	local mW, mB = page.game:getMaterial()

	page.labelMaterialW = UI.Label{text = tostring(mW - mB), x = root.w - 24, y = page.timerW.y, w = 24, h = 10, bc = page.surface.bc, fc = colors.gray, align = 'right'}
	page.surface:addChild(page.labelMaterialW)

	page.labelMaterialB = UI.Label{text = tostring(mB - mW), x = root.w - 24, y = page.timerB.y, w = 24, h = 10, bc = page.surface.bc, fc = colors.gray, align = 'right'}
	page.surface:addChild(page.labelMaterialB)

	if not network.running then
		page.tfFEN = UI.Textfield{x = 5, y = page.surface.h - 15, w = root.w - 25, h = 10, radius = 2, hint = "Type FEN", fc = colors.white, bc = colors.gray}
		page.surface:addChild(page.tfFEN)

		page.btnFEN = UI.Button{x = root.w - 15, y = page.tfFEN.y, w = 10, h = 10, text = ">", radius = 10, fc = colors.white, bc = colors.gray}
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
		page.boardUI.local_x = math.floor((width - 91 - Chess.BOARD_W)/2) + 1
		page.boardUI.local_y = math.floor((height - Chess.BOARD_H)/2) + 1
		page.boxPanel.local_x = width - 91
		page.boxPanel.local_y = math.floor((height - 71)/2) + 1
		if not network.running then
			page.tfFEN.local_y, page.tfFEN.w = height - 15, width- 25
			page.btnFEN.local_x, page.btnFEN.local_y = width - 15, page.tfFEN.local_y
			page.btnRestart.local_x = width - 70
		else
			page.btnResign.local_x = width - 35
			page.btnOfferdraw.local_x = page.btnResign.local_x - 35
		end
		page.labelMessage.w = width - 133
		page.timerW.local_x, page.timerW.local_y = page.boxPanel.local_x, page.boardUI.rotate and page.boxPanel.local_y + page.boxPanel.h + 1 or page.boxPanel.local_y - 11
		page.timerB.local_x, page.timerB.local_y = page.boxPanel.local_x, page.boardUI.rotate and page.boxPanel.local_y - 11 or page.boxPanel.local_y + page.boxPanel.h + 1
		page.labelMaterialW.local_x, page.labelMaterialW.local_y = width - 24, page.timerW.local_y
		page.labelMaterialB.local_x, page.labelMaterialB.local_y = width - 24, page.timerB.local_y
		if page.labelOfferdraw then
			page.labelOfferdraw.local_x, page.labelOfferdraw.local_y = math.floor((width - 25)/2) + 1, height - 15
			page.btnYes.local_x, page.btnYes.local_y = page.labelOfferdraw.local_x + page.labelOfferdraw.w + 5, page.labelOfferdraw.local_y
			page.btnNo.local_x, page.btnNo.local_y = page.btnYes.local_x + page.btnYes.w + 5, page.labelOfferdraw.local_y
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
				page.labelOfferdraw = UI.Label{x = math.floor((root.w - 25)/2) + 1, y = root.h - 15, w = font.calcWidth(team .. ' offers draw') + 30, h = 10, text = team .. ' offers draw', bc = page.surface.bc, fc = colors.white}
				page.surface:addChild(page.labelOfferdraw)

				page.btnYes = UI.Button{x = page.labelOfferdraw.x + page.labelOfferdraw.w + 5, y = page.labelOfferdraw.y, w = 10, h = 10, radius = 5, text = 'Y', bc = colors.green, fc = colors.white}
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
				page.btnNo = UI.Button{x = page.btnYes.x + page.btnYes.w + 5, y = page.labelOfferdraw.y, w = 10, h = 10, radius = 5, text = 'N', bc = colors.red, fc = colors.white}
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

	page.surface = UI.Box{ x = 0, y = 0, w = root.w, h = root.h, bc = colors.black }
	root:addChild(page.surface)

	page.btnExit = UI.Button{x = 5, y = 5, w = 20, h = 10, radius = 5, bc = colors.gray, fc = colors.white, text = '←'}
	page.surface:addChild(page.btnExit)
	function page.btnExit:pressed()
		if network.running then
			if network.server then network:stopServer()
			else network:disconnectFromServer()
			end
		end
		Screen:switch('mainMenu')
	end

	page.btnSettings = UI.Button{x = page.btnExit.x + page.btnExit.w + 5, y = page.btnExit.y, w = 10, h = 10, radius = 5, text = '', bc = colors.gray, fc = colors.white}
	page.btnSettings.oldDraw = page.btnSettings.draw
	function page.btnSettings:draw()
		self:oldDraw()
		local fg = self.held and self.bc or self.fc
		local d = 2
		term.setPixel(self.x + d, self.y + d, fg)
		term.setPixel(self.x + d + 1, self.y + d + 1, fg)
		term.setPixel(self.x + d + 4, self.y + d + 4, fg)
		term.setPixel(self.x + d + 5, self.y + d + 5, fg)
		term.setPixel(self.x + d + 1, self.y + d + 4, fg)
		term.setPixel(self.x + d, self.y + d + 5, fg)
		term.setPixel(self.x + d + 4, self.y + d + 1, fg)
		term.setPixel(self.x + d + 5, self.y + d, fg)
		for i = 1, 3 do
			for j = 1, 3 do
				if (i + j) % 2 ~= 0 then
					term.drawPixels(self.x + i * 2, self.y + j * 2, fg, 2, 2)
				end
			end
		end
	end
	page.surface:addChild(page.btnSettings)
	function page.btnSettings:pressed()
		Screen:openModal('settingsMenu')
	end

	page.labelLobby = UI.Label{x = page.btnSettings.x + page.btnSettings.w + 5, y = page.btnExit.y, w = 29, h = 10, bc = page.surface.bc, fc = colors.white, text = LC.lobby}
	page.surface:addChild(page.labelLobby)

	page.rbtnTeam = UI.RadioButton{x = root.w - 55, y = page.labelLobby.y + page.labelLobby.h + 5, w = font.calcWidth(LC.black) + 5, h = 16, bc = page.surface.bc, fc = colors.white, text = {LC.white, LC.black}}
	page.surface:addChild(page.rbtnTeam)
	function page.rbtnTeam:pressed(i)
		page.Player1.dirty = true
		page.Player1.team = (i == LC.white) and 'w' or 'b'
		local message = {type = 'lobby_update', ready = page.btnReady.ready, team = page.Player1.team, nickname = user.Nickname}
		if network.server then network:broadcast(message)
		else network:sendTo(message)
		end
	end

	page.labelTime = UI.Label{x = page.rbtnTeam.x, y = page.rbtnTeam.y + page.rbtnTeam.h + 15, w = font.calcWidth('Time Mode'), h = 10, text = 'Time Mode', fc = colors.white, bc = colors.black}
	page.surface:addChild(page.labelTime)

	page.dropdownTime = UI.Dropdown{x = page.labelTime.x, y = page.labelTime.y + 15, w = 50, h = 10, fc = colors.black, bc = colors.white, array = {'Off', '1+0', '2+1', '3+2', '5+3', '10+5', '30+20', 'custom'}, defaultValue = '5+3', radius = 2, disabled = not network.server}
	page.surface:addChild(page.dropdownTime)
	function page.dropdownTime:pressed(element)
		if element == 'custom' then
			page.tfCustom = UI.Textfield{x = self.x, y = self.y + self.h + 5, w = self.w, h = 10, bc = colors.gray, fc = colors.white}
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

	page.Player1 = UI.Box{x = math.floor((root.w - 60 - 48)/2) + 1, y = math.floor((root.h - 65)/2) + 1, w = 48, h = 65, radius = 5, bc = colors.gray, fc = colors.white}
	page.Player1.team = 'w'
	page.Player1.ready = false
	page.Player1.img = paintutils.loadImage(Chess.path .. 'Data/ChessProfile.nfp')
	page.Player1.nickname = user.Nickname
	page.Player1.oldDraw = page.Player1.draw
	function page.Player1:draw()
		self.bc = self.ready and colors.green or colors.gray
		self:oldDraw()
		paintutils.drawImage(self.img, math.floor((self.w - 28)/2) + self.x + 1, self.y + 6)
		font.drawText(self.nickname, self.x, self.y + self.h - 19, self.fc, self.w, 9, 'center')
		font.drawText('•', math.floor((self.w - 4)/2) + self.x, self.y + self.h - 10, (self.team == 'w') and colors.white or colors.black)
	end
	page.surface:addChild(page.Player1)

	page.btnReady = UI.Button{x = root.w - (font.calcWidth(LC.not_ready)+10) - 5, y = root.h - 15, w = font.calcWidth(LC.not_ready)+10, h = 10, radius = 6, bc = colors.gray, fc = colors.white, text = LC.ready}
	page.surface:addChild(page.btnReady)
	function page.btnReady:pressed()
		page.Player1.ready = not page.Player1.ready
		if page.Player1.ready then
			page.rbtnTeam:setDisabled(true)
			page.dropdownTime:setDisabled(true)
			if page.tfCustom then page.tfCustom:setDisabled(true) end
			if page.tfFEN then page.tfFEN:setDisabled(true) end
			self:setText(LC.not_ready)
		else
			page.rbtnTeam:setDisabled()
			if network.server then
				if page.tfCustom then page.tfCustom:setDisabled() end
				if page.tfFEN then page.tfFEN:setDisabled(true) end
				page.dropdownTime:setDisabled()
			end
			self:setText(LC.ready)
		end
		page.Player1.dirty = true
		local message = {type = 'lobby_update', ready = page.Player1.ready, team = page.Player1.team, nickname = user.Nickname}
		if network.server then network:broadcast(message)
		else network:sendTo(message)
		end
	end

	if network.server then
		page.btnPlay = UI.Button{x = page.btnReady.x - 15, y = page.btnReady.y, w = 10, h = 10, radius = 10, bc = colors.gray, fc = colors.white, text = "►"}
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

		page.tfFEN = UI.Textfield{x = 5, y = root.h - 15, w = 200, h = 10, radius = 2, bc = colors.gray, fc = colors.white, hint = 'FEN Position'}
		page.surface:addChild(page.tfFEN)
	end

	function page.surface.onResize(width, height)
		page.surface.w, page.surface.h = width, height
		local P1Y = math.floor((height - page.Player1.h)/2) + 1
		local P1X = page.Player2 and math.floor((width - 60 - page.Player1.w*2)/2) + 1 or math.floor((width - 60 - page.Player1.w)/2) + 1
		page.Player1.local_y, page.Player1.local_x = 21 > P1Y and 21 or P1Y, P1X
		page.rbtnTeam.local_x = width - 55
		page.btnReady.local_x, page.btnReady.local_y = width - (font.calcWidth(LC.not_ready)+10) - 5, height - 15
		page.labelTime.local_x = page.rbtnTeam.local_x
		page.dropdownTime.local_x = page.labelTime.local_x
		if page.btnPlay then
			page.btnPlay.local_x, page.btnPlay.local_y = page.btnReady.local_x - 15, page.btnReady.local_y
			page.tfFEN.local_y = height - 15
		end
		if page.tfCustom then
			page.tfCustom.local_x = page.dropdownTime.local_x
		end
		if page.Player2 then
			page.Player2.local_y, page.Player2.local_x = 21 > P1Y and 21 or P1Y, page.Player1.local_x + page.Player1.w + 10
		end
	end

	function page.createUI(recieve)
		page.Player1.local_x = math.floor((root.w - 60 - 106)/2) + 1

		page.Player2 = UI.Box{x = page.Player1.local_x + page.Player1.w + 10, y = math.floor((root.h - 65)/2) + 1, w = page.Player1.w, h = page.Player1.h, radius = 5, bc = colors.gray, fc = colors.white}
		page.Player2.nickname = recieve.nickname
		page.Player2.img = page.Player1.img
		page.Player2.oldDraw = page.Player2.draw
		page.Player2.draw = page.Player1.draw
		page.surface:addChild(page.Player2)

		if network.server then
			page.btnKick.local_x = page.Player2.x + 8
			page.btnKick.local_y = page.Player2.y + page.Player2.h + 5
		end

		page.surface:onLayout()
	end

	function network.connectHandler(_, client)
		if page.Player2 then
			return network:closeClient(client.clientID)
		end
		page.btnKick = UI.Button{text = 'Kick', x = 0, y = 0, w = 30, h = 11, radius = 5, bc = colors.red, fc = colors.white}
		function page.btnKick:pressed() client.close() end
		page.surface:addChild(page.btnKick)
	end
	function network.closeHandler()
		if not network.server then
			Screen:switch('mainMenu')
		else
			page.Player1.local_x = math.floor((root.w - 60 - 48)/2) + 1
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
	page.surface = UI.Box{ x = 0, y = 0, w = root.w, h = root.h, bc = colors.black }
	root:addChild(page.surface)

	page.btnExit = UI.Button{x = 1, y = 2, w = 20, h = 10, radius = 5, bc = colors.gray, fc = colors.white, text = '←'}
	page.surface:addChild(page.btnExit)
	function page.btnExit:pressed()
		Screen:switch('mainMenu')
	end

	page.btnL = UI.Button{x = page.btnExit.x + page.btnExit.w + 5, y = 2, w = 10, h = 10, radius = 2, bc = colors.gray, fc = colors.white, text = 'L'}
	page.surface:addChild(page.btnL)
	function page.btnL:pressed()
		page.tfIP.text = 'localhost'
		page.tfIP.dirty = true
	end

	page.btnV = UI.Button{x = page.btnL.x + page.btnL.w + 5, y = 2, w = 10, h = 10, radius = 2, bc = colors.gray, fc = colors.white, text = 'V'}
	page.surface:addChild(page.btnV)
	function page.btnV:pressed()
		page.tfIP.text = '192.168.191.153'
		page.tfIP.dirty = true
	end

	page.btnA = UI.Button{x = page.btnV.x + page.btnV.w + 5, y = 2, w = 10, h = 10, radius = 2, bc = colors.gray, fc = colors.white, text = 'A'}
	page.surface:addChild(page.btnA)
	function page.btnA:pressed()
		page.tfIP.text = '192.168.191.87'
		page.tfIP.dirty = true
	end

	local text, hint
	if user.ServerType == 'Rednet' then
		text = LC.computer_id..':'
		hint = '9'
	else
		text = LC.ip_adress..':'
		hint = '192.168.0.1'
	end

	page.labelIP = UI.Label{x = math.floor((root.w - font.calcWidth(text)-80)/2) + 1, y = math.floor((root.h - 10)/2) + 1, h = 10, w = font.calcWidth(text), text = text, bc = page.surface.bc, fc = colors.white}
	page.surface:addChild(page.labelIP)

	page.labelError = UI.Label{x = 0, y = page.labelIP.y - 15, h = 10, w = root.w, text = '', bc = page.surface.bc, fc = colors.white, align = 'center'}
	page.surface:addChild(page.labelError)

	page.tfIP = UI.Textfield{x = page.labelIP.x + page.labelIP.w + 5, y = page.labelIP.y, w = 81, h = 10, radius = 2, hint = hint, bc = colors.gray, fc = colors.white}
	page.surface:addChild(page.tfIP)

	page.btnConnect = UI.Button{x = math.floor((root.w - font.calcWidth(LC.connect) - 10)/2) + 1, y = page.labelIP.y + page.labelIP.h + 5, w = font.calcWidth(LC.connect) + 10, h = 15, radius = 5, bc = colors.gray, fc = colors.white, text = LC.connect}
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
		page.labelIP.local_x, page.labelIP.local_y = math.floor((width - font.calcWidth(LC.ip_adress..':')-80)/2) + 1, math.floor((height - 9)/2) + 1
		page.tfIP.local_x, page.tfIP.local_y = page.labelIP.local_x + page.labelIP.w + 5, page.labelIP.local_y
		page.btnConnect.local_x, page.btnConnect.local_y = math.floor((width - font.calcWidth(LC.connect) - 10)/2) + 1, page.labelIP.local_y + page.labelIP.h + 5
		page.labelError.local_y, page.labelError.w = page.labelIP.local_y - 15, width
	end

	return page
end
Screen:register('joinMenu', JoinMenu)

local MainMenu = {}
function MainMenu.new()
	local page = {}

	page.surface = UI.Box{ x = 0, y = 0, w = root.w, h = root.h, bc = colors.black }
	root:addChild(page.surface)

	page.logo = UI.Box{x = math.floor((root.w - 75)/2) + 1, y = 5, w = 75, h = 75, bc = colors.blue}
	page.surface:addChild(page.logo)
	page.logo.img = paintutils.loadImage(Chess.path .. 'Data/logo.nfp')
	function page.logo:draw()
		paintutils.drawImage(self.img, self.x + 17, self.y + 2)
	end

	page.labelNickname = UI.Label{x = 0, y = 0, w = font.calcWidth(LC.nickname..':'), h = 10, bc = page.surface.bc, fc = colors.white, text = LC.nickname..':'}
	page.surface:addChild(page.labelNickname)

	page.nickname = UI.Textfield{x = page.labelNickname.x + page.labelNickname.w + 5, y = 0, w = 60, h = 10, radius = 2, bc = colors.gray, fc = colors.white}
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

	local calcWidth = font.calcWidth(LC.create) + 10 + font.calcWidth(LC.join) + 10 + 5
	local center = math.floor((root.w - calcWidth)/2)+1
	page.btnCreate = UI.Button{x = center, y = page.logo.y + page.logo.h + 5, w = font.calcWidth(LC.create) + 10, h = 10, radius = 5, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = LC.create}
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

	page.btnJoin = UI.Button{x = page.btnCreate.x + page.btnCreate.w + 5, y = page.logo.y + page.logo.h + 5, w = font.calcWidth(LC.join) + 10, h = 10, radius = 5, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = LC.join, bc_hc = colors.lightGray, fc_hc = colors.black}
	page.surface:addChild(page.btnJoin)
	function page.btnJoin:pressed()
		Screen:switch('joinMenu')
	end

	page.btnLocalGame = UI.Button{x = center, y = page.btnJoin.y + page.btnJoin.h + 5, w = calcWidth, h = 10, radius = 5, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = LC.local_game, bc_hc = colors.lightGray, fc_hc = colors.black}
	page.surface:addChild(page.btnLocalGame)
	function page.btnLocalGame:pressed()
		Screen:switch('startGame', 'w', '')
	end

	page.btnSettings = UI.Button{x = center, y = page.btnLocalGame.y + page.btnLocalGame.h + 5, w = calcWidth, h = 10, radius = 5, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = LC.settings, bc_hc = colors.lightGray, fc_hc = colors.black}
	page.surface:addChild(page.btnSettings)
	function page.btnSettings:pressed()
		Screen:openModal('settingsMenu')
	end

	page.btnQuit = UI.Button{x = center, y = page.btnSettings.y + page.btnSettings.h + 5, w = calcWidth, h = 10, bc = colors.gray, radius = 5, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = LC.quit, bc_hc = colors.lightGray, fc_hc = colors.black}
	page.surface:addChild(page.btnQuit)
	function page.btnQuit:pressed()
		os.queueEvent('terminate')
	end

	page.btnAbout = UI.Button{x = root.w - 15, y = 5, w = 10, h = 10, radius = 5, bc = colors.gray, fc = colors.white, text = "?"}
	page.surface:addChild(page.btnAbout)
	function page.btnAbout:pressed()
		Screen:openModal('aboutMenu')
	end

	page.labelVersion = UI.Label{x = 0, y = root.h - 20, w = font.calcWidth('Ver.: ' .. Chess.version), h = 10, bc = page.surface.bc, fc = colors.gray, text = 'Ver.: ' .. Chess.version, align = "left"}
	page.surface:addChild(page.labelVersion)

	page.btnUpdate = UI.Button{x = 0, y = root.h - 10, w = font.calcWidth(LC.check_for_update) + 10, h = 10, radius = 5, text = LC.check_for_update, bc = colors.gray, fc = colors.white}
	page.btnUpdate.loading = 0
	function page.btnUpdate:draw()
		local bc = self.bc
		local fc = self.fc
		if self.held and not (self.loading > 0) then
			bc = self.bc_cl or self.fc
			fc = self.fc_cl or self.bc
		end
		if self.radius then
			g.draw_filled_rounded_rect(self.x ,self.y, self.w, self.h, self.radius, bc)
			local old = UI.term_setClip(self.x, self.y, (self.loading * self.w), self.h)
			g.draw_filled_rounded_rect(self.x ,self.y, self.w, self.h, self.radius, colors.blue)
			UI.term_unsetClip(old)
		else
			term.drawPixels(self.x, self.y, bc, self.w, self.h)
			local old = UI.term_setClip(self.x, self.y, (self.loading * self.w), self.h)
			term.drawPixels(self.x ,self.y, self.w, self.h, colors.blue)
			UI.term_unsetClip(old)
		end
		font.simpleText(self.text, self.x, self.y, fc, self.w, self.h, 'center')
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
				self:setText(LC.updating)
				for i, path in ipairs(filesToUpdate) do
					local request = http.get(link .. path)
					if request then
						log('UPDATE: ' .. Chess.path .. path)
						-- write_file(Chess.path .. path, request.readAll())
						request.close()
						self.loading = i / #filesToUpdate
						self:draw()
					end
				end
				self:setText(LC.succes)
			else
				self:setText(LC.no_updates)
			end
		end
	end

	function page.surface.onResize(width, height)
		page.surface.w, page.surface.h = width, height
		center = math.floor((width - calcWidth)/2)+1
		page.logo.local_x = math.floor((root.w - 75)/2) + 1
		page.btnCreate.local_x = center
		page.btnJoin.local_x = page.btnCreate.local_x + page.btnCreate.w + 5
		page.btnLocalGame.local_x, page.btnLocalGame.local_y = center, page.btnJoin.local_y + page.btnJoin.h + 5
		page.btnSettings.local_x, page.btnSettings.local_y = center, page.btnLocalGame.local_y + page.btnLocalGame.h + 5
		page.btnQuit.local_x = center
		page.btnAbout.local_x = width - 16
		page.labelVersion.local_y = height - 20
		page.btnUpdate.local_y = height - 10
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
		term.clear()
		term.setGraphicsMode(false)
		break
	elseif event == "rednet_message" or event:match("^websocket") then
		network:eventHandler(evt)
	elseif event == 'peripheral' or event == 'peripheral_detach' then
		speaker:updateOutputs()
		network:updateModems()
	end
	-- term.setFrozen(true)
	root:onEvent(evt)
	-- term.setFrozen(false)
end