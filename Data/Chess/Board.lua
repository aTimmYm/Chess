local _Board = {}

local CELL_W = 3

local function clearSelection(board, game)
	board.selected = nil
	game.legalMoves = {}
	board.dirty = true
	-- refreshStatus()
end

local function selectSquare(self, x, y)
	local game = self.game
	if game.over then return end
	local p = self.board[y][x]
	if p and _Board.pieceColor(p) == game.turn then
		self.selected = { x = x, y = y }
		game.legalMoves = game:legalMovesFrom(x, y)
		self.dirty = true
		-- refreshStatus()
	else
		clearSelection(self, game)
	end
end

local function squareAtMouse(self, mx, my)
	local relX = mx - self.x + 1
	local relY = my - self.y + 1
	if relX < 2 or relX > 25 or relY < 2 or relY > 9 then
		return nil
	end
	local file = math.floor((relX - 2) / CELL_W) + 1
	local rankFromTop = relY - 1
	if file < 1 or file > 8 or rankFromTop < 1 or rankFromTop > 8 then
		return nil
	end
	-- local x = file
	local x = self.rotate and file or 9 - file
	local y = self.rotate and rankFromTop or 9 - rankFromTop
	return x, y
end

local function onMouseDown(self, btn, mx, my)
	local game = self.game
	if game.team and (game.turn ~= game.team) or game.pendingPromotion then return end
	local x, y = self:squareAtMouse(mx, my)
	if not x then return true end

	if game.over then return true end

	if self.selected then
		local sX, sY = self.selected.x, self.selected.y
		local ret = game:moveSelectedTo(x, y, self.selected)
		if ret == 'promo' then
			if self.waitingPromo then
				self:waitingPromo(x, y, self.selected)
			end
			return true
		elseif ret == true then
			self.selected = nil
			self.dirty = true
			self:pressed(sX * 10 + sY, x * 10 + y)
			return true
		end
		local p = self.board[y][x]
		if p and _Board.pieceColor(p) == game.turn then
			self:selectSquare(x, y)
		else
			clearSelection(self, game)
		end
	else
		self:selectSquare(x, y)
	end
	return true
end

local function onMouseUp(self, btn, mx, my)
	-- if self.waitingPromo then return true end
	local game = self.game
	local x, y = self:squareAtMouse(mx, my)
	if not x then return true end

	if game.over then return true end
	if self.selected then
		local sX, sY = self.selected.x, self.selected.y
		local ret = game:moveSelectedTo(x, y, self.selected)
		if ret == 'promo' then
			if self.waitingPromo then
				self:waitingPromo(x, y, self.selected)
			end
			return true
		elseif ret == true then
			self.selected = nil
			self.dirty = true
			self:pressed(sX * 10 + sY, x * 10 + y)
			return true
		end
	else
		return true
	end
	return true
end

local function onFocus(self, focused)
	if focused then return end
	if self.game.pendingPromotion then return end
	clearSelection(self, self.game)

	return true
end

local function draw(self)
	local game = self.game
	local function cellLeft(file)
		return self.rotate and self.x + 1 + (file - 1) * CELL_W or self.x + 1 + (9 - file - 1) * CELL_W
	end
	local function cellTop(rankFromTop)
		return self.rotate and self.y + rankFromTop or self.y + (9 - rankFromTop)
	end

	-- background + coordinates
	term.setBackgroundColor(self.bc)
	term.setTextColor(self.fc)
	-- top files
	term.setCursorPos(self.x + 2, self.y)
	for i = 1, 8 do
		term.write(_Board.xToFile[not self.rotate and 9 - i or i] .. "  ")
	end

	for rankFromTop = 1, 8 do
		local y = 9 - rankFromTop
		local sy = cellTop(rankFromTop)

		term.setCursorPos(self.x, sy)
		term.write(tostring(y))

		for file = 1, 8 do
			local sx = cellLeft(file)
			local p = self.board[rankFromTop][file]
			local tp = p and 't'..p:sub(2,2)
			local base = ((file + rankFromTop) % 2 == 0) and _Board.Chess.BOARD_BG_A or _Board.Chess.BOARD_BG_B
			local bg = base
			local fg = (bg == _Board.Chess.BOARD_BG_A) and _Board.Chess.BOARD_FG_A or _Board.Chess.BOARD_FG_B
			local text = "   "

			local isSelected = self.selected and self.selected.x == file and self.selected.y == rankFromTop
			local targetType = nil
			if self.selected then
				for _, m in ipairs(game.legalMoves) do
					if m.tx == file and m.ty == rankFromTop then
					targetType = m.captured and "capture" or "move"
					break
					end
				end
			end

			if targetType == "move" then
				bg = base
				fg = _Board.Chess.BOARD_BG_S
				text = " \7 "
			elseif targetType == "capture" then
				bg = _Board.Chess.BOARD_BG_T
				fg = _Board.Chess.BOARD_FG_A
				if p then
					local glyph = _Board.pieceGlyph[tp] or "?"
					text = " " .. glyph .. " "
				else
					text = " x "
				end
			elseif isSelected then
				bg = _Board.Chess.BOARD_BG_S
				fg = _Board.Chess.BOARD_FG_B
				if p then
					local glyph = _Board.pieceGlyph[tp] or "?"
					text = " " .. glyph .. " "
				end
			elseif p then
				local glyph = _Board.pieceGlyph[tp] or "?"
				text = " " .. glyph .. " "
				fg = (_Board.pieceColor(p) == "w") and _Board.Chess.BOARD_FG_A or _Board.Chess.BOARD_FG_B
			end

			term.setBackgroundColor(bg)
			term.setTextColor(fg)
			term.setCursorPos(sx, sy)
			term.write(text)
		end

		term.setBackgroundColor(colors.black)
		term.setTextColor(colors.lightGray)
		term.setCursorPos(self.x + 25, sy)
		term.write(tostring(y))
	end

	-- bottom files
	term.setCursorPos(self.x + 2, self.y + 9)
	for i = 1, 8 do
		term.write(_Board.xToFile[not self.rotate and 9 - i or i] .. "  ")
	end
end

function _Board.Board(args)
	local instance = _Board.UI.Box(args)

	instance.board = _Board.makeBoard()
	instance.game = nil
	instance.selected = nil
	instance.rotate = true

	instance.draw = draw
	instance.onFocus = onFocus
	instance.onMouseDown = onMouseDown
	-- instance.onMouseUp = onMouseUp
	instance.selectSquare = selectSquare
	instance.squareAtMouse = squareAtMouse

	return instance
end

return _Board