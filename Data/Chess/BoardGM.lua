local _Board = {}

-- local function log(...)
-- 	local texts = {...}
-- 	local file = fs.open("log.txt", "a")
-- 	for i, v in ipairs(texts) do
-- 		if type(v) == "table" and type(v) ~= "thread" then
-- 			v = textutils.serialise(v)
-- 		else
-- 			v = tostring(v)
-- 		end
-- 		file.write(v.."; ")
-- 	end
-- 	file.write("\n")
-- 	file.close()
-- end

local PI = 3.1415926
local l = 5
local function draw_arrow(x1, y1, x2, y2, color)
	color = color or colors.green
	paintutils.drawLine(x1, y1, x2, y2, color)
	local dx = x2 - x1
	local dy = y2 - y1

	local gammaRad = math.atan(math.abs(dx/dy))

	if dx < 0 and dy < 0 then
		gammaRad = 2 * PI - gammaRad
	elseif dx < 0 and dy >= 0 then
		gammaRad = gammaRad - PI
	-- elseif dx > 0 and dy < 0 then
	--     gammaRad = gammaRad
	-- elseif dx > 0 and dy > 0 then
	elseif dy >= 0 then
		gammaRad = PI - gammaRad
	end
	-- local atan = math.atan(1)
	local atan = 0.78539816339745
	local alpha = gammaRad + atan
	local beta = gammaRad - atan

	local deltaX3 = math.floor(l * math.cos(alpha) + 0.5)
	local deltaY3 = math.floor(l * math.sin(alpha) + 0.5)

	local deltaX4 = math.floor(l * math.cos(beta) + 0.5)
	local deltaY4 = math.floor(l * math.sin(beta) + 0.5)

	local x3 = x2 + deltaX3
	local y3 = y2 + deltaY3
	local x4 = x2 - deltaX4
	local y4 = y2 - deltaY4

	paintutils.drawLine(x2, y2, x3, y3, color)
	paintutils.drawLine(x2, y2, x4, y4, color)
end

local function draw_wide_arrow(x1, y1, x2, y2, color, width)
    for i = 0, width - 1 do
        for j = 0, width - 1 do
            draw_arrow(x1 + j, y1 + i, x2 + j, y2 + i, color)
        end
    end
end


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

local function onMouseDrag(self, btn, mx, my)
	local arrow = self.arrow
	local x, y = self:squareAtMouse(mx, my)
	if not x then return end
	local eX, eY = math.floor(x * _Board.Chess.CELL_W - _Board.Chess.CELL_W / 2), math.floor(y * _Board.Chess.CELL_H - _Board.Chess.CELL_H / 2)
	if btn == 2 and (eX ~= arrow.sX or eY ~= arrow.sY) then
		arrow.eX, arrow.eY = eX, eY
		-- log(arrow.sX, arrow.sY, arrow.eX, arrow.eY)
		self.dirty = true
	elseif btn == 2 then
		arrow.eX, arrow.eY = nil, nil
		self.dirty = true
	end
end

local function onKeyDown(self, key, held)
	if held then return true end
	local arrow = self.arrow
	if key == keys.leftAlt and not arrow.eX then
		self.arrow.color = colors.blue
	elseif key == keys.leftShift and not arrow.eX then
		self.arrow.color = colors.red
	end
	return true
end

local function onKeyUp(self, key)
	local arrow = self.arrow
	if key == keys.leftAlt and not arrow.eX then
		arrow.color = colors.green
	elseif key == keys.leftShift and not arrow.eX then
		arrow.color = colors.green
	end
	return true
end

local function onMouseDown(self, btn, mx, my)
	local x, y = self:squareAtMouse(mx, my)
	local game = self.game
	if game.team and (game.turn ~= game.team) or game.pendingPromotion then return end
	if not x then return true end

	if game.over then return true end

	if self.selected and btn == 1 then
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
	elseif btn == 1 then
		self:selectSquare(x, y)
	end
	if x then
		self.arrow.sX, self.arrow.sY = math.floor(x * _Board.Chess.CELL_W - _Board.Chess.CELL_W / 2), math.floor(y * _Board.Chess.CELL_H - _Board.Chess.CELL_H / 2)
		self.arrow.eX, self.arrow.eY = nil, nil
		if btn == 2 then clearSelection(self, game) end
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
	local Chess = _Board.Chess
	-- term.drawPixels(self.x, self.y, self.bc, self.w, self.h)
	local bX, bY = self.x + Chess.T_DELTA_W, self.y + Chess.T_DELTA_H
	local cellW, cellH = Chess.CELL_W, Chess.CELL_H
	if not self.cachedBG then
		self.cachedBG = {}
		for y = 0, 7 do
			for x = 0, 7 do
				local color
				if ((x + y) % 2) == 0 then
					color = Chess.BOARD_BG_A
				else
					color = Chess.BOARD_BG_B
				end
				local startY = y * cellH + 1
				local startX = x * cellW + 1

				for y2 = startY, startY + cellH + 1 do
					if not self.cachedBG[y2] then self.cachedBG[y2] = {} end
					for x2 = startX, startX + cellW + 1 do
						self.cachedBG[y2][x2] =	color
					end
				end
			end
		end
	end
	term.drawPixels(bX, bY, self.cachedBG, 112, 112)
	local game = self.game
	local function cellLeft(file)
		return self.rotate and self.x + (file - 1) * Chess.CELL_W or self.x + (9 - file - 1) * Chess.CELL_W
	end
	local function cellTop(rankFromTop)
		return self.rotate and self.y + (rankFromTop - 1) * Chess.CELL_H or self.y + (9 - rankFromTop - 1) * Chess.CELL_H
	end

	-- background + coordinates

	-- top files
	for i = 1, 8 do
		_Board.font.simpleText(_Board.xToFile[not self.rotate and 9 - i or i], self.x + i * Chess.CELL_W - math.floor((Chess.CELL_W - Chess.T_DELTA_W) / 2) + 1, self.y, colors.white)
		-- _Board.font.drawText(_Board.xToFile[not self.rotate and 9 - i or i], self.x + i * _Board.Chess.CELL_W - math.floor((_Board.Chess.CELL_W - _Board.Chess.T_DELTA_W) / 2) + 1, self.y, colors.white, _, _, _, _, _, true)
	end

	for rankFromTop = 1, 8 do
		local y = (9 - rankFromTop)
		local sy = cellTop(rankFromTop) + Chess.T_DELTA_H

		_Board.font.simpleText(tostring(y), self.x, sy + math.floor((Chess.CELL_H - Chess.T_DELTA_H) / 2) + 1, colors.white)

		for file = 1, 8 do
			local sx = cellLeft(file) + Chess.T_DELTA_W
			local p = self.board[rankFromTop][file]
			local base = ((file + rankFromTop) % 2 == 0) and Chess.BOARD_BG_A or Chess.BOARD_BG_B
			local bg = base
			local fg = (bg == Chess.BOARD_BG_A) and Chess.BOARD_FG_A or Chess.BOARD_FG_B
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
				fg = Chess.BOARD_BG_S
				text = "•"
			elseif targetType == "capture" then
				bg = Chess.BOARD_BG_T
				fg = colors.white
				if not p then
					text = "•"
				end
			elseif isSelected then
				bg = Chess.BOARD_BG_S
				fg = colors.black
			elseif p then
				fg = (_Board.pieceColor(p) == "w") and Chess.BOARD_FG_A or Chess.BOARD_FG_B
				if p:sub(2,2) == 'k' and game:inCheck(p:sub(1,1)) then
					bg = Chess.BOARD_BG_T
				end
			end
			if bg == Chess.BOARD_BG_T or bg == Chess.BOARD_BG_S then
				term.drawPixels(sx, sy, bg, Chess.CELL_W, Chess.CELL_H)
			end

			if text ~= '' then
				_Board.font.simpleText(text, sx, text ~= '•' and sy or sy + 1, fg, Chess.CELL_W, Chess.CELL_H, 'center')
			end
			-- if p then _Board.drawPiece(sx, sy, _Board.pieceGlyph[p:sub(2,2)], fg) end
			if p then _Board.drawPiece(sx, sy, _Board.cacheGlyph[p], Chess.CELL_W, Chess.CELL_H) end
		end
		_Board.font.simpleText(tostring(y), self.x + 8 * Chess.CELL_W + Chess.T_DELTA_W, sy + math.floor((Chess.CELL_H - Chess.T_DELTA_H) / 2) + 1, colors.white)
	end

	if self.arrow.eX then
		local startX, startY, endX, endY
		local rot = self.rotate
		local bW, bH = cellW * 8, cellH * 8
		local dx, dy = self.x + 6, self.y + 9

		startX = (rot and self.arrow.sX or (bW - self.arrow.sX)) + dx
		startY = (rot and self.arrow.sY or (bH - self.arrow.sY)) + dy
		endX = (rot and self.arrow.eX or (bW - self.arrow.eX)) + dx
		endY = (rot and self.arrow.eY or (bH - self.arrow.eY)) + dy


		draw_wide_arrow(startX, startY, endX, endY, self.arrow.color, 2)
		-- draw_wide_arrow(self.arrow.sX + self.x + 6, self.arrow.sY + self.y + 9, self.arrow.eX + self.x + 6, self.arrow.eY + self.y + 9, self.arrow.color, 2)
	end

	-- bottom files
	for i = 1, 8 do
		_Board.font.simpleText(_Board.xToFile[not self.rotate and 9 - i or i] .. "  ", self.x + i * Chess.CELL_W - math.floor((Chess.CELL_W - Chess.T_DELTA_W) / 2) + 1, self.y + 8 * Chess.CELL_H + Chess.T_DELTA_H, colors.white)
	end
	term.setPixel(self.x + Chess.T_DELTA_W, self.y + Chess.T_DELTA_H, self.bc)
	term.setPixel(self.x + self.w - Chess.T_DELTA_W - 1, self.y + Chess.T_DELTA_H, self.bc)
	term.setPixel(self.x + self.w - Chess.T_DELTA_W - 1, self.y + self.h - Chess.T_DELTA_H - 1, self.bc)
	term.setPixel(self.x + Chess.T_DELTA_W, self.y + self.h - Chess.T_DELTA_H - 1, self.bc)
end

function _Board.Board(args)
	local instance = _Board.UI.Box(args)

	instance.board = _Board.makeBoard()
	instance.game = nil
	instance.selected = nil
	instance.rotate = true
	instance.arrow = {}

	instance.draw = draw
	instance.onFocus = onFocus
	instance.onMouseDown = onMouseDown
	instance.onMouseDrag = onMouseDrag
	instance.onKeyDown = onKeyDown
	instance.onKeyUp = onKeyUp
	-- instance.onMouseUp = onMouseUp
	instance.selectSquare = selectSquare
	instance.squareAtMouse = squareAtMouse

	return instance
end

return _Board