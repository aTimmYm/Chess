local _Board = {}

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
	local relX = mx - self.x
	local relY = my - self.y
	if relX < (_Board.Chess.T_DELTA_W) or relX > (_Board.Chess.T_DELTA_W + _Board.Chess.CELL_W * 8) or relY < _Board.Chess.T_DELTA_H or relY > (_Board.Chess.T_DELTA_H + _Board.Chess.CELL_H * 8) then
		return nil
	end
	local file = math.floor((relX - _Board.Chess.T_DELTA_W) / _Board.Chess.CELL_W) + 1
	local rankFromTop = math.floor((relY - _Board.Chess.T_DELTA_H) / _Board.Chess.CELL_H) + 1
	if file < 1 or file > 8 or rankFromTop < 1 or rankFromTop > 8 then
		return nil
	end
	local x = self.rotate and file or 9 - file
	local y = self.rotate and rankFromTop or 9 - rankFromTop
	return x, y
end

local function onMouseDown(self, btn, mx, my)
	local game = self.game
	if game.team and (game.turn ~= game.team) then return end
	local x, y = self:squareAtMouse(mx, my)
	if not x then return true end

	if game.over then return true end

	if self.selected then
		local sX, sY = self.selected.x, self.selected.y
		if game:moveSelectedTo(x, y, self.selected) then
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
	local game = self.game
	local x, y = self:squareAtMouse(mx, my)
	if not x then return true end

	if game.over then return true end
	if self.selected then
		local sx, sy = self.selected.x, self.selected.y
		if game:moveSelectedTo(x, y, self.selected) then
			self.selected = nil
			self.dirty = true
			self:pressed(sx * 10 + sy, x * 10 + y)
			return true
		end
	else
		return true
	end
	return true
end

local function onFocus(self, focused)
	if focused then return end
	clearSelection(self, self.game)

	return true
end

local function draw(self)
	term.drawPixels(self.x, self.y, self.bc, self.w, self.h)
	local game = self.game
	local function cellLeft(file)
		return self.rotate and self.x + (file - 1) * _Board.Chess.CELL_W or self.x + (9 - file - 1) * _Board.Chess.CELL_W
	end
	local function cellTop(rankFromTop)
		return self.rotate and self.y + (rankFromTop - 1) * _Board.Chess.CELL_H or self.y + (9 - rankFromTop - 1) * _Board.Chess.CELL_H
	end

	-- background + coordinates

	-- top files
	for i = 1, 8 do
		_Board.font.simpleText(_Board.xToFile[not self.rotate and 9 - i or i], self.x + i * _Board.Chess.CELL_W - math.floor((_Board.Chess.CELL_W - _Board.Chess.T_DELTA_W) / 2) + 1, self.y, colors.white)
		-- _Board.font.drawText(_Board.xToFile[not self.rotate and 9 - i or i], self.x + i * _Board.Chess.CELL_W - math.floor((_Board.Chess.CELL_W - _Board.Chess.T_DELTA_W) / 2) + 1, self.y, colors.white, _, _, _, _, _, true)
	end

	for rankFromTop = 1, 8 do
		local y = (9 - rankFromTop)
		local sy = cellTop(rankFromTop) + _Board.Chess.T_DELTA_H

		_Board.font.simpleText(tostring(y), self.x, sy + math.floor((_Board.Chess.CELL_H - _Board.Chess.T_DELTA_H) / 2) + 1, colors.white)

		for file = 1, 8 do
			local sx = cellLeft(file) + _Board.Chess.T_DELTA_W
			local p = self.board[rankFromTop][file]
			local base = ((file + rankFromTop) % 2 == 0) and _Board.Chess.BOARD_BG_A or _Board.Chess.BOARD_BG_B
			local bg = base
			local fg = (bg == _Board.Chess.BOARD_BG_A) and _Board.Chess.BOARD_FG_A or _Board.Chess.BOARD_FG_B
			local text = ''
			-- local glyph

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
				text = "•"
			elseif targetType == "capture" then
				bg = _Board.Chess.BOARD_BG_T
				fg = colors.white
				if not p then
					text = "•"
				end
			elseif isSelected then
				bg = _Board.Chess.BOARD_BG_S
				fg = colors.black
			elseif p then
				fg = (_Board.pieceColor(p) == "w") and _Board.Chess.BOARD_FG_A or _Board.Chess.BOARD_FG_B
				if p:sub(2,2) == 'k' and game:inCheck(p:sub(1,1)) then
					bg = _Board.Chess.BOARD_BG_T
				end
			end
			term.drawPixels(sx, sy, bg, _Board.Chess.CELL_W, _Board.Chess.CELL_H)

			if text ~= '' then
				 _Board.font.simpleText(text, sx, text ~= '•' and sy or sy + 1, fg, _Board.Chess.CELL_W, _Board.Chess.CELL_H, 'center')
			end
			if p then _Board.drawPiece(sx, sy, _Board.pieceGlyph[p:sub(2,2)], fg) end
		end
		_Board.font.simpleText(tostring(y), self.x + 8 * _Board.Chess.CELL_W + _Board.Chess.T_DELTA_W, sy + math.floor((_Board.Chess.CELL_H - _Board.Chess.T_DELTA_H) / 2) + 1, colors.white)
	end

	-- bottom files
	for i = 1, 8 do
		_Board.font.simpleText(_Board.xToFile[not self.rotate and 9 - i or i] .. "  ", self.x + i * _Board.Chess.CELL_W - math.floor((_Board.Chess.CELL_W - _Board.Chess.T_DELTA_W) / 2) + 1, self.y + 8*_Board.Chess.CELL_H+_Board.Chess.T_DELTA_H, colors.white)
	end
	term.setPixel(self.x + _Board.Chess.T_DELTA_W, self.y + _Board.Chess.T_DELTA_H, self.bc)
	term.setPixel(self.x + self.w - _Board.Chess.T_DELTA_W - 1, self.y + _Board.Chess.T_DELTA_H, self.bc)
	term.setPixel(self.x + self.w - _Board.Chess.T_DELTA_W - 1, self.y + self.h - _Board.Chess.T_DELTA_H - 1, self.bc)
	term.setPixel(self.x + _Board.Chess.T_DELTA_W, self.y + self.h - _Board.Chess.T_DELTA_H - 1, self.bc)
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
	instance.onMouseUp = onMouseUp
	instance.selectSquare = selectSquare
	instance.squareAtMouse = squareAtMouse

	return instance
end



return _Board